####################
# Variables
####################
variable "project_id" {
  type        = string
  description = "GCP project id"
}

# gcp auth token - set with: -var auth_token=$(gcloud auth print-access-token)
variable "auth_token" {
  type = string
}

variable "region" {
  type        = string
  description = "Region for this MIG (e.g. europe-west3). You can replicate the MIG+autoscaler for additional regions."
  default     = "europe-west3"
}

variable "regions" {
  type        = list(string)
  description = "List of regions to deploy instance groups and autoscalers. Includes primary region by default."
  default     = ["europe-west3"]
}

variable "zone" {
  type        = string
  description = "Zone for zonal operations (used for some imports/console). Example: europe-west3-a"
  default     = "europe-west3-a"
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "image_family" {
  type    = string
  default = "debian-12" # change as desired
}

variable "messages_per_vm" {
  type    = number
  default = 4
  description = "How many concurrent unacked messages we consider assignable to one VM (used by autoscaler singleInstanceAssignment). Tune this."
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 5
}
