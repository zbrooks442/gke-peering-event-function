<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.4.6 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 4.63.1 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 4.63.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.3.0 |
| <a name="provider_google"></a> [google](#provider\_google) | 4.63.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloudfunctions2_function.function](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function) | resource |
| [google_logging_project_sink.vpc_peering_sink](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_sink) | resource |
| [google_project_iam_member.cf-service-account-iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.vpc_peering_sink_pubsub](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.eventarc_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_pubsub_topic.pubsub](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_service_account.cf-service-account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_storage_bucket.cf-bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_object.cf-object](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [archive_file.source](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_location"></a> [bucket\_location](#input\_bucket\_location) | Bucket location | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Optional resource labels | `map(string)` | `{}` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the network for function to monitor gke peerings | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID for resources | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region for deployment | `string` | n/a | yes |
| <a name="input_vpc_connector"></a> [vpc\_connector](#input\_vpc\_connector) | Optional VPC connector for cloud function | `string` | `""` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->