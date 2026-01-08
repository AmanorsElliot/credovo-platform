# Orchestration Service

## Local Development

### Building the Docker Image

**Important**: The Dockerfile expects to be built from the repository root, not from the service directory.

To build locally:

```bash
# From the repository root
cd /path/to/credovo-platform
docker build -f services/orchestration-service/Dockerfile -t orchestration-service:local .
```

**Do NOT** build from the service directory:
```bash
# This will NOT work
cd services/orchestration-service
docker build .  # ❌ This will fail
```

### Running Locally

```bash
npm install
npm run build
npm start
```

## Deployment

The service is automatically deployed via GitHub Actions when changes are pushed to the main branch.

Manual deployment:

```bash
gcloud run deploy orchestration-service \
  --image europe-west1-docker.pkg.dev/credovo-platform-dev/credovo-services/orchestration-service:latest \
  --region europe-west1 \
  --platform managed \
  --service-account orchestration-service@credovo-platform-dev.iam.gserviceaccount.com
```


