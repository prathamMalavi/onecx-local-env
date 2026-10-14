---
name: onecx-local-env-cli
description: Use this skill to deploy and integrate a generated OneCX PoC application into a running OneCX Local Environment using the @onecx/local-env-cli tool.
---

# OneCX Local Env CLI

Integrates a generated OneCX PoC application into a running OneCX Local Environment. This skill provides the knowledge needed to use `@onecx/local-env-cli` to register the application's UI (and optionally BFF/SVC) with the OneCX platform, create navigation menu entries, and configure Docker Compose deployment.

## Use When

- A PoC has been generated and needs to be integrated into a running OneCX Local Environment.
- You need to register a microfrontend (UI) with the OneCX product registry.
- You need to create a menu entry for a new application in the OneCX workspace.
- You need to add services to the Docker Compose configuration for local deployment.

## Do Not Use When

- The OneCX Local Environment has not been set up or is not running — instruct the user to set it up first.
- You need to generate the UI, BFF, or SVC code — use the `onecx-capabilities` skill and the OneCX generator for that.
- You need to modify the OneCX platform itself — this skill is only for integrating applications.

## Prerequisites

1. **OneCX Local Environment must be set up and running**. The user must have already cloned, configured, and started their `onecx-local-env` instance. If it is not running, **pause and instruct the user** to start it before proceeding.

2. **`ONECX_LOCAL_ENV_PATH`** must be set in `forge.env` at the workspace root. This variable points to the user's local `onecx-local-env` repository directory.

3. **Node.js and npm** must be installed (the CLI is invoked via `npx`).

4. **The PoC application** must already be generated (UI folder must exist with a valid `helm/values.yaml` or equivalent configuration).

## Configuration

The path to the OneCX Local Environment is read from `forge.env`:

```bash
ONECX_LOCAL_ENV_PATH=/path/to/onecx-local-env
```

To read this value programmatically:

```bash
source forge.env
echo "$ONECX_LOCAL_ENV_PATH"
```

If `ONECX_LOCAL_ENV_PATH` is empty or `forge.env` does not exist, **stop and ask the user** to configure it.

## Commands

All commands below must be executed **from within the PoC application's UI directory**.

### 1. Sync UI with OneCX Product Registry

Registers the product, MFE, permissions, and workspace entries:

```bash
npx @onecx/local-env-cli sync ui <product-name> /<base-path> ./helm/values.yaml \
  -e <env-path> \
  -n <product-name>-ui
```

| Parameter | Description | Example |
|-----------|-------------|---------|
| `<product-name>` | Product identifier with `onecx-` prefix | `onecx-my-poc` |
| `/<base-path>` | Base URL path for the application (with leading `/`, include `onecx-` prefix) | `/onecx-my-poc` |
| `/<angular-internal-route>` | Angular internal route for the application (with leading `/`, derived from `app-routing.module.ts`) | `/page` |
| `<env-path>` | Absolute path to the `onecx-local-env` directory (`ONECX_LOCAL_ENV_PATH`) | `/root/onecx/onecx-local-env` |
| `<product-name>-ui` | Logical name for the UI service (with `onecx-` prefix) | `onecx-my-poc-ui` |

### 2. Create Menu Entry

Creates a navigation entry in the OneCX workspace shell:

```bash
npx @onecx/local-env-cli menu create <product-name>-ui <menu-path> "<menu-label>" \
  -e <env-path>
```

| Parameter | Description | Example |
|-----------|-------------|---------|
| `<menu-path>` | Menu entry path in workspace (must start with `/`, use `/<base-path>/<angular-internal-route>`) | `/onecx-my-poc/angular-internal-route` |
| `<menu-label>` | Display label shown in the shell menu | `My PoC App` |

> **Note:** Use `/<base-path>/<angular-internal-route>` where `<angular-internal-route>` is derived from the Angular routing module (`app-routing.module.ts`). Do NOT guess; read the routing module. `/main` will blank-screen if that route doesn't exist.

### 3. Create Docker Compose File

Generates `<env-path>/<product-name>.compose.yaml` with image, build, and Traefik labels:

```bash
npx @onecx/local-env-cli docker <product-name> create <product-name> <mfe-name> \
  -e <env-path> \
  -s ui
```

| Parameter | Description | Example |
|-----------|-------------|---------|
| `<mfe-name>` | MFE name as registered in product-store (camelCase, no prefix) | `myPoc` |
| `-s ui` | Service type: `ui`, `bff`, or `svc` (UI-only deployments do not require BFF) | `ui` |

### 4. Restart the OneCX Environment

After running the three commands above, restart the environment so OneCX picks up the newly registered product data:

```bash
cd <env-path>
./start-onecx.sh -p all
```

Wait for the environment to be fully healthy before proceeding (all containers in 'healthy' or 'running' state).

> **What gets imported on restart:** Products, MFEs, permissions, and permission-assignments are imported via operator (PUT) endpoints — these are idempotent and work on any restart. The workspace (products + menu) is imported via ExIm (POST) which **SKIPS existing workspaces**. Step 5 below handles this.

### 5. Register Product to Workspace (REQUIRED)

> ⚠️ **This step is mandatory.** The CLI updates `onecx-data/workspace/default_ADMIN.json` with product and menu entries, but the workspace ExIm import always returns `"ADMIN": "SKIPPED"` for existing workspaces. Step 5 applies those changes via the workspace REST API (no DB access required).

Run the agent-owned script from the **agent's skill scripts directory**:

```bash
bash .github/skills/onecx-local-env-cli.scripts/register-workspace.sh \
  -e <env-path> \
  -p <product-name>
```

| Parameter | Description |
|-----------|-------------|
| `-e` | Absolute path to `onecx-local-env` directory (`ONECX_LOCAL_ENV_PATH`) |
| `-p` | Product name (e.g., `onecx-my-poc`) |

The script automatically reads product details from the generated files. No manual parameters needed.

Expected output: `[SKIP]` or `[OK]` for product registration, then `[OK] Menu imported (status: UPDATED)`.

> **What the script does:** Reads product base URL from `product-store/products/<product>.json` and permission app_id from `permission/<product>_<app-id>.json`. Calls `POST /internal/products` to add the product (idempotent), then calls `POST /exim/v1/workspace/ADMIN/menu/import` to replace the full menu with what is in `default_ADMIN.json`. This is safe to re-run.

## Hot Reload Setup

After the CLI commands, configure hot reload so your local Angular dev server is used instead of a Docker container. Changes are reflected immediately without rebuilding images.

### Step 1: Modify the Generated Compose File

The generated `<product-name>.compose.yaml` runs the UI as a Docker container. Comment out the `image`, `build`, and `labels` blocks, and add `- base` to profiles:

```yaml
services:
  <product-name>-ui:
    # image: ${<PRODUCT_NAME>_UI}        # commented: not using Docker image for hot reload
    container_name: <product-name>-ui
    environment:
      APP_BASE_HREF: /mfe/<mfe-path>/
      APP_ID: <product-name>-ui
      PRODUCT_NAME: <product-name>
      BFF_URL: "http://localhost:8080"  # optional: only if BFF exists
    # labels:                            # commented: Traefik routing handled by toggle-mfes.sh
    #   - traefik.http.services...
    #   - traefik.http.routers...
    networks:
      - onecx
    profiles:
      - all
      - base                            # ADD THIS — CLI only generates 'all'
    # remove depends_on if no BFF needed — UI-only deployments work without it
```

> Keep all lines — just comment out `image`, `build`, and `labels`. Do not delete them so Docker image mode can be re-enabled later.

### Step 2: Activate Traefik Hot Reload Routing

Use `toggle-mfes.sh` to route Traefik to the local dev server. **Never create the Traefik config file manually** — the script uses a template that includes the required `stripPrefix` middleware:

```bash
cd <env-path>
./toggle-mfes.sh -a <mfe-name>:<port>:/mfe/<mfe-path>
```

| Part | Description | Example |
|------|-------------|---------|
| `<mfe-name>` | Identifier for Traefik service/router names | `myPoc` |
| `<port>` | Local dev server port | `4200` |
| `/mfe/<mfe-path>` | Full URL prefix, must start with `/mfe/` | `/mfe/myPoc` |

The script writes `init-data/traefik/active/<mfe-name>_<port>.yml`. Traefik auto-detects the file — no restart needed.

Other `toggle-mfes.sh` operations:

```bash
./toggle-mfes.sh -l                        # list active configs
./toggle-mfes.sh -d <mfe-name>:<port>      # deactivate one
./toggle-mfes.sh -c                        # remove all
```

### Step 3: Configure proxy.conf.js

The PoC's `proxy.conf.js` must rewrite the MFE path so the dev server receives requests at `/` instead of `/mfe/<mfe-path>/`:

```javascript
const bypassFn = function (req, res) {
  try {
    if (req.method === 'OPTIONS') {
      res.setHeader('Allow', 'GET, POST, HEAD, PUT, DELETE, OPTIONS');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', '*');
      res.setHeader('Access-Control-Allow-Headers', '*');
      return res.send('');
    }
    return null;
  } catch (error) {
    console.log('error', error);
  }
};

const PROXY_CONFIG = {
  '/mfe/<mfe-path>': {
    target: 'http://localhost:<port>/',
    secure: false,
    pathRewrite: { '^.*/mfe/<mfe-path>': '' },
    changeOrigin: true,
    logLevel: 'debug',
    bypass: bypassFn,
  },
  '/bff': {
    target: 'http://<product-name>-bff',
    secure: false,
    pathRewrite: { '^.*/bff': '' },
    changeOrigin: true,
    logLevel: 'debug',
    bypass: bypassFn,
  },
};

module.exports = PROXY_CONFIG;
```

### Step 4: Start the Dev Server

**The dev server must bind to `0.0.0.0`** (not `127.0.0.1`) so Traefik can reach it via `host.docker.internal`. Pass this as a runtime flag — do **not** modify `project.json` to hardcode it:

```bash
cd <poc-ui-path>
npm start -- --host 0.0.0.0 --port <port> --disable-host-check
```

Verify the binding:

```bash
ss -tlnp | grep <port>
# Must show: 0.0.0.0:<port>
# If it shows 127.0.0.1:<port>, Traefik cannot reach the dev server
```

### Step 5: Verify the Integration

```bash
curl -H "Host: onecx.localhost" http://localhost/mfe/<mfe-path>/remoteEntry.js
# Expect: HTTP 200 with JavaScript content
```

Then open `http://onecx.localhost/onecx-shell/admin/` in your browser to see the app in the shell.

## Switching to Docker Image Mode

Use this when you want to run the PoC as a proper Docker container instead of a local dev server.

### Step 1: Deactivate Traefik Hot Reload Routing (if previously active)

Skip this step if you have not previously set up hot reload for this MFE.

```bash
cd <env-path>
./toggle-mfes.sh -d <mfe-name>:<port>
```

### Step 2: Build the UI

```bash
cd <poc-ui-path>
npm install

# Clean build
rm -rf .nx/cache ./dist
npm run build
```

### Step 3: Build the Docker Image

```bash
docker build --no-cache -t <product-name>-ui:latest .
```

### Step 4: Configure Environment Variables

Create or update `.env` in the `onecx-local-env` root **and** `versions/v2/.env`, adding the image reference:

```dotenv
# <PRODUCT_NAME> must be upper-cased and hyphen-replaced with underscore
# Always use onecx- prefix
<PRODUCT_NAME>_UI=<product-name>-ui:latest
# <PRODUCT_NAME>_BFF=<product-name>-bff:latest
```

Example for a product named `onecx-my-poc`:
```dotenv
ONECX_MY_POC_UI=onecx-my-poc-ui:latest
```

### Step 5: Uncomment image/build/labels in Compose File

In `<env-path>/<product-name>.compose.yaml`, uncomment the `image`, `build`, and `labels` blocks that were commented out during hot reload setup.

### Step 6: Restart OneCX Environment

```bash
cd <env-path>
./start-onecx.sh -p all
```

This picks up the new compose file and starts the UI container.

Alternatively, start only the new service without a full restart:

```bash
# Option A — attach to existing stack using base profile
docker compose -f versions/v2/compose.yaml -f <product-name>.compose.yaml --profile base up -d <product-name>-ui

# Option B — rebuild and start with the product compose file directly
docker compose -f <product-name>.compose.yaml --profile base up -d --build
```

### Step 7: Verify

```bash
curl -H "Host: onecx.localhost" http://localhost/mfe/<mfe-path>/remoteEntry.js
# Expect: HTTP 200 with JavaScript content
```

## Known Issues

### Profile mismatch — service never starts

**Cause:** CLI-generated compose sets `profiles: [all]` only. `./start-onecx.sh -p base` excludes the service.  
**Fix:** Add `- base` to profiles in the compose file (Step 1 above).

### 502 Bad Gateway — dev server not reachable

**Cause:** Dev server bound to `127.0.0.1`. Traefik connects via `host.docker.internal` (host IP) — it cannot reach loopback.  
**Diagnosis:** `ss -tlnp | grep <port>` — must show `0.0.0.0`, not `127.0.0.1`.  
**Fix:** Always start with `--host 0.0.0.0`.

### Manually created Traefik file missing strip middleware

**Cause:** Missing `stripPrefix` middleware means the full `/mfe/<mfe-path>/` path is forwarded to the dev server instead of `/`.  
**Fix:** Always use `./toggle-mfes.sh -a` — never create the Traefik config file manually.

### `host.docker.internal` not resolving on Linux

**Diagnosis:**
```bash
docker exec traefik getent hosts host.docker.internal
```
**Fix:** Add `extra_hosts: ["host.docker.internal:host-gateway"]` to the traefik service in compose.

### `include:` in compose file shows empty services

**Cause:** Docker Compose doesn't inherit network/profile context via `include:`.  
**Fix:** Use multiple `-f` flags instead:
```bash
docker compose -f versions/v2/compose.yaml -f <product-name>.compose.yaml --profile base up -d
```

### Container exits with "host not found in upstream"

**Cause:** Nginx config references a BFF service that doesn't exist.  
**Fix:** Set `BFF_URL` to a valid service (e.g., `http://localhost:8080`) in the compose environment block, or modify `nginx/locations.conf` to remove the BFF proxy if a BFF is not needed.

### remoteEntry.js returns 404

**Cause:** Container not running, routing misconfigured, or build incomplete.  
**Diagnosis:**
```bash
docker ps -a | grep <product-name>      # check container status
docker logs <product-name>-ui           # check container logs
ls dist/<project-name>/remoteEntry.js   # verify build output
```
Verify that the Traefik routing label matches `APP_BASE_HREF`.

### UI not appearing in shell menu

**Cause:** The workspace ExIm import **SKIPS existing workspaces** — it returns `"ADMIN": "SKIPPED"` every time. Entries added to `default_ADMIN.json` are never applied to the running DB after the first bootstrap.  
**Fix:** Run Command 5 (agent-owned script). Do **NOT** rely on `./import-onecx.sh` for this — it will not apply workspace changes.

### Blank screen after clicking menu entry

**Cause:** Menu URL doesn't match any Angular route. The shell strips the product `base_url` and passes the remainder to the Angular router. If the remainder doesn't match a route, the app renders nothing.  
**Example:** URL `/onecx-my-poc` → Angular receives empty string → no matching route → blank screen.  
**Fix:** Use `/<base-path>/<angular-route>` where `<angular-route>` is the first route prefix from `src/app/app-routing.module.ts`. For `matcher: startsWith('X')`, use `X`. For `path: 'X'`, use `X`. Read the file — do not guess.

### Permission error "Missing permission key: BOOK#SEARCH"

**Cause (CLI bug):** `sync ui` names the MFE file using the webpack `remoteName` (e.g., `book-catalog`) as the second filename segment. The second segment becomes the `app_id` in the product-store. The permission system uses the image-derived name (e.g., `onecx-book-catalog-ui`). When they don't match, the MFE sends `appId=book-catalog` to the permission service which has permissions for `onecx-book-catalog-ui` → Unauthorized.  
**Fix:** The deployer agent's Step 3a handles this automatically. Manually:
```bash
# Rename MFE file (second segment must match permission file second segment)
mv onecx-data/product-store/microfrontends/<product>_<remoteName>_main.json \
   onecx-data/product-store/microfrontends/<product>_<permissionAppId>_main.json

# Then re-run import and workspace registration
./start-onecx.sh -p all
bash .github/skills/onecx-local-env-cli.scripts/register-workspace.sh -e . -p <product>
```

## Quick Reference

```bash
# Full deployment sequence (from within PoC directory)
npx @onecx/local-env-cli sync ui <product-name> /<base-path> ./helm/values.yaml -e <env-path> -n <product-name>-ui
npx @onecx/local-env-cli menu create <product-name>-ui /<base-path>/<angular-route> "<label>" -e <env-path>
npx @onecx/local-env-cli docker <product-name> create <product-name> <mfe-name> -e <env-path> -s ui

# Fix CLI app_id bug (after sync ui, if MFE second segment != permission second segment)
# See deployer.agent.md Step 3a for the fix commands

# Restart environment (from <env-path>)
./start-onecx.sh -p all

# REQUIRED: Register to workspace (agent-owned script, from agent directory)
bash .github/skills/onecx-local-env-cli.scripts/register-workspace.sh -e <env-path> -p <product-name>

# Hot reload: activate Traefik routing (from <env-path>)
./toggle-mfes.sh -a <mfe-name>:<port>:/mfe/<mfe-path>

# Build UI and Docker image
npm run build && docker build --no-cache -t <product-name>-ui:latest .

# Stop and restart services (full cycle - recommended after config changes)
./stop-onecx.sh -p all
./start-onecx.sh -p all

# Start only new service (no full restart)
docker compose -f versions/v2/compose.yaml -f <product-name>.compose.yaml --profile base up -d <product-name>-ui

# Check logs
docker logs <product-name>-ui

# Stop services
docker compose -f <product-name>.compose.yaml --profile all down

# Check container status
docker ps --filter "name=<product-name>"
```

## Access URLs

- **OneCX Shell:** `http://onecx.localhost/onecx-shell/admin/`
- **MFE remoteEntry:** `http://onecx.localhost/mfe/<mfe-path>/remoteEntry.js`
- **Traefik Dashboard:** `http://localhost:8082/dashboard/`
