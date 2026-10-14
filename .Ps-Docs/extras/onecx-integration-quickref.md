# OneCX UI Integration Quick Reference

## File Locations Summary

```
your-ui-project/
├── helm/values.yaml              # Product/MFE configuration (used by CLI)
├── Dockerfile                    # Docker build config
├── proxy.conf.js                 # Dev server proxy (for hot reload)
├── webpack.config.js             # Module Federation config
├── onecx-integration.config.json # Agent configuration (optional)
└── dist/<project>/               # Build output
    └── remoteEntry.js            # ⭐ Module Federation entry

onecx-local-env/
├── compose.yaml                  # Main compose (includes v2)
├── <product>.compose.yaml        # ⭐ Custom product compose
├── .env                          # Environment variables (for custom compose)
├── versions/v2/.env              # Main environment variables
├── scripts/
│   └── integrate-ui.sh           # ⭐ Integration automation script
├── init-data/
│   └── traefik/
│       ├── base/
│       │   ├── traefik-conf.yml
│       │   └── traefik-services.yml
│       └── active/
│           └── <product>_<port>.yml  # ⭐ Hot reload config
└── onecx-data/
    ├── product-store/
    │   ├── products/<product>.json           # Product definition
    │   ├── microfrontends/<p>_<ui>_main.microfrontend.json  # MFE registration
    │   └── microservices/<p>_<ui>.json       # Service definition
    ├── permission/<product>_<ui>.json        # Permissions
    ├── permission-assignment/<product>.json  # Role mappings
    └── workspace/default_ADMIN.json          # Workspace + menu
```

## Quick Commands

### Using the Integration Script

```bash
# Docker integration
cd /path/to/your-ui
./path/to/onecx-local-env/scripts/integrate-ui.sh docker ./onecx-integration.config.json

# Hot reload
./path/to/onecx-local-env/scripts/integrate-ui.sh hot-reload ./onecx-integration.config.json
```

### Using local-env-cli

```bash
# Sync product data (FIRST — registers product/MFE/permissions)
npx @onecx/local-env-cli sync ui <product> /<basePath> ./helm/values.yaml \
  -e /path/to/onecx-local-env -n <product>-ui

# Create menu entry (SECOND)
npx @onecx/local-env-cli menu create <product>-ui /<basePath>/<feature> "<Name>" \
  -e /path/to/onecx-local-env

# Create compose entry (THIRD)
npx @onecx/local-env-cli docker <product> create <product> <mfePath> \
  -e /path/to/onecx-local-env -s ui
```

### Docker Commands

```bash
# Build image
npm run build && docker build --no-cache -t <product>-ui:latest .

# Start with compose
docker compose -f <product>.compose.yaml --profile all up -d --build

# Check status
docker ps --filter "name=<product>"

# View logs
docker logs <product>-ui

# Stop container
docker stop <product>-ui
```

### Hot Reload Commands

```bash
# Activate Traefik routing to local dev server (generates active/<mfe-name>_<port>.yml)
cd <env-path>
./toggle-mfes.sh -a <mfe-name>:<port>:/mfe/<mfe-path>

# List all active hot-reload configs
./toggle-mfes.sh -l

# Deactivate hot-reload routing
./toggle-mfes.sh -d <mfe-name>:<port>

# Start local dev server — must bind to 0.0.0.0, NOT 127.0.0.1
cd /path/to/your-ui-project
npm start -- --host 0.0.0.0 --port <port> --disable-host-check

# Verify server is reachable by Traefik
ss -tlnp | grep <port>
# Must show: 0.0.0.0:<port>  (not 127.0.0.1:<port>)

# Verify routing end-to-end
curl -H "Host: onecx.localhost" http://localhost/mfe/<mfe-path>/remoteEntry.js
```

## Key URLs

| Service | URL |
|---------|-----|
| OneCX Shell | `http://onecx.localhost/onecx-shell/admin/` |
| Your MFE | `http://onecx.localhost/mfe/<mfePath>/` |
| remoteEntry.js | `http://onecx.localhost/mfe/<mfePath>/remoteEntry.js` |
| Traefik Dashboard | `http://localhost:8082/dashboard/` |
| Keycloak | `http://keycloak-app.localhost:8080/` |

## Configuration Templates

### Compose File (Docker Image Mode)

> **Do NOT use `include:`** — Docker Compose does not resolve service-level networks/profiles correctly via `include:` in this setup. Always use multiple `-f` flags when running.

```yaml
services:
  <product-name>-ui:
    image: ${<PRODUCT_NAME>_UI}          # variable from versions/v2/.env
    # build:                             # uncomment to build from source instead
    #   context: /path/to/your-ui-project
    #   dockerfile: Dockerfile
    container_name: <product-name>-ui
    environment:
      APP_BASE_HREF: /mfe/<mfe-path>/
      APP_ID: <product-name>-ui
      PRODUCT_NAME: <product-name>
      BFF_URL: "http://localhost:8080"    # use localhost if no real BFF running
    labels:
      - traefik.http.services.<product-name>-ui.loadbalancer.server.port=8080
      - traefik.http.routers.<product-name>-ui.rule=Host(`onecx.localhost`) && PathPrefix(`/mfe/<mfe-path>/`)
    networks:
      - onecx
    profiles:
      - all
      - base                             # add both profiles to match start-onecx.sh -p base
```

Start with:
```bash
docker compose -f versions/v2/compose.yaml -f <product-name>.compose.yaml --profile base up -d
```

### Hot Reload Traefik Config

> Do NOT create this file manually. Use `./toggle-mfes.sh -a <mfe-name>:<port>:/mfe/<mfe-path>` — it generates the file from the template in `init-data/traefik/inactive/_mfe_template.yml`.

Generated file location: `init-data/traefik/active/<mfe-name>_<port>.yml`

```yaml
http:
  routers:
    local_<mfe-name>:
      rule: "Host(`onecx.localhost`) && PathPrefix(`/mfe/<mfe-path>/`)"
      service: local_<mfe-name>
      priority: 323
      middlewares:
        - strip_<mfe-name>
  middlewares:
    strip_<mfe-name>:
      stripPrefix:
        prefixes:
          - "/mfe/<mfe-path>"       # strips prefix before forwarding to dev server
  services:
    local_<mfe-name>:
      loadBalancer:
        servers:
          - url: "http://host.docker.internal:<port>/"  # host.docker.internal = host machine from inside Docker
```

## Troubleshooting Checklist

- [ ] Is the container running? (`docker ps`)
- [ ] Does remoteEntry.js load? (Browser: `/mfe/<path>/remoteEntry.js`)
- [ ] Is product synced? (Check `onecx-data/product-store/products/`)
- [ ] Is workspace registered? (Check `onecx-data/workspace/default_ADMIN.json`)
- [ ] For hot reload: Is traefik config in `active/`?
- [ ] For hot reload: Is docker container stopped?
- [ ] Traefik routing visible? (`http://localhost:8082/dashboard/`)
