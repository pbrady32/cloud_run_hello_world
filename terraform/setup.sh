#!/bin/bash

# Apply Terraform configuration to create the GCS bucket
terraform init
terraform apply -auto-approve

# Get the bucket name and prefix from the output
BUCKET_NAME=$(terraform output -json backend_configuration | jq -r '.bucket_name')
PREFIX=$(terraform output -json backend_configuration | jq -r '.prefix')

# Create the backend.tf file with the bucket name
cat <<EOF >backend.tf
terraform {
  backend "gcs" {
    bucket      = "${BUCKET_NAME}"
    prefix      = "${PREFIX}"
    credentials = "umms-hernia-api-dev-7c7f200c2799.json"
  }
}
EOF

# Reinitialize Terraform with the new backend configuration
terraform init