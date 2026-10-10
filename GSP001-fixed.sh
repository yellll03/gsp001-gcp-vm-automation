#!/usr/bin/env bash
# Fixed version of GSP001.sh (Creating a Virtual Machine)
# Fixes: ZONE/PROJECT not set, firewall rule never applied to the VM,
# NGINX installed on Cloud Shell instead of (only) the VM, no wait for SSH,
# no check that NGINX is actually serving.

export REGION="${REGION:-us-east5}"
export ZONE="${ZONE:-us-east5-a}"
export DEVSHELL_PROJECT_ID="${DEVSHELL_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"

gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE"

# Firewall rules matching the console's "Allow HTTP/HTTPS traffic" (tags http-server / https-server)
gcloud compute firewall-rules create default-allow-http --network=default \
  --allow=tcp:80 --target-tags=http-server --source-ranges=0.0.0.0/0 2>/dev/null
gcloud compute firewall-rules create default-allow-https --network=default \
  --allow=tcp:443 --target-tags=https-server --source-ranges=0.0.0.0/0 2>/dev/null

# Task 1: gcelab. A leftover Debian 11 VM (EOL, apt is broken) is deleted and rebuilt on Debian 12.
if gcloud compute disks describe gcelab --zone="$ZONE" --format='get(sourceImage)' 2>/dev/null | grep -q 'debian-11'; then
  gcloud compute instances delete gcelab --zone="$ZONE" --quiet
fi
if ! gcloud compute instances describe gcelab --zone="$ZONE" >/dev/null 2>&1; then
  gcloud compute instances create gcelab \
    --project="$DEVSHELL_PROJECT_ID" --zone="$ZONE" --machine-type=e2-medium \
    --image-family=debian-12 --image-project=debian-cloud \
    --boot-disk-size=10GB --boot-disk-type=pd-balanced \
    --tags=http-server,https-server
fi
gcloud compute instances add-tags gcelab --zone="$ZONE" --tags=http-server,https-server

# Task 3: gcelab2
gcloud compute instances describe gcelab2 --zone="$ZONE" >/dev/null 2>&1 || \
  gcloud compute instances create gcelab2 --machine-type e2-medium --zone="$ZONE"

# Task 2: install NGINX on the VM (retry until SSH is ready)
for i in $(seq 1 10); do
  if gcloud compute ssh gcelab --zone="$ZONE" --project="$DEVSHELL_PROJECT_ID" --quiet \
      --command "sudo apt-get update && sudo apt-get install -y nginx && sudo systemctl enable --now nginx && sudo systemctl restart nginx && ps auwx | grep nginx"; then
    break
  fi
  echo "SSH not ready, retrying ($i/10)..."; sleep 15
done

# Verify
IP=$(gcloud compute instances describe gcelab --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
for i in $(seq 1 12); do
  curl -s -m 5 "http://$IP/" | grep -q "Welcome to nginx" && { echo "NGINX OK: http://$IP/"; break; }
  sleep 5
done
