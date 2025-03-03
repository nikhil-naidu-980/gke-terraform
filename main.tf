# Provider Configuration
provider "google" {
  region = "us-west1"
  project = "rare-hub-452618-j9"
}

# Create the VPC
resource "google_compute_network" "vpc" {
  name = "gke-vpc"
  auto_create_subnetworks = "false" # Use custom subnet creation
}

# Create the public subnet
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  region        = "us-west1"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.1.0/24"
  private_ip_google_access = false

  # Enable public IPs for GKE nodes
}

# Create the private subnet (for nodes without public IPs)
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  region        = "us-west1"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.2.0/24"
  private_ip_google_access = true
}
