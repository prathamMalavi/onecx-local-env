#!/usr/bin/env bash
#
# integrate-mfe.sh
#
# Registers an Angular MFE with OneCX local environment and activates hot reload routing.
# Place this file in the root of your MFE project and fill in the variables below.
#
# Usage: ./integrate-mfe.sh
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION — fill in all blank values before running
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────

# Absolute path to your onecx-local-env clone.
ONECX_LOCAL_ENV_PATH="/root/onecx/dev-new/onecx-local-env"

# Product name in kebab-case.
# Used as the product-store key, service prefix, and compose file name.
# Example: hello-world
PRODUCT_NAME="onecx-angular-21-module-test"

# MFE name in camelCase — the path segment defined in your values.yaml.
# This is the <name> part of the routing path /mfe/<name>/.
# Open helm/values.yaml and look for the mfe basePath, e.g.:
#   basePath: /mfe/helloWorld/  →  set MFE_NAME="helloWorld"
MFE_NAME="onecx-angular-21-module-test-ui"

# Base URL path for the product (must start with /).
# Leave blank to auto-derive from PRODUCT_NAME (i.e. /<PRODUCT_NAME>).
BASE_PATH="/onecx-angular-21-module-test"

# Path to the Helm values.yaml, relative to this script's directory.
HELM_VALUES_PATH="./helm/values.yaml"

# Full menu entry path inside the OneCX workspace.
# Example: /hello-world/hello
MENU_PATH="/onecx-angular-21-module-test/"

# Label shown in the shell navigation sidebar.
# Example: Hello World
MENU_LABEL="Onecx Angular 21 Module Test"

# Port your Angular dev server runs on.
# Example: 4200
PORT="4006"

# "false" → new app: runs full product registration (sync, menu, compose) then hot reload setup.
# "true"  → already registered: skips registration steps, only applies hot reload setup.
EXISTING_APP="false"

# Path to your proxy.conf.js (or .json), relative to this script's directory.
# Leave blank to auto-search: checks angular.json/project.json proxyConfig
# reference first, then falls back to ./src/proxy.conf.js and ./proxy.conf.js.
PROXY_CONF_PATH=""




DB_CHANGE="true"
EXPOSED_MODULE="./RemoteModule"
SHARE_SCOPE="angular_21"




# ─────────────────────────────────────────────────────────────────────────────


readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

log()  { printf '%b\n' "${CYAN}[integrate-mfe]${NC} $*"; }
ok()   { printf '%b\n' "${GREEN}[integrate-mfe]${NC} $*"; }
warn() { printf '%b\n' "${YELLOW}[integrate-mfe]${NC} $*"; }
err()  { printf '%b\n' "${RED}[integrate-mfe]${NC} $*"; }

# ─── Defaults ─────────────────────────────────────────────────────────────────

[[ -z "$BASE_PATH" && -n "$PRODUCT_NAME" ]] && BASE_PATH="/$PRODUCT_NAME"

# Auto-detect MFE_NAME from values.yaml basePath field
if [[ -z "$MFE_NAME" && -f "$HELM_VALUES_PATH" ]]; then
  _detected_mfe=$(grep -o '/mfe/[^/"[:space:]]*' "$HELM_VALUES_PATH" | head -1 | sed 's|/mfe/||;s|/$||')
  if [[ -n "$_detected_mfe" ]]; then
    MFE_NAME="$_detected_mfe"
    log "Auto-detected MFE_NAME from values.yaml: $MFE_NAME"
  fi
fi

# Auto-detect PROXY_CONF_PATH from angular.json / project.json / common paths
if [[ -z "$PROXY_CONF_PATH" ]]; then
  for _cfg in angular.json project.json; do
    if [[ -f "$_cfg" ]]; then
        _p=$(grep -o '"proxyConfig"[[:space:]]*:[[:space:]]*"[^"]*"' "$_cfg" 2>/dev/null | grep -o '"[^"]*\(\(\.js\)\|\(\.json\)\)"' | head -1 | tr -d '"' || true)      
        if [[ -n "$_p" ]]; then
        PROXY_CONF_PATH="$_p"
        log "Auto-detected PROXY_CONF_PATH from $_cfg: $PROXY_CONF_PATH"
        break
      fi
    fi
  done
fi
if [[ -z "$PROXY_CONF_PATH" ]]; then
  for _candidate in ./src/proxy.conf.js ./proxy.conf.js ./src/proxy.conf.json ./proxy.conf.json; do
    if [[ -f "$_candidate" ]]; then
      PROXY_CONF_PATH="$_candidate"
      log "Auto-detected PROXY_CONF_PATH: $PROXY_CONF_PATH"
      break
    fi
  done
fi

# ─── Validation ───────────────────────────────────────────────────────────────

MISSING=()
[[ -z "$ONECX_LOCAL_ENV_PATH" ]] && MISSING+=("ONECX_LOCAL_ENV_PATH")
[[ -z "$PRODUCT_NAME"         ]] && MISSING+=("PRODUCT_NAME")
[[ -z "$MFE_NAME"             ]] && MISSING+=("MFE_NAME")
[[ -z "$BASE_PATH"            ]] && MISSING+=("BASE_PATH")
[[ -z "$MENU_PATH"            ]] && MISSING+=("MENU_PATH")
[[ -z "$MENU_LABEL"           ]] && MISSING+=("MENU_LABEL")
[[ -z "$PORT"                 ]] && MISSING+=("PORT")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  err "The following required variables are not set:"
  for v in "${MISSING[@]}"; do
    err "  - $v"
  done
  err "Edit the CONFIGURATION section at the top of this script and re-run."
  exit 1
fi

if [[ ! -d "$ONECX_LOCAL_ENV_PATH" ]]; then
  err "ONECX_LOCAL_ENV_PATH does not exist: $ONECX_LOCAL_ENV_PATH"
  exit 1
fi

readonly CLI="npx @onecx/local-env-cli"
readonly MFE_SERVICE_NAME="${PRODUCT_NAME}-ui"

log "─────────────────────────────────────────────────────────────"
log " Product : $PRODUCT_NAME  (base: $BASE_PATH)"
log " MFE     : $MFE_NAME  →  /mfe/$MFE_NAME/"
log " Port    : $PORT"
log " Mode    : EXISTING_APP=$EXISTING_APP"
log "─────────────────────────────────────────────────────────────"

# ─── Steps 1–3: Product registration (new apps only) ─────────────────────────

if [[ "$EXISTING_APP" == "true" ]]; then
  warn "EXISTING_APP=true — skipping product registration (steps 1–3)."
else
  # Step 1: Sync UI
  log "Step 1/3 — Syncing UI with OneCX product registry …"
  log "  product: $PRODUCT_NAME | base-path: $BASE_PATH | values: $HELM_VALUES_PATH | service: $MFE_SERVICE_NAME"

  $CLI sync ui "$PRODUCT_NAME" "$BASE_PATH" "$HELM_VALUES_PATH" \
    -e "$ONECX_LOCAL_ENV_PATH" \
    -n "$MFE_SERVICE_NAME"

  ok "Step 1 done."

  # Step 2: Menu entry
  log "Step 2/3 — Creating menu entry …"
  log "  service: $MFE_SERVICE_NAME | path: $MENU_PATH | label: $MENU_LABEL"

  $CLI menu create "$MFE_SERVICE_NAME" "$MENU_PATH" "$MENU_LABEL" \
    -e "$ONECX_LOCAL_ENV_PATH"

  ok "Step 2 done."

  # Step 3: Docker compose
  log "Step 3/3 — Adding service to Docker compose …"
  log "  compose: $PRODUCT_NAME | product: $PRODUCT_NAME | mfe: $MFE_NAME"

  $CLI docker "$PRODUCT_NAME" create "$PRODUCT_NAME" "$MFE_NAME" \
    -e "$ONECX_LOCAL_ENV_PATH" \
    -s ui

  ok "Step 3 done."
fi

# ─── Step 5: Activate Traefik hot reload routing ──────────────────────────────

log "Step 5 — Activating Traefik hot reload routing …"
log "  config: $MFE_NAME:$PORT:/mfe/$MFE_NAME"

"$ONECX_LOCAL_ENV_PATH/toggle-mfes.sh" -a "${MFE_NAME}:${PORT}:/mfe/${MFE_NAME}"

ok "Step 5 done."

# ─── Step 6: Update package.json start script ────────────────────────────────

log "Step 6 — Updating package.json start script …"

if [[ ! -f "package.json" ]]; then
  warn "package.json not found in current directory — skipping."
else
  node -e "
    const fs = require('fs');
    const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    const start = pkg && pkg.scripts && pkg.scripts.start;
    if (!start) {
      console.log('  No start script found in package.json — skipping.');
      process.exit(0);
    }
    let updated = start;
    let changed = false;
    if (!updated.includes('--host 0.0.0.0')) {
      updated += ' --host 0.0.0.0';
      changed = true;
    }
    if (!updated.includes('--disable-host-check')) {
      updated += ' --disable-host-check';
      changed = true;
    }
    if (!updated.includes('--port')) {
      updated += ' --port=${PORT}';
      changed = true;
    }
    if (changed) {
      pkg.scripts.start = updated;
      fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
      console.log('  Updated start script to: ' + updated);
    } else {
      console.log('  Already has required flags — no changes needed.');
    }
  "
  ok "Step 6 done."
fi

# ─── Step 7: Update proxy.conf.js ────────────────────────────────────────────

log "Step 7 — Updating proxy.conf.js …"

if [[ -z "$PROXY_CONF_PATH" ]]; then
  warn "proxy.conf.js not found — add this entry to PROXY_CONFIG manually:"
  warn "    '/mfe/${MFE_NAME}': { target: 'http://localhost:${PORT}/', pathRewrite: { '^.*/mfe/${MFE_NAME}': '' }, ... }"
elif [[ ! -f "$PROXY_CONF_PATH" ]]; then
  warn "proxy.conf.js not found at: $PROXY_CONF_PATH — skipping."
else
  node -e "
    const fs = require('fs');
    const path = '$PROXY_CONF_PATH';
    const mfeName = '${MFE_NAME}';
    const port = '${PORT}';
    let content = fs.readFileSync(path, 'utf8');
    if (content.includes(\"'/mfe/\" + mfeName + \"'\")) {
      console.log('  Entry /mfe/' + mfeName + ' already present — no changes.');
      process.exit(0);
    }
    const entry = \"  '/mfe/\" + mfeName + \"': {\\n\"
      + \"    target: 'http://localhost:\" + port + \"/',\\n\"
      + \"    secure: false,\\n\"
      + \"    pathRewrite: { '^.*/mfe/\" + mfeName + \"': '' },\\n\"
      + \"    changeOrigin: true,\\n\"
      + \"    logLevel: 'debug',\\n\"
      + \"    bypass: bypassFn,\\n\"
      + \"  },\";
    const updated = content.replace(
      /const PROXY_CONFIG\\s*=\\s*\\{/,
      'const PROXY_CONFIG = {\\n' + entry
    );
    if (updated === content) {
      console.log('  Could not locate PROXY_CONFIG — add the entry manually.');
      process.exit(0);
    }
    fs.writeFileSync(path, updated);
    console.log('  Injected /mfe/' + mfeName + ' entry into ' + path);
  "
  ok "Step 7 done."
fi





# ─── Step X: Optional DB Update ─────────────────────────────────────────────

log "Step X — Optional DB update …"

if [[ "$DB_CHANGE" == "true" ]]; then

  if [[ -z "$SHARE_SCOPE" || -z "$EXPOSED_MODULE" ]]; then
    warn "DB_CHANGE=true but SHARE_SCOPE or EXPOSED_MODULE is empty — skipping DB update."
  else
    CONTAINER=$(docker ps --format "{{.Names}} {{.Image}}" | awk '$2 ~ /^postgres/ {print $1}' | head -n 1)

    if [[ -z "$CONTAINER" ]]; then
      warn "No Postgres container found — skipping DB update."
    else
      log "Using container: $CONTAINER"

      RESULT=$(docker exec -i "$CONTAINER" \
      psql -U postgres -d onecx_product_store -t -c \
      "UPDATE microfrontend
       SET share_scope = '${SHARE_SCOPE}'
       WHERE exposed_module = '${EXPOSED_MODULE}'
       AND (share_scope IS NULL OR share_scope != '${SHARE_SCOPE}');")

      # Extract update count (psql returns: UPDATE X)
      UPDATED=$(echo "$RESULT" | tr -d '[:space:]')

      if [[ "$UPDATED" == "UPDATE0" ]]; then
        ok "No rows updated."
      else
        ok "Rows updated: $UPDATED"
      fi
    fi
  fi

else
  log "DB_CHANGE=false — skipping DB update."
fi




# ─── Summary ──────────────────────────────────────────────────────────────────

printf '\n'
ok "─────────────────────────────────────────────────────────────"
ok " Integration complete for: $PRODUCT_NAME"
ok "─────────────────────────────────────────────────────────────"
printf '%b\n' "${CYAN}Next steps:${NC}"
printf 'Run ./import-onecx.sh to import OneCX data (permissions, product-store, workspace) if not already done.\n'
if [[ "$EXISTING_APP" != "true" ]]; then
  printf '%b\n' "  1. Review: ${ONECX_LOCAL_ENV_PATH}/${PRODUCT_NAME}.compose.yaml"
  printf '%b\n' "     - Comment out 'image', 'build', and 'labels' blocks for hot reload"
  printf '%b\n' "     - Ensure 'profiles' includes both 'all' and 'base'"
  printf '%b\n' "  2. Register the product to the ADMIN workspace (one-time manual step):"
  printf '%b\n' "       http://onecx.localhost/onecx-shell/admin/workspace/ADMIN → Applications tab"
  printf '%b\n' "  3. Start the containers:"
  printf '%b\n' "       docker compose -f versions/v2/compose.yaml -f ${PRODUCT_NAME}.compose.yaml --profile base up -d"
  printf '%b\n' "  4. Start your dev server:"
  printf '%b\n' "       npm start"
else
  printf '%b\n' "  1. Start your dev server:"
  printf '%b\n' "       npm start"
fi
printf '%b\n' ""
printf '%b\n' "  Verify hot reload routing:"
printf '%b\n' "       curl -H 'Host: onecx.localhost' http://localhost/mfe/${MFE_NAME}/remoteEntry.js"
printf '\n'
