# init stuff

resource "google_storage_bucket" "scripts" {
  name     = "${var.project_id}-compute-scripts-${random_id.bucket_suffix.hex}"
  location = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "worker_py" {
  name   = "worker.py"
  bucket = google_storage_bucket.scripts.name
  source = "${path.module}/../scripts/worker.py"
  content_type = "text/x-python"
}

resource "google_storage_bucket_object" "startup_sh" {
  name   = "startup.sh"
  bucket = google_storage_bucket.scripts.name
  source = "${path.module}/../scripts/startup.sh"
  content_type = "text/x-shellscript"
}


# MIG

data "google_compute_image" "worker_image" {
  family  = var.image_family
  project = "debian-cloud"
}

resource "google_compute_instance_template" "spot_worker" {
  for_each = toset(var.regions)
  name_prefix = "spot-worker-tpl-${each.key}-"

  machine_type = var.machine_type
  can_ip_forward = false

  disk {
    auto_delete  = true
    boot         = true
    source_image = data.google_compute_image.worker_image.self_link
  }

  network_interface {
    network    = google_compute_network.worker_vpc.id
    subnetwork = google_compute_subnetwork.worker_subnet[each.key].id
    access_config {}
  }

  tags = ["ssh-access"]

  scheduling {
    # PROVISIONING_MODEL set to SPOT to create Spot VMs
    provisioning_model = "SPOT"
    on_host_maintenance = "TERMINATE"
    automatic_restart    = false
    preemptible          = true
  }

  service_account {
    email  = google_service_account.worker_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    PROJECT_ID    = var.project_id
    SUBSCRIPTION  = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.tasks_sub.name}"
    RESULTS_BUCKET = google_storage_bucket.results.name
    SCRIPTS_BUCKET = google_storage_bucket.scripts.name
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail
    export PROJECT_ID="${var.project_id}"
    export SUBSCRIPTION="projects/${var.project_id}/subscriptions/${google_pubsub_subscription.tasks_sub.name}"
    export RESULTS_BUCKET="${google_storage_bucket.results.name}"
    export SCRIPTS_BUCKET="${google_storage_bucket.scripts.name}"
    # Download and run external startup script from the scripts bucket
    TOKEN=$(curl -s -H "Metadata-Flavor: Google" "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token" | python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])')
    curl -fsSL -H "Authorization: Bearer $TOKEN" "https://storage.googleapis.com/${google_storage_bucket.scripts.name}/startup.sh" -o /tmp/startup.sh
    chmod +x /tmp/startup.sh
    /tmp/startup.sh
  EOT
}

resource "google_compute_region_instance_group_manager" "spot_mig" {
  for_each           = toset(var.regions)
  name               = "spot-workers-${each.key}"
  region             = each.key
  base_instance_name = "spot-worker"
  version {
    instance_template  = google_compute_instance_template.spot_worker[each.key].self_link
    name               = "v1"
  }
  target_size = max(var.min_size, 1)
}

resource "google_compute_region_autoscaler" "spot_autoscaler" {
  for_each = google_compute_region_instance_group_manager.spot_mig
  name     = "spot-autoscaler-${each.key}"
  region   = each.key
  # Use self_link to ensure clear dependency and proper destroy ordering
  target   = each.value.self_link

  autoscaling_policy {
    min_replicas = max(var.min_size, 1)
    max_replicas = var.max_size
    cpu_utilization { target = 0.6 }
    cooldown_period = 60
  }
}
