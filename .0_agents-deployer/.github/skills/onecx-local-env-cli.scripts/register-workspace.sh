#!/usr/bin/env bash
#
# register-workspace.sh
#
# Registers a product in the OneCX ADMIN workspace using the workspace REST API.
# Uses: POST /internal/products and POST /exim/v1/workspace/{name}/menu/import
#
# This is an AGENT-OWNED script. It does NOT depend on any local-env scripts.
# Uses only the workspace service REST API (no database injection).
#
# Usage:
#   ./register-workspace.sh -e <env-path> -p <product-name> [-w <workspace-name>]
#
# Options:
#   -e  Absolute path to onecx-local-env directory (ONECX_LOCAL_ENV_PATH)
#   -p  Product name (e.g., onecx-my-poc)
#   -w  Workspace name (default: ADMIN)
#
# What this script does:
#   1. Reads the product base URL and permission app_id from generated files in <env-path>
#   2. Gets the workspace ID via GET /internal/workspaces/search/{name}
#   3. Registers the product in the workspace (idempotent) via POST /internal/products
#   4. Imports the full menu from default_ADMIN.json via POST /exim/v1/workspace/{name}/menu/import
#      (This is a REPLACE operation — it replaces the full menu tree with what is in the file)
#
# The CLI commands (sync ui, menu create) already update default_ADMIN.json with the
# correct product and menu entries. This script applies those changes to the running environment.
#

set -euo pipefail

WS_SVC_URL="http://onecx-workspace-svc"
WORKSPACE_NAME="ADMIN"
PRODUCT_NAME=""
ENV_PATH=""

usage() {
  echo "Usage: $0 -e <env-path> -p <product-name> [-w <workspace-name>]"
  exit 1
}

while getopts ":e:p:w:" opt; do
  case "$opt" in
    e) ENV_PATH="$OPTARG" ;;
    p) PRODUCT_NAME="$OPTARG" ;;
    w) WORKSPACE_NAME="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z "$ENV_PATH" || -z "$PRODUCT_NAME" ]] && usage

WORKSPACE_FILE="$ENV_PATH/onecx-data/workspace/default_${WORKSPACE_NAME}.json"
if [[ ! -f "$WORKSPACE_FILE" ]]; then
  echo "[ERROR] Workspace file not found: $WORKSPACE_FILE"
  exit 1
fi

PRODUCT_FILE="$ENV_PATH/onecx-data/product-store/products/${PRODUCT_NAME}.json"
if [[ ! -f "$PRODUCT_FILE" ]]; then
  echo "[ERROR] Product file not found: $PRODUCT_FILE"
  exit 1
fi

# Derive permission app_id from permission filename (2nd segment of <product>_<app-id>.json)
PERM_FILE=$(ls "$ENV_PATH/onecx-data/permission/${PRODUCT_NAME}_"*.json 2>/dev/null | head -1)
if [[ -z "$PERM_FILE" ]]; then
  echo "[ERROR] No permission file found for product: $PRODUCT_NAME"
  exit 1
fi
PERM_FILENAME=$(basename "$PERM_FILE" .json)
PERMISSION_APP_ID="${PERM_FILENAME#${PRODUCT_NAME}_}"

# Read base URL from product file
BASE_URL=$(python3 -c "import json; d=json.load(open('$PRODUCT_FILE')); print(d['basePath'])")

echo "  Product       : $PRODUCT_NAME"
echo "  Permission ID : $PERMISSION_APP_ID"
echo "  Base URL      : $BASE_URL"
echo "  Workspace     : $WORKSPACE_NAME"

# ── Step 1: Get workspace ID ──────────────────────────────────────────────────
WS_RESPONSE=$(curl -sf "$WS_SVC_URL/internal/workspaces/search/$WORKSPACE_NAME" 2>&1) || {
  echo "[ERROR] Could not reach workspace service. Is OneCX running?"
  exit 1
}
WORKSPACE_ID=$(echo "$WS_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "  Workspace ID  : $WORKSPACE_ID"

# ── Step 2: Check if product already registered ────────────────────────────────
PRODUCT_COUNT=$(curl -sf -X POST "$WS_SVC_URL/internal/products/search" \
  -H "Content-Type: application/json" \
  -d "{\"workspaceId\":\"$WORKSPACE_ID\",\"productName\":\"$PRODUCT_NAME\",\"pageSize\":1}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('totalElements',0))")

if [[ "$PRODUCT_COUNT" -gt 0 ]]; then
  echo "[SKIP] Product '$PRODUCT_NAME' already registered in workspace '$WORKSPACE_NAME'"
else
  # ── Step 3: Register product in workspace ──────────────────────────────────
  curl -sf -X POST "$WS_SVC_URL/internal/products" \
    -H "Content-Type: application/json" \
    -d "{
      \"workspaceId\": \"$WORKSPACE_ID\",
      \"productName\": \"$PRODUCT_NAME\",
      \"baseUrl\": \"$BASE_URL\",
      \"microfrontends\": [{\"appId\": \"$PERMISSION_APP_ID\", \"basePath\": \"/\"}]
    }" > /dev/null
  echo "[OK]   Product '$PRODUCT_NAME' registered in workspace '$WORKSPACE_NAME'"
fi

# ── Step 4: Import full menu from default_ADMIN.json ──────────────────────────
# This is a REPLACE operation — imports the complete menu tree from the file.
# The CLI (sync ui + menu create) already wrote the correct entries to this file.
IMPORT_TS=$(date +%Y%m%d%H%M%S)
MENU_PAYLOAD=$(python3 -c "
import json, sys
ws_file = '$WORKSPACE_FILE'
ws_name = '$WORKSPACE_NAME'
with open(ws_file) as f:
    d = json.load(f)
menu_items = d.get('workspaces', {}).get(ws_name, {}).get('menuItems', [])
snapshot = {
    'id': 'deployer-menu-import-$IMPORT_TS',
    'menu': {'menuItems': menu_items}
}
print(json.dumps(snapshot))
")

MENU_RESULT=$(echo "$MENU_PAYLOAD" | \
  curl -sf -X POST "$WS_SVC_URL/exim/v1/workspace/$WORKSPACE_NAME/menu/import" \
    -H "Content-Type: application/json" \
    -d @- | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','?'))")

echo "[OK]   Menu imported to workspace '$WORKSPACE_NAME' (status: $MENU_RESULT)"
