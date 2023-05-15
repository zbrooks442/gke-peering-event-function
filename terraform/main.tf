
locals {
  sink_filters = [
    "protoPayload.methodName = \"v1.compute.networks.addPeering\"",
    "protoPayload.request.networkPeering.name: (\"gke-\" AND \"-peer\")",
    "protoPayload.resourceName: (\"${var.project_id}\" AND \"${var.network_name}\")"
  ]
  sink_filter = join(" AND ", local.sink_filters)
  default_labels = {"network_name" = var.network_name, "purpose" = "gke_peering_events"}
  labels = merge(var.labels, local.default_labels)
  required_apis  = ["artifactregistry.googleapis.com", "eventarc.googleapis.com", "run.googleapis.com"]
}

resource "random_string" "random" {
  length  = 8
  upper   = false
  special = false
}

resource "google_project_service" "required_apis" {
  project  = var.project_id
  for_each = toset(local.required_apis)
  service  = each.key

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_on_destroy = false
}

resource "google_pubsub_topic" "pubsub" {
  name   = "gkepeer-updater-${random_string.random.result}-pubsub"
  labels = var.labels
}

resource "google_logging_project_sink" "vpc_peering_sink" {
  name                   = "gkepeer-updater-${random_string.random.result}-sink"
  description            = "Filters addPeering events for network ${var.network_name}"
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
  name                        = "gkepeer-updater-${random_string.random.result}-bucket"
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
  account_id   = "gkepeer-updater-${random_string.random.result}"
  display_name = "gkepeer-updater-${random_string.random.result}"
}

resource "google_project_iam_member" "cf-service-account-iam-cr-invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.cf-service-account.email}"
}

resource "google_project_iam_member" "cf-service-account-iam-networkadmin" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.cf-service-account.email}"
}

resource "google_project_iam_member" "cf-service-account-iam-pubusb" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.cf-service-account.email}"
}

resource "google_cloudfunctions2_function" "function" {
  name = "gkepeer-updater-${random_string.random.result}-func"
  location = var.region
  description = "Function to update GKE peerings for network ${var.network_name}"

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
    available_memory      = "256M"
    max_instance_count    = 5
    timeout_seconds       = 300
    service_account_email = google_service_account.cf-service-account.email
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.pubsub.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.cf-service-account.email
  }

  depends_on = [
    google_project_service.required_apis
  ]
}
