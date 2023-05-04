# This is the main configuration file for Terraform
# We will set up our provider, backend, and resources here
# GCS will store our state file, and we will use Google as our provider
# We will also create a service account for our Cloud Run application

# --------------------------------------------------------------------------------------------------
# PREPARE PROVIDERS
# --------------------------------------------------------------------------------------------------
provider "google" {
  credentials = file("umms-hernia-api-dev-7c7f200c2799.json")
  project = "umms-hernia-api-dev"
  region  = "us-central1"
  zone    = "us-central1-c"
}

# --------------------------------------------------------------------------------------------------
# CREATE TFSTATE BUCKET
# --------------------------------------------------------------------------------------------------

# Create a Google Cloud Storage bucket that will house our Terraform state file
# This bucket will be used by all team members
# We will also set object versioning on the bucket to protect against accidental deletion
resource "google_storage_bucket" "terraform_state_bucket" {
  name     = "terraform_demo_state_bucket"
  location = "us-central1"
  versioning {
    enabled = true
  }
}

# Create a folder named 'terraform' in our terraform_demo_state_bucket
resource "google_storage_bucket_object" "terraform_state_bucket_object" {
  name   = "terraform/"
  bucket = google_storage_bucket.terraform_state_bucket.name
  content_type = "application/x-directory"
}

# The backend configuration holds our state file, so we can obtian a lock on it 
# to prevent team members from overwriting each other's changes
terraform {
  backend "gcs" {
    bucket = "terraform_demo_state_bucket"
    prefix = "terraform" 
   }
}

# --------------------------------------------------------------------------------------------------
# CREATE SERVICE ACCOUNTS
# --------------------------------------------------------------------------------------------------

# Create a service account for our Cloud Run application
# For this case it doesn't need any other permissions
# because it's not calling any other Google APIs
resource "google_service_account" "service_account" {
  account_id   = "cloud-run-hello-world-service-account"
  display_name = "Cloud Run Hello World Service Account"
}

# --------------------------------------------------------------------------------------------------
# CREATE SOURCE REPOSITORY
# --------------------------------------------------------------------------------------------------

# Create a Source Repository that mirrors a GitHub repository
# This will be used to trigger Cloud Build when a commit is pushed to GitHub
resource "google_sourcerepo_repository" "my_repo" {
  name = "cloud-run-hello-world-repo"
  description = "Cloud Run API Source Repository"
  mirrorConfig {
    url = "https://github.com/pbrady32/cloud_run_hello_world"
    }
}

# --------------------------------------------------------------------------------------------------
# CREATE CLOUD RUN SERVICE
# --------------------------------------------------------------------------------------------------

# We will use the service account we created above
# We will also set the container image to the one we built in Cloud Build
resource "google_cloud_run_service" "service" {
  name     = "cloud-run-api"
  location = "us-central1"
  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
      service_account_name = google_service_account.service_account.email
    }
  }
}

# Terraform needs Cloud Run Admin role for this
# Add a new principal to the Cloud Run service with the ability to invoke it
# The principle is: apidir-dev-ummshernia@api-dir-dev-c089.iam.gserviceaccount.com
# This is the service account for the API Directory
data "google_iam_policy" "admin" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:apidir-dev-ummshernia@api-dir-dev-c089.iam.gserviceaccount.com",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "policy" {
  location = google_cloud_run_service.service.location
  project = google_cloud_run_service.service.project
  service = google_cloud_run_service.service.name
  policy_data = data.google_iam_policy.admin.policy_data
}
