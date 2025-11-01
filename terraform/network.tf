resource "google_compute_network" "worker_vpc" {
  name                    = "worker-network"
  auto_create_subnetworks = false
}

locals {
  # Simple CIDR derivation: increment third octet by index for each region (/20 blocks)
  region_cidrs = {
    for idx, r in tolist(var.regions) : r => cidrsubnet("10.10.0.0/16", 4, idx) # gives /20 ranges
  }
}

resource "google_compute_subnetwork" "worker_subnet" {
  for_each      = local.region_cidrs
  name          = "worker-network-${each.key}"
  ip_cidr_range = each.value
  region        = each.key
  network       = google_compute_network.worker_vpc.id
}

resource "google_compute_firewall" "ssh" {
  name    = "worker-network-allow-ssh"
  network = google_compute_network.worker_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags  = ["ssh-access"]
  source_ranges = ["0.0.0.0/0"]
}
