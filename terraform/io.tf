resource "google_pubsub_topic" "tasks" {
  name = "compute-tasks"
}

resource "google_pubsub_subscription" "tasks_sub" {
  name  = "compute-tasks-sub"
  topic = google_pubsub_topic.tasks.name
  ack_deadline_seconds = 120
  # optional: message_retention_duration etc.
}

resource "google_storage_bucket" "results" {
  name     = "${var.project_id}-compute-results-${random_id.bucket_suffix.hex}"
  location = var.region
  uniform_bucket_level_access = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}
