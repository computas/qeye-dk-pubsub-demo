####################
# Outputs
####################
output "topic" {
  value = google_pubsub_topic.tasks.name
}

output "subscription" {
  value = google_pubsub_subscription.tasks_sub.name
}

output "results_bucket" {
  value = google_storage_bucket.results.url
}

output "scripts_bucket" {
  value = google_storage_bucket.scripts.url
}

output "mig_ids" {
  description = "Map of region to managed instance group id"
  value       = { for r, mig in google_compute_region_instance_group_manager.spot_mig : r => mig.id }
}

output "autoscaler_names" {
  description = "Map of region to autoscaler name"
  value       = { for r, as in google_compute_region_autoscaler.spot_autoscaler : r => as.name }
}
