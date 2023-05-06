variable "network_name" {
  description = "Name of the network for function to monitor gke peerings"
  type        = string
}

variable "project_id" {
  description = "Project ID for resources"
  type        = string
}

variable "vpc_connector" {
  description = "Optional VPC connector for cloud function"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Optional resource labels"
  type        = map(string)
  default     = {}
}

variable "bucket_location" {
  description = "Bucket location"
  type        = string
}

variable "region" {
  description = "Region for deployment"
  type        = string
}