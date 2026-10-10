#!/usr/bin/env bash
# GSP001 - Creating a Virtual Machine (Compute Engine) - automation
# Run in Cloud Shell:  bash gsp001-automation.sh
# Optional overrides:  REGION=us-east5 ZONE=us-east5-a bash gsp001-automation.sh
set -euo pipefail

REGION="${REGION:-us-east5}"
ZONE="${ZONE:-us-east5-a}"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"

echo "Project: ${PROJECT_ID} | Region: ${REGION} | Zone: ${ZONE}"
gcloud config set project "${PROJECT_ID}" >/dev/null
gcloud config set compute/region "${REGION}"
gcloud config set compute/zone "${ZONE}"

# Task 1: VM with HTTP firewall (equivalent of "Allow HTTP traffic")
if ! gcloud compute firewall-rules describe default-allow-http >/dev/null 2>&1; then
  gcloud compute firewall-rules create default-allow-http \
    --network=default \
    --direction=INGRESS \
    --allow=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server
fi

# Task 1 + 2: gcelab, with NGINX installed via startup script (no manual SSH needed)
gcloud compute instances create gcelab \
  --zone="${ZONE}" \
  --machine-type=e2-medium \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=10GB \
  --boot-disk-type=pd-balanced \
  --tags=http-server \
  --metadata=startup-script='#! /bin/bash
apt-get update
apt-get install -y nginx
systemctl enable --now nginx'

# Task 3: gcelab2 with gcloud defaults
gcloud compute instances create gcelab2 \
  --machine-type=e2-medium \
  --zone="${ZONE}"

# Verify NGINX on gcelab
EXTERNAL_IP=$(gcloud compute instances describe gcelab --zone="${ZONE}" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "Waiting for NGINX at http://${EXTERNAL_IP}/ ..."
for i in $(seq 1 30); do
  if curl -s --max-time 5 "http://${EXTERNAL_IP}/" | grep -q "Welcome to nginx"; then
    echo "NGINX is up: http://${EXTERNAL_IP}/"
    break
  fi
  sleep 10
done

gcloud compute instances list
echo "Done. Click 'Check my progress' in the lab."
