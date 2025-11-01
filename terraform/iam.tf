resource "google_service_account" "worker_sa" {
  account_id   = "compute-worker-sa"
  display_name = "Worker VM service account"
}

# Grant Pub/Sub subscriber and storage write access to the worker service account
resource "google_project_iam_binding" "worker_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:${google_service_account.worker_sa.email}"
  ]
}

resource "google_project_iam_binding" "worker_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.worker_sa.email}"
  ]
}

resource "google_project_iam_member" "cache_manager_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = google_service_account.worker_sa.member
}

resource "google_project_iam_member" "cache_manager_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.worker_sa.member
}
