# GSP001 Automation

Automates the Google Cloud lab "Creating a Virtual Machine" (GSP001):

- Creates `gcelab` (e2-medium, Debian 12, 10 GB balanced disk, HTTP firewall rule)
- Installs NGINX on it via a startup script
- Creates `gcelab2` with gcloud defaults

## Usage (Cloud Shell)

```bash
git clone <this-repo-url> && cd <repo>
bash gsp001-automation.sh
```

Override defaults with `REGION=... ZONE=... bash gsp001-automation.sh`.
