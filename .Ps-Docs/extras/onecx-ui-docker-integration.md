# OneCX UI Docker Image Integration Guide

This guide provides comprehensive steps to integrate a custom OneCX UI microfrontend into the OneCX local environment using Docker images.

## Overview

Integrating a UI into OneCX requires:
1. **Product Registration** - Define the product in product-store
2. **Microfrontend Registration** - Register the MFE with module federation details
3. **Permission Setup** - Configure permissions and role assignments
4. **Workspace Registration** - Add the product to a workspace with menu entry
5. **Docker Compose Configuration** - Set up container with traefik routing

## Prerequisites

- OneCX local environment set up and running (`onecx-local-env`)
- Your UI project built with Angular and Module Federation
- Docker installed
- Node.js and npm installed
- `@onecx/local-env-cli` package available

## Directory Structure

```
onecx-local-env/
├── compose.yaml                    # Main compose file
├── versions/v2/.env               # Environment variables (images)
├── .env                           # Root env (for custom compose files)
├── <product>.compose.yaml         # Custom product compose file
├── init-data/
│   └── traefik/
│       ├── base/traefik-conf.yml  # Traefik configuration
│       └── active/                # Hot reload configs (*.yml)
└── onecx-data/
    ├── product-store/
    │   ├── products/              # Product definitions
    │   ├── microfrontends/        # MFE registrations
    │   └── microservices/         # Service definitions
    ├── permission/                # Permission definitions
    ├── permission-assignment/     # Role -> Permission mappings
    └── workspace/                 # Workspace configurations
```

## Integration Steps

### Step 1: Build Your UI

```bash
cd /path/to/your-ui-project
npm install
npm run build
```

### Step 2: Build Docker Image

```bash
# Clean build
rm -rf .nx/cache ./dist
npm run build

# Build Docker image
docker build --no-cache -t <product-name>-ui:latest .
```

### Step 3: Sync UI with OneCX (Recommended - Using CLI)

The `@onecx/local-env-cli` automates creating all necessary configuration files.

```bash
cd /path/to/your-ui-project

# Sync UI configuration (creates product, microfrontend, permissions, etc.)
npx @onecx/local-env-cli sync ui <product-name> /<base-path> ./helm/values.yaml \
  -e /path/to/onecx-local-env \
  -n <product-name>-ui

# Create menu entry in workspace
npx @onecx/local-env-cli menu create <product-name>-ui /<base-path>/<feature-path> "<Display Name>" \
  -e /path/to/onecx-local-env

# Create docker compose entry
npx @onecx/local-env-cli docker <product-name> create <product-name> <mfePath> \
  -e /path/to/onecx-local-env \
  -s ui
```

**Parameters:**
- `<product-name>`: Your product name (e.g., `test-book-app`)
- `<base-path>`: Product base URL path (e.g., `/test-book-app`)
- `<mfePath>`: MFE routing path without `/mfe/` prefix (e.g., `bookCatalog` for `/mfe/bookCatalog/`)

### Step 4: Configure Docker Compose (Manual or Adjust CLI Output)

Create or update `<product-name>.compose.yaml`:

```yaml
include:
  - compose.yaml

services:
  <product-name>-ui:
    image: ${<PRODUCT_NAME>_UI:-<product-name>-ui:latest}
    # Alternative: build from source
    # build:
    #   context: /path/to/your-ui-project
    #   dockerfile: Dockerfile
    container_name: <product-name>-ui
    environment:
      APP_BASE_HREF: /mfe/<mfePath>/
      APP_ID: <product-name>-ui
      PRODUCT_NAME: <product-name>
      BFF_URL: "http://<product-name>-bff:8080"  # If using BFF
    labels:
      - traefik.http.services.<product-name>-ui.loadbalancer.server.port=8080
      - traefik.http.routers.<product-name>-ui.rule=Host(`onecx.localhost`) && PathPrefix(`/mfe/<mfePath>/`)
    networks:
      - onecx
    profiles:
      - all
      - <product-name>
```

### Step 5: Add Environment Variable (Optional)

If using image reference instead of build, add to `/root/.env` or `versions/v2/.env`:

```env
<PRODUCT_NAME>_UI=<product-name>-ui:latest
```

### Step 6: Import Data and Start

```bash
cd /path/to/onecx-local-env

# Import product data (if starting fresh)
./import-onecx.sh

# Start with custom compose file
docker compose -f <product-name>.compose.yaml --profile all up -d --build
```

## Key Files Created by CLI

### Product Definition (`onecx-data/product-store/products/<product-name>.json`)

```json
{
  "version": "xxx",
  "description": "<product description>",
  "basePath": "/<base-path>",
  "displayName": "<Display Name>",
  "iconName": "pi-briefcase"
}
```

### Microfrontend Registration (`onecx-data/product-store/microfrontends/<product>_<service>_main.microfrontend.json`)

```json
{
  "appName": "<product-name>",
  "description": "OneCX <Product> Module",
  "remoteBaseUrl": "/mfe/<mfePath>/",
  "remoteEntry": "/mfe/<mfePath>/remoteEntry.js",
  "exposedModule": "./<ModuleName>Module",
  "technology": "WEBCOMPONENTMODULE",
  "remoteName": "<remote-name>",
  "tagName": "<product>-webcomponent",
  "type": "MODULE"
}
```

### Permission Assignment (`onecx-data/permission-assignment/<product-name>.json`)

```json
{
  "<product-name>": {
    "<product-name>-ui": {
      "onecx-admin": {
        "<RESOURCE>": ["CREATE", "EDIT", "DELETE", "VIEW", "SEARCH"]
      }
    }
  }
}
```

### Workspace Product Entry (in `onecx-data/workspace/default_ADMIN.json`)

```json
{
  "productName": "<product-name>",
  "baseUrl": "/<base-path>",
  "microfrontends": [
    {
      "appId": "<product-name>-ui",
      "basePath": "/"
    }
  ]
}
```

## Troubleshooting

### Container Exits with "host not found in upstream"

**Cause:** Nginx config references a BFF service that doesn't exist.

**Solution:** Either:
1. Add BFF service to compose file
2. Set `BFF_URL` environment variable to a valid service (e.g., `http://localhost:8080`)
3. Modify nginx `locations.conf` to remove BFF proxy if not needed

### remoteEntry.js Returns 404

**Cause:** Either the container isn't running, routing is misconfigured, or the build is incomplete.

**Solutions:**
1. Check container status: `docker ps -a | grep <product-name>`
2. Check container logs: `docker logs <product-name>-ui`
3. Verify build output exists: `ls dist/<project-name>/remoteEntry.js`
4. Verify traefik routing label matches `APP_BASE_HREF`

### UI Not Appearing in Shell Menu

**Cause:** Missing workspace registration or menu entry.

**Solution:**
1. Run menu create command (CLI)
2. Manually add to workspace JSON
3. Re-import workspace data: `./import-onecx.sh`

### Container Not Starting with --profile all

**Cause:** `test-book-app-ui` is in `profiles: [all]` but you ran with `--profile base`.

**Solution:** Use matching profile: `docker compose -f <file>.yaml --profile all up -d`

## Quick Reference Commands

```bash
# Build UI and Docker image
npm run build && docker build --no-cache -t <name>:latest .

# Start services
docker compose -f <product>.compose.yaml --profile all up -d --build

# Check logs
docker logs <container-name>

# Stop services
docker compose -f <product>.compose.yaml --profile all down

# Import data
./import-onecx.sh

# Check container status
docker ps --filter "name=<product>"
```

## Access URLs

- **OneCX Shell:** `http://onecx.localhost/onecx-shell/admin/`
- **MFE Direct:** `http://onecx.localhost/mfe/<mfePath>/remoteEntry.js`
- **Traefik Dashboard:** `http://localhost:8082/dashboard/`
