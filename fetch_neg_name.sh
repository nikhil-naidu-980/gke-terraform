#!/bin/bash
set -e

# Query NEGs in us-west1-a and filter for the one related to nginx-app-service
NEG_NAME=$(gcloud compute network-endpoint-groups list \
  --filter="zone:us-west1-a nginx-app-service" \
  --format="value(name)" | head -n 1)

if [ -z "$NEG_NAME" ]; then
  echo "{\"error\": \"No NEG found for nginx-app-service in us-west1-a\"}" >&2
  exit 1
fi

# Output in JSON format as required by Terraform's external data source
echo "{\"neg_name\": \"$NEG_NAME\"}"