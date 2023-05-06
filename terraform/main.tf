
locals {
  sink_filters = [
    "protoPayload.methodName = \"v1.compute.networks.addPeering\"",
    "protoPayload.request.networkPeering.name: (\"gke-\" AND \"-peer\")",
    "protoPayload.resourceName: (\"${var.project_id}\" AND \"${var.network_name}\")"
  ]
  sink_filter = join(" AND ", local.sink_filters)
  default_labels = {"network_name" = var.network_name, "purpose" = "gke_peering_events"}
  labels = merge(var.labels, local.default_labels)
}

resource "google_project_service" "eventarc_api" {
  project = var.project_id
  service = "eventarc.googleapis.com"

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_on_destroy = false
}

resource "google_pubsub_topic" "pubsub" {
  name   = "vpc-peering-gke-${var.network_name}-pubsub"
  labels = var.labels
}

resource "google_logging_project_sink" "vpc_peering_sink" {
  name                   = "vpc-peering-gke-${var.network_name}-sink"
  description            = "Filters addPeering events for a specific network"
  destination            = "pubsub.googleapis.com/${google_pubsub_topic.pubsub.id}"
  filter                 = local.sink_filter
  unique_writer_identity = true
}

resource "google_project_iam_member" "vpc_peering_sink_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.vpc_peering_sink.writer_identity
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "../src"
  output_path = "./function-source.zip"
}

resource "google_storage_bucket" "cf-bucket" {
  name                        = "${var.network_name}-vpc-peering-cf"
  location                    = var.bucket_location
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "cf-object" {
  name       = "${data.archive_file.source.id}.zip"
  bucket     = google_storage_bucket.cf-bucket.name
  source     = "function-source.zip"
  depends_on = [data.archive_file.source]
}

resource "google_service_account" "cf-service-account" {
  account_id   = "${var.network_name}-vpc-peering-cf-sa"
  display_name = "Service Account used by CloudFunction to update gke VPC peerings with export_custom_routes"
}

resource "google_project_iam_member" "cf-service-account-iam" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.cf-service-account.email}"
}

resource "google_cloudfunctions2_function" "function" {
  name = "${var.network_name}-vpc-peering-cf"
  location = var.region
  description = "Function to update GKE peerings for network ${var.network_name} with custom route export"

  build_config {
    runtime = "python311"
    entry_point = "update_peering"  # Set the entry point 
    source {
      storage_source {
        bucket = google_storage_bucket.cf-bucket.name
        object = google_storage_bucket_object.cf-object.name
      }
    }
  }

  service_config {
    vpc_connector = var.vpc_connector != "" ? var.vpc_connector : null
    vpc_connector_egress_settings = var.vpc_connector != "" ? "ALL_TRAFFIC" : null
    environment_variables = {
      NETWORK_NAME = var.network_name,
      PROJECT_ID = var.project_id
    }
    available_memory   = "256M"
    max_instance_count = 5
    timeout_seconds    = 300
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.pubsub.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }

  depends_on = [
    google_project_service.eventarc_api
  ]
}
