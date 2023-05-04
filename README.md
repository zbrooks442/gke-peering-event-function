# gke-peering-event-function
GCP Cloudfunction that responds to VPC peering events for GKE and automatically adds custom route export

## Summary

Google Kubernetes Engine (GKE) is the Google Cloud specific implementation of Kubernetes. When deploying private GKE clusters, worker nodes will go in customer owned VPCs and masters go in a special gke tenant VPC owned/managed by Google. GKE will automatically build a VPC peering between customer VPCs and tenant VPCs as needed and remove the peerings if all clusters are deleted. Additionally, these peerings are regional so if you use a global VPC and deploy GKE into multiple regions, expect to see a peering per region.

## Problem

The peerings always start with gke- and end with -peer. The issue with Google dynamically building these peerings is there is not a way to enable custom route exports on these peerings when they are built. It must be added in after the fact and this is a problem when the networking stack is managed as code. If you attempt to modify this these peerings using [terraform](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering_routes_config) and the peering is deleted, your terraform will break and you must remove the resource from state. You may want route export because there is a private connection from your corporate infrastructure that developers use to reach the master nodes and without route export, it will be unreachable. The tenant VPC will not have a return route for your users.

## Solution

My solution to this issue is to build a CloudFunction that is executed when the creation of vpc peerings happens. CloudFunctions have support for a set number of events natively using the cloudevents [specification](https://github.com/cloudevents/spec) but this event in particular is not supported [Google Supported Events](https://github.com/googleapis/google-cloudevents).

The workaround is to setup a logsink in stackdriver so certain log messages are forwarded to a pub/sub topic which can then trigger execution of the cloud function. These events come in as base64 encoded json so they must be decoded and processed before they can be used. [Google Documentation](https://cloud.google.com/functions/docs/calling/logging)

### Example Log Query for addPeering Events

    resource.type="gcp_network"
    protoPayload.methodName="v1.compute.networks.addPeering"
    protoPayload.request.networkPeering.name: ("gke-" AND "-peer")
    protoPayload.resourceName: ("<project_id>" AND "<network_name>")