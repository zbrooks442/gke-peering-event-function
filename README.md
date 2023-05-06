# gke-peering-event-function
GCP Cloudfunction that responds to VPC peering events for GKE and automatically adds custom route export

## Summary

Google Kubernetes Engine (GKE) is the Google Cloud specific implementation of Kubernetes. When deploying private GKE clusters, worker nodes will go in customer owned VPCs and masters go in a special gke tenant VPC owned/managed by Google. GKE will automatically build a VPC peering between customer VPCs and tenant VPCs as needed and remove the peerings if all clusters are deleted. Additionally, these peerings are regional so if you use a global VPC and deploy GKE into multiple regions, expect to see a peering per region.

## Problem

The peerings always start with gke- and end with -peer. The issue with Google dynamically building these peerings is there is not a way to enable custom route exports on these peerings when they are built. It must be added in after the fact and this is a problem when the networking stack is managed as code. If you attempt to modify this these peerings using [terraform](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering_routes_config) and the peering is deleted, your terraform will break and you must remove the resource from state. You may want route export because there is a private connection from your corporate infrastructure that developers use to reach the master nodes and without route export, it will be unreachable. The tenant VPC will not have a return route for your users.

## Solution

My solution to this issue is to build a CloudFunction that is executed when the creation of vpc peerings happens. CloudFunctions have support for a set number of events natively using the cloudevents [specification](https://github.com/cloudevents/spec) but this event in particular is not supported [Google Supported Events](https://github.com/googleapis/google-cloudevents).

The workaround is to setup a logsink in stackdriver so certain log messages are forwarded to a pub/sub topic which can then trigger execution of the cloud function. These events come in as base64 encoded json so they must be decoded and processed before they can be used. [Google Documentation](https://cloud.google.com/functions/docs/calling/logging)

The end result of this solution is that when a VPC peering is added, a cloudfunction is triggered and will add route export on the customer VPC. This ensures that any new GKE peerings which are added dynamically will also recieve custom routes from the customer VPC. This removes the requirement for an administrator to make this change especially when using a shared vpc.

## Terraform

This solution is implemented with Terraform. The terraform is in the example directory. The identity that runs terraform needs the required permissions to build out the resources in question. Refer to the readme within the terraform folder for the resources created.

### Setup

1. Setup your backend.tf or not if you want state to be stored locally
2. Create a tfvars file and populate with variable values (included example in terraform)
3. Run a `terraform init` to install the required providers
4. Run a `terraform plan` to ensure terraform runs as expected.

### Deployment

After you've followed the setup steps, you can deploy using `terraform apply`.

### Testing

You can test the solution two ways, I'll include some screenshots below.

1. Create a private GKE cluster and watch the VPC peering that gets created, you should see route export added after 20-30 seconds.
2. Build two test VPCs and build a VPC peering, name the peerings gke-<random>-peer. You should see route export added on the peering that is in your target VPC have route export added.

## Example Log Query for addPeering Events

A log Sink is used to filter out only VPC peering creation events for GKE peerings in particular. Below is the query that is used.

    protoPayload.methodName="v1.compute.networks.addPeering"
    protoPayload.request.networkPeering.name: ("gke-" AND "-peer")
    protoPayload.resourceName: ("<project_id>" AND "<network_name>")

## CloudFunction

The cloudfunction executes a python script which in-turn adds the required peering. Python cloudfunctions require the code to either be in a .zip archive or directory stored in a repo or GCS bucket. The example uses a GCS bucket and zip file.

### Requirements

Python cloud functions require two files to be present.

1. main.py
2. requirements.txt

main.py will contain your entrypoint function and this is also specified when you build the function. The requirements.txt file contains the required packages that need to be installed.

### Tests

I've added some unit tests as an example in the tests directory. Not all of these tests are great since it is difficult to mock some of the objects returned from the queries used by the Google compute SDK. Run the following steps to run the unit tests.

1. Install the module contained within src/modules (from root of repo) `pip install -e .`
2. Run unit tests from within tests folder `python -m unittest test_update_vpc_peering.py`

### Functionality

The python code takes in the base64 log message from the pub/sub topic. It base64 decodes the message and extracts the required log fields. It then extracts the existing peering and constructs a new peering object with custom route export enabled. Then it executes the update peering operation to ensure custom route export is enabled.
