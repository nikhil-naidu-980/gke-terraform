provider "google" {
  project = "your-gcp-project-id"
  region  = "us-west2"  # Choose an appropriate region
}

# Create the VPC
resource "google_compute_network" "main" {
  name                    = "main-vpc"
  auto_create_subnetworks = false
}