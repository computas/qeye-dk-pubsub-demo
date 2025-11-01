terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.9"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  access_token = var.auth_token
}
