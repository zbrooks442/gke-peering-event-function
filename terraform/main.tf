




locals {
  sink_filters = [
    "resource.type = \"gcp_network\"",
    "protoPayload.methodName = \"v1.compute.networks.addPeering\"",
    "protoPayload.request.networkPeering.name: (\"gke-\" AND \"-peer\")",
    "protoPayload.resourceName: (\"${var.project_id}\" AND \"${var.network_name}\")"
  ]
  sink_filter = join(" AND ", local.sink_filters)
}

resource "google_logging_project_sink" "vpc_peering_sink" {
  name        = "vpc-peering-${var.network_name}-sink"
  description = "some explanation on what this is"
  destination = "storage.googleapis.com/${google_storage_bucket.log-bucket.name}"
  filter      = local.sink_filter

  unique_writer_identity = true
}