# gke-peering-event-function
GCP Cloudfunction that responds to VPC peering events for GKE and automatically adds custom route export

## Summary

Google Kubernetes Engine (GKE) is the Google Cloud specific implementation of Kubernetes. When deploying private GKE clusters, worker nodes will go in customer owned VPCs and masters go in a special gke tenant VPC owned/managed by Google. GKE will automatically build a VPC peering between customer VPCs and tenant VPCs as needed and remove the peerings if all clusters are deleted. Additionally, these peerings are regional so if you use a global VPC and deploy GKE into multiple regions, you will see multiple VPC peerings if you have clusters in multiple regions.

## Problem

You may want route export because there is a private connection from your corporate infrastructure that developers use to reach the master nodes and without route export, it will be unreachable. The issue with Google dynamically building these peerings is there is not a way to enable custom route exports on these peerings when they are built. It must be added in after the fact and this is a problem when the networking stack is managed as code. If you attempt to modify this these peerings using [terraform](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering_routes_config) and the peering is deleted, your terraform will break and you must remove the resource from state.

## Solution

My solution to this issue is to build a CloudFunction that is executed when the creation of vpc peerings happens. CloudFunctions have support for a set number of events natively using the cloudevents [specification](https://github.com/cloudevents/spec) but this event in particular is not supported [Google Supported Events](https://github.com/googleapis/google-cloudevents).

The workaround is to setup a logsink in Google logging so certain log messages are forwarded to a pub/sub topic which can then trigger execution of the cloud function. These events come in as base64 encoded json so they must be decoded and processed before they can be used. [Google Documentation](https://cloud.google.com/functions/docs/calling/logging)

The end result of this solution is that when a VPC peering is added, a cloudfunction is triggered and will add route export on the customer VPC. This ensures that any new GKE peerings which are added dynamically will also recieve custom routes from the customer VPC. This removes the requirement for an administrator to make this change especially when using a shared vpc.

## Terraform

This solution is implemented with Terraform. You can use the code in the ./terraform directory to deploy this solution. The identity that runs terraform needs the required permissions to build out the resources in question. Refer to the readme within the terraform folder for the resources created.

### Terraform Tests

This can easily be converted to a module. Normally I'd build this into a terraform module and write tests using the [terratest framework](https://terratest.gruntwork.io/). I did not do this since this is just a demonstration. I'm currently testing the terraform by running an apply in a dev environment and a destroy when I'm done. This is essentially what terratest will do except you'd typically compare output values with expected results.

### Setup

1. Setup your backend.tf if you want your state stored remotely (TFC/TFE, GCS, S3, Etc) or not if you want state to be stored locally
2. Create a tfvars file and populate with variable values (included example in terraform)
3. Run a `terraform init` to install the required providers
4. Run a `terraform plan` to ensure terraform runs as expected.

### Deployment

After you've followed the setup steps, you can deploy using `terraform apply`.

### Manual Tests

You can test the solution two ways. I tested using the second procedure since it's easier and I didn't need to build a GKE cluster which can take some time to build.

1. Create a private GKE cluster and watch the VPC peering that gets created, you should see route export added after 20-30 seconds.
2. Build two test VPCs and build a VPC peering, name the peerings `gke-<random>-peer`. You should see route export added on the peering that is in your target VPC have route export added.

#### Example Test

I've created a tfvars file in the terraform directory with the following values. I've ommited some of these values for privacy reasons.

```
network_name = "testvpc1"
project_id = "<omitted>"
vpc_connector = "projects/<omitted>/locations/us-east4/connectors/cloud-functions-connector"
bucket_location = "us-east4"
region = "us-east4"
```

After that, I ran terraform apply. My terraform was already initialized. Below is the output of the apply.

<br>

`Apply complete! Resources: 9 added, 0 changed, 0 destroyed.`

<br>

I then created two test VPCs named testvpc1 and testvpc2. testvpc1 simulates a customer VPC and testvpc2 simulates a Google managed GKE VPC.

<br>

![Screenshot of test VPCs](./test_vpc_screenshot.png?raw=true "Test VPC Screenshot")

<br>

I then created two VPC peerings. You must create a VPC peering from testvpc2 to testvpc1 and then another from testvpc1 to testvpc2. When you build a GKE cluster, you'd only see one peering in your project. We should expect the testvpc1 to testvpc2 peering to get the route export added. Notice that it does not have route export added at this point.

<br>

vpc peering for testvpc2 to testvpc1

<br>

![Screenshot of testvpc2 to testvpc1 peering](./testvpc2_peering.png?raw=true "Test VPC 2 peering Screenshot")

<br>

vpc peering for testvpc1 to testvpc2

<br>

![Screenshot of testvpc1 to testvpc2 peering](./testvpc1_peering.png?raw=true "Test VPC 1 peering Screenshot")

<br>

Notice that the peerings are created but route export is not enabled.

<br>

![Screenshot of both peerings](./created_peerings.png?raw=true "Peerings Screenshot")

<br>

If you wait about 30 seconds and then refresh, you will see that custom route export is enabled on testvpc1 to testvpc2. This is exactly what we want and I did not take any action to make this happen. What occured is a log message was generated when the vpc peering event happened. The log sink sent that message to a pub/sub topic which invoked the cloudfunction. The cloudfunction added the custom route export on the target VPC in question.

<br>

![Screenshot of both peerings after ](./created_peerings2.png?raw=true "Peerings After Screenshot")

<br>

## Example Log Query for addPeering Events

A log Sink is used to filter out only VPC peering creation events for GKE peerings in particular. Below is the query that is used.

    protoPayload.methodName="v1.compute.networks.addPeering"
    protoPayload.request.networkPeering.name: ("gke-" AND "-peer")
    protoPayload.resourceName: ("<project_id>" AND "<network_name>")

## CloudFunction

The cloudfunction executes a python script which in-turn adds the required peering. Python cloudfunctions require the code to either be in a .zip archive or directory stored in a repo or GCS bucket. The example uses a GCS bucket and zip file all built via terraform.

### Requirements

Python cloud functions require two files to be present.

1. main.py
2. requirements.txt

main.py will contain your entrypoint function and this is also specified when you build the function. The requirements.txt file contains the required packages that need to be installed.

### Tests

I've added some unit tests as an example in the tests directory. Not all of these tests are great since it is difficult to mock some of the objects returned from the queries used by the Google compute SDK. Run the following steps to execute the unit tests.

1. Install tox following [official documentation](https://tox.wiki/en/4.5.1/installation.html).
2. Setup gcloud default authentication, will not make any real API calls `gcloud auth application-default login`.
3. Run tox which will setup virtual environments, lint, and run pytest. Just run `tox` from root directory of repo.

```
~> gke-peering-event-function % tox
lint: install_deps> python -I -m pip install 'black>=23' -e . -r ./src/requirements.txt
.pkg: install_requires> python -I -m pip install setuptools
.pkg: _optional_hooks> python /Users/zachbrooks/.local/pipx/venvs/tox/lib/python3.11/site-packages/pyproject_api/_backend.py True setuptools.build_meta
.pkg: get_requires_for_build_sdist> python /Users/zachbrooks/.local/pipx/venvs/tox/lib/python3.11/site-packages/pyproject_api/_backend.py True setuptools.build_meta
.pkg: prepare_metadata_for_build_wheel> python /Users/zachbrooks/.local/pipx/venvs/tox/lib/python3.11/site-packages/pyproject_api/_backend.py True setuptools.build_meta
.pkg: build_sdist> python /Users/zachbrooks/.local/pipx/venvs/tox/lib/python3.11/site-packages/pyproject_api/_backend.py True setuptools.build_meta
lint: install_package_deps> python -I -m pip install google-cloud-compute==1.11.0
lint: install_package> python -I -m pip install --force-reinstall --no-deps /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/.tmp/package/1/update_vpc_peering-0.0.1.tar.gz
lint: commands[0]> black .
All done! ✨ 🍰 ✨
4 files left unchanged.
lint: OK ✔ in 11.25 seconds
py311: install_deps> python -I -m pip install 'pytest>=7' -e . -r ./src/requirements.txt
py311: install_package_deps> python -I -m pip install google-cloud-compute==1.11.0
py311: install_package> python -I -m pip install --force-reinstall --no-deps /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/.tmp/package/2/update_vpc_peering-0.0.1.tar.gz
py311: commands[0]> pytest tests
============================= test session starts ==============================
platform darwin -- Python 3.11.3, pytest-7.3.1, pluggy-1.0.0
cachedir: .tox/py311/.pytest_cache
rootdir: /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function
collected 5 items                                                              

tests/test_update_vpc_peering.py .....                                   [100%]

=============================== warnings summary ===============================
.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:121
  /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:121: DeprecationWarning: pkg_resources is deprecated as an API
    warnings.warn("pkg_resources is deprecated as an API", DeprecationWarning)

.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870
.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870
.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870
.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870
  /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870: DeprecationWarning: Deprecated call to `pkg_resources.declare_namespace('google')`.
  Implementing implicit namespace packages (as specified in PEP 420) is preferred to `pkg_resources.declare_namespace`. See https://setuptools.pypa.io/en/latest/references/keywords.html#keyword-namespace-packages
    declare_namespace(pkg)

.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870
  /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870: DeprecationWarning: Deprecated call to `pkg_resources.declare_namespace('google.cloud')`.
  Implementing implicit namespace packages (as specified in PEP 420) is preferred to `pkg_resources.declare_namespace`. See https://setuptools.pypa.io/en/latest/references/keywords.html#keyword-namespace-packages
    declare_namespace(pkg)

.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2349
.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2349
.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2349
  /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2349: DeprecationWarning: Deprecated call to `pkg_resources.declare_namespace('google')`.
  Implementing implicit namespace packages (as specified in PEP 420) is preferred to `pkg_resources.declare_namespace`. See https://setuptools.pypa.io/en/latest/references/keywords.html#keyword-namespace-packages
    declare_namespace(parent)

.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870
  /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/py311/lib/python3.11/site-packages/pkg_resources/__init__.py:2870: DeprecationWarning: Deprecated call to `pkg_resources.declare_namespace('google.logging')`.
  Implementing implicit namespace packages (as specified in PEP 420) is preferred to `pkg_resources.declare_namespace`. See https://setuptools.pypa.io/en/latest/references/keywords.html#keyword-namespace-packages
    declare_namespace(pkg)

.tox/py311/lib/python3.11/site-packages/google/rpc/__init__.py:20
  /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/py311/lib/python3.11/site-packages/google/rpc/__init__.py:20: DeprecationWarning: Deprecated call to `pkg_resources.declare_namespace('google.rpc')`.
  Implementing implicit namespace packages (as specified in PEP 420) is preferred to `pkg_resources.declare_namespace`. See https://setuptools.pypa.io/en/latest/references/keywords.html#keyword-namespace-packages
    pkg_resources.declare_namespace(__name__)

tests/test_update_vpc_peering.py::test_return_network
  /Users/zachbrooks/github.com/zbrooks422/gke-peering-event-function/.tox/py311/lib/python3.11/site-packages/google/auth/_default.py:78: UserWarning: Your application has authenticated using end user credentials from Google Cloud SDK without a quota project. You might receive a "quota exceeded" or "API not enabled" error. See the following page for troubleshooting: https://cloud.google.com/docs/authentication/adc-troubleshooting/user-creds. 
    warnings.warn(_CLOUD_SDK_CREDENTIALS_WARNING)

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
======================== 5 passed, 12 warnings in 1.38s ========================
.pkg: _exit> python /Users/zachbrooks/.local/pipx/venvs/tox/lib/python3.11/site-packages/pyproject_api/_backend.py True setuptools.build_meta
  lint: OK (11.25=setup[8.90]+cmd[2.34] seconds)
  py311: OK (9.59=setup[7.84]+cmd[1.75] seconds)
  congratulations :) (20.87 seconds)
```

### Functionality

The python code takes in the base64 log message from the pub/sub topic. It base64 decodes the message and extracts the required log fields. It then extracts the existing peering and constructs a new peering object with custom route export enabled. Then it executes the update peering operation to ensure custom route export is enabled.

### Logging/Monitoring

I've implemented some basic logging functionality. I log json based messages to standard out when issues occur. This could be greatly improved by using a standard logging framework/library that is meant for usage with GCP cloudfunctions. The logging that is implemented will at least tell you if it successfully updated a peering or if it failed in the cloudfunction logs. You may want to generate an alert if the GKE peering doesn't update successfully since GKE clusters using the peering will not be reachable.
