# GKE with Nginx Deployment and Global Load Balancer

This repository contains the Terraform configuration to set up a Google Kubernetes Engine (GKE) cluster on Google Cloud and deploy a simple Nginx application with a Global HTTP Load Balancer using Google Cloud's Network Endpoint Groups (NEG).

## Prerequisites

Before using this repository, ensure that you have the following:

- **Google Cloud account** with the appropriate permissions.
- **Terraform** installed. You can install it from [Terraform's website](https://www.terraform.io/downloads.html).
- **Google Cloud SDK** installed and authenticated. Follow [Google Cloud SDK installation instructions](https://cloud.google.com/sdk/docs/install).

## Project Overview

The repository includes:

1. **`main.tf`**: A Terraform script to:
   - Set up a GKE cluster.
   - Configure VPC and subnets.
   - Create firewall rules, IAM roles, and permissions.
   - Deploy an Nginx application in Kubernetes.
   - Set up a Global HTTP Load Balancer using NEG (Network Endpoint Groups).

2. **`fetch_neg_name.sh`**: A bash script used to fetch the NEG name dynamically. It is used in the `main.tf` to gather the necessary information for setting up the backend service in the load balancer.

## Setup and Usage

Follow the steps below to deploy the infrastructure.

### 1. Clone the Repository

Start by cloning the repository to your local machine:

```bash
git clone <your-repo-url>
cd <your-repo-directory>
```

### 2. Configure Google Cloud Provider

In the main.tf file, the provider is set to Google Cloud (google provider). Ensure that the project ID and region are correctly configured for your Google Cloud account:

```bash
provider "google" {
  region  = "us-west1"      # Update region if needed
  project = "your-project-id"  # Replace with your actual Google Cloud project ID
}
```

### 3. Authenticate Google Cloud

Ensure that you are authenticated with Google Cloud by running:

```bash
gcloud auth login
gcloud config set project <your-project-id>
```

### 4. Initialize Terraform

Run the following command to initialize the Terraform configuration:

```bash
terraform init
```

This will download the necessary Terraform provider plugins.

### 5. Apply the Terraform Configuration

To create the resources, apply the Terraform plan:

```bash
terraform apply
```

This will download the necessary Terraform provider plugins. You can run ```terraform plan``` before running ```terraform apply``` to see what changes you are going to make before applying the changes.

### 6. Verify the Deployment

Once the infrastructure is deployed, you can check the status of the GKE cluster and other resources using the Google Cloud Console or ```gcloud``` CLI. The application should be available through a global IP created by Terraform.

```bash
terraform apply
```

You can also access your application by visiting the external IP assigned to the load balancer in the ```google_compute_global_address``` resource.

### 7. Clean Up

To delete the created resources when you no longer need them, run the following command:


```bash
terraform destroy
```

This will remove all the resources created by Terraform.









