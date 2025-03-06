# Provider Configuration
provider "google" {
  region = "us-west1"
  project = "rare-hub-452618-j9"
}

data "google_client_config" "default" {}

# Kubernetes provider configuration for connecting to the GKE cluster
provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

# Create the VPC
resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks  = false  # We will create custom subnets
}

# Create the public subnet, linked to the custom VPC
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  region        = "us-west1"
  network       = google_compute_network.vpc.id  # Ensure this subnet is in the custom VPC
  ip_cidr_range = "10.0.1.0/24"
  private_ip_google_access = true
}

# Create the private subnet, also linked to the custom VPC
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  region        = "us-west1"
  network       = google_compute_network.vpc.id  # Ensure this subnet is in the custom VPC
  ip_cidr_range = "10.0.2.0/24"
  private_ip_google_access = true
}

# Create a firewall rule to allow external access to GKE nodes
resource "google_compute_firewall" "gke_allow_inbound" {
  name    = "gke-allow-inbound"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-node"]
}

# Create the GKE cluster
resource "google_container_cluster" "gke" {
  name     = "my-gke-cluster"
  location = "us-west1-a"

  initial_node_count = 1

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    tags = ["gke-node"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  networking_mode = "VPC_NATIVE"

  # Explicitly reference the custom VPC subnetwork
  subnetwork = google_compute_subnetwork.public_subnet.id  # Correct reference to the public subnet

  # Explicitly disable deletion protection
  deletion_protection = false

  # Configure private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  # Explicitly reference the custom VPC network
  network = google_compute_network.vpc.id  # This ensures the GKE cluster is associated with the custom VPC
}

# IAM Role for GKE Cluster (for service account used by GKE)
resource "google_service_account" "gke_service_account" {
  account_id   = "gke-service-account"
  display_name = "GKE Service Account"
}

# IAM Role Attachment for GKE Service Account
resource "google_project_iam_member" "gke_service_account_role" {
  project = "rare-hub-452618-j9"
  role    = "roles/container.clusterAdmin"
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}

# IAM Roles for the GKE Node (required to access the GKE nodes)
resource "google_project_iam_member" "gke_node_role" {
  project = "rare-hub-452618-j9"
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}

resource "google_project_iam_member" "gke_node_pull_images" {
  project = "rare-hub-452618-j9"
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}

resource "google_project_iam_member" "gke_service_account_artifact_registry" {
  project = "rare-hub-452618-j9"
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}

# Create GKE Node Pool
resource "google_container_node_pool" "node_pool" {
  name       = "default-node-pool"
  location   = "us-west1-a"
  cluster    = google_container_cluster.gke.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    tags = ["gke-node"]
    service_account = google_service_account.gke_service_account.email
  }
}

# Create Namespace for the application
resource "kubernetes_namespace" "nginx_app_namespace" {
  metadata {
    name = "nginx-app-namespace"
  }
}

# Deploying nginx application
resource "kubernetes_deployment" "nginx_app_deployment" {
  metadata {
    name      = "nginx-app-deployment"
    namespace = kubernetes_namespace.nginx_app_namespace.metadata[0].name
    labels = {
      app = "nginx-app"
    }
  }

  spec {
    replicas = 1 
    selector {
      match_labels = {
        app = "nginx-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-app"
        }
        annotations = {
          "cloud.google.com/neg" = jsonencode({"exposed_ports" = {"80" = {}}}) 
        }
      }

      spec {
        node_selector = {
          "cloud.google.com/gke-nodepool" = google_container_node_pool.node_pool.name
        }

        container {
          name  = "nginx-app-container"
          image = "nginx:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Create the Service for the Nginx Deployment
resource "kubernetes_service" "nginx_app_service" {
  metadata {
    name      = "nginx-app-service"
    namespace = kubernetes_namespace.nginx_app_namespace.metadata[0].name
    annotations = {
      "cloud.google.com/neg" = jsonencode({"exposed_ports" = {"80" = {}}})
    }
  }

  spec {
    selector = {
      app = "nginx-app"
    }

    port {
      port        = 80
      target_port = "80"
    }

    type = "ClusterIP"
  }
}

# External data source to fetch the NEG name dynamically
data "external" "fetch_neg_name" {
  depends_on = [kubernetes_service.nginx_app_service] 
  program    = ["bash", "${path.module}/fetch_neg_name.sh"]
}

data "google_compute_network_endpoint_group" "nginx_neg" {
  depends_on = [kubernetes_service.nginx_app_service]
  name       = data.external.fetch_neg_name.result["neg_name"] 
  zone       = "us-west1-a"
}

# HTTP Health Check
resource "google_compute_health_check" "nginx_health_check" {
  name               = "nginx-health-check"
  check_interval_sec = 10
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# Backend Service with NEG
resource "google_compute_backend_service" "nginx_backend" {
  name        = "nginx-backend"
  protocol    = "HTTP"
  timeout_sec = 30

  backend {
    group            = data.google_compute_network_endpoint_group.nginx_neg.id # Updated reference
    balancing_mode   = "RATE"
    max_rate_per_endpoint = 100
  }

  health_checks = [google_compute_health_check.nginx_health_check.self_link]
}