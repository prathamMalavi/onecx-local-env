#!/usr/bin/env bash
#
# Register a product to an existing OneCX workspace.
#
# The workspace ExIm import SKIPS workspaces that already exist, so this
# script registers a product directly in the database. Works for both
# hot reload and Docker image deployments — it's a workspace concern,
# not a deployment concern.
#
# Usage:
#   ./register-product-to-workspace.sh \
#     -p <product-name> \
#     -b <base-url> \
#     -m <mfe-id> \
#     -k <menu-key> \
#     -n <menu-name> \
#     -u <menu-url> \
#     [-w <workspace-name>]    # default: ADMIN
#     [-r <role-name>]         # default: onecx-admin
#     [-t <tenant-id>]         # default: default
#
# Example:
#   ./register-product-to-workspace.sh \
#     -p book-catalog \
#     -b /book-catalog \
#     -m book-catalog-ui \
#     -k CUSTOM_BOOK_CATALOG_UI \
#     -n "Book Catalog" \
#     -u /book-catalog/main
#

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

#################################################################
# defaults
WORKSPACE_NAME="ADMIN"
ROLE_NAME="onecx-admin"
TENANT_ID="default"
DB_USER="onecx_workspace"
DB_NAME="onecx_workspace"
POSTGRES_CONTAINER="postgresdb"

PRODUCT_NAME=""
BASE_URL=""
MFE_ID=""
MENU_KEY=""
MENU_NAME=""
MENU_URL=""

#################################################################
# usage
usage() {
  printf '%b\n' "
Usage: $0 -p <product> -b <base-url> -m <mfe-id> -k <menu-key> -n <menu-name> -u <menu-url> [-w <workspace>] [-r <role>] [-t <tenant>]

Required:
  -p  Product name      e.g. book-catalog
  -b  Base URL          e.g. /book-catalog
  -m  MFE app ID        e.g. book-catalog-ui
  -k  Menu item key     e.g. CUSTOM_BOOK_CATALOG_UI   (must be unique)
  -n  Menu item name    e.g. 'Book Catalog'
  -u  Menu item URL     e.g. /book-catalog/main

Optional:
  -w  Workspace name    default: ADMIN
  -r  Role name         default: onecx-admin
  -t  Tenant ID         default: default
"
  exit "${1:-0}"
}

#################################################################
# parse args
while getopts ":p:b:m:k:n:u:w:r:t:h" opt; do
  case "$opt" in
    p) PRODUCT_NAME="$OPTARG" ;;
    b) BASE_URL="$OPTARG" ;;
    m) MFE_ID="$OPTARG" ;;
    k) MENU_KEY="$OPTARG" ;;
    n) MENU_NAME="$OPTARG" ;;
    u) MENU_URL="$OPTARG" ;;
    w) WORKSPACE_NAME="$OPTARG" ;;
    r) ROLE_NAME="$OPTARG" ;;
    t) TENANT_ID="$OPTARG" ;;
    h) usage 0 ;;
    :) printf '%b\n' "${RED}Missing value for -${OPTARG}${NC}"; usage 1 ;;
    ?) printf '%b\n' "${RED}Unknown option: -${OPTARG}${NC}"; usage 1 ;;
  esac
done

#################################################################
# validate required
for var in PRODUCT_NAME BASE_URL MFE_ID MENU_KEY MENU_NAME MENU_URL; do
  if [[ -z "${!var}" ]]; then
    printf '%b\n' "${RED}Missing required parameter: -$(echo "$var" | tr '[:upper:]' '[:lower:]' | cut -c1)${NC}"
    usage 1
  fi
done

psql_cmd() {
  docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "$1" 2>&1
}

printf '%b\n' "${CYAN}Registering '$PRODUCT_NAME' to workspace '$WORKSPACE_NAME'${NC}"

#################################################################
# get workspace guid
WS_GUID=$(psql_cmd "SELECT guid FROM workspace WHERE name='${WORKSPACE_NAME}' AND tenant_id='${TENANT_ID}';")
if [[ -z "$WS_GUID" ]]; then
  printf '%b\n' "${RED}Workspace '${WORKSPACE_NAME}' not found for tenant '${TENANT_ID}'${NC}"
  exit 1
fi
printf '  workspace guid: %s\n' "$WS_GUID"

#################################################################
# get role guid
ROLE_GUID=$(psql_cmd "SELECT guid FROM role WHERE name='${ROLE_NAME}' AND workspace_guid='${WS_GUID}';")
if [[ -z "$ROLE_GUID" ]]; then
  printf '%b\n' "${RED}Role '${ROLE_NAME}' not found in workspace '${WORKSPACE_NAME}'${NC}"
  exit 1
fi
printf '  role guid: %s\n' "$ROLE_GUID"

#################################################################
# get "Custom Applications" parent menu guid (creates under it if exists, else top-level)
CUSTOM_PARENT_GUID=$(psql_cmd "SELECT guid FROM menu_item WHERE name='Custom Applications' AND workspace='${WS_GUID}' LIMIT 1;")
if [[ -z "$CUSTOM_PARENT_GUID" ]]; then
  printf '%b\n' "${YELLOW}  'Custom Applications' parent not found — menu item will be top-level${NC}"
  PARENT_CLAUSE="NULL"
else
  printf '  parent guid: %s\n' "$CUSTOM_PARENT_GUID"
  PARENT_CLAUSE="'${CUSTOM_PARENT_GUID}'"
fi

#################################################################
# 1. Register product (skip if already exists)
EXISTING_PRODUCT=$(psql_cmd "SELECT guid FROM product WHERE product_name='${PRODUCT_NAME}' AND workspace_guid='${WS_GUID}';")
if [[ -n "$EXISTING_PRODUCT" ]]; then
  printf '%b\n' "${YELLOW}  [SKIP] product '${PRODUCT_NAME}' already registered${NC}"
else
  PROD_GUID=$(psql_cmd "SELECT gen_random_uuid()::varchar;")
  psql_cmd "INSERT INTO product (optlock, creationdate, modificationdate, base_url, guid, product_name, tenant_id, workspace_guid, creationuser)
            VALUES (0, now(), now(), '${BASE_URL}', '${PROD_GUID}', '${PRODUCT_NAME}', '${TENANT_ID}', '${WS_GUID}', 'register-script');" > /dev/null
  psql_cmd "INSERT INTO microfrontend (base_path, guid, mfe_id, product_guid)
            VALUES ('/', gen_random_uuid()::varchar, '${MFE_ID}', '${PROD_GUID}');" > /dev/null
  printf '%b\n' "${GREEN}  [OK] product '${PRODUCT_NAME}' registered with base_url '${BASE_URL}'${NC}"
fi

#################################################################
# 2. Add menu item (skip if key already exists)
EXISTING_MENU=$(psql_cmd "SELECT guid FROM menu_item WHERE key='${MENU_KEY}' AND workspace='${WS_GUID}' AND tenant_id='${TENANT_ID}';")
if [[ -n "$EXISTING_MENU" ]]; then
  printf '%b\n' "${YELLOW}  [SKIP] menu item '${MENU_KEY}' already exists${NC}"
  MENU_GUID="$EXISTING_MENU"
else
  MENU_GUID=$(psql_cmd "SELECT gen_random_uuid()::varchar;")
  psql_cmd "INSERT INTO menu_item (optlock, creationdate, modificationdate, guid, key, name, url, application_id, badge, disabled, external, pos, parent, tenant_id, workspace, creationuser, target)
            VALUES (0, now(), now(), '${MENU_GUID}', '${MENU_KEY}', '${MENU_NAME}', '${MENU_URL}', '${MFE_ID}', 'briefcase', false, false, 99, ${PARENT_CLAUSE}, '${TENANT_ID}', '${WS_GUID}', 'register-script', '_self');" > /dev/null
  printf '%b\n' "${GREEN}  [OK] menu item '${MENU_NAME}' added (url: ${MENU_URL})${NC}"
fi

#################################################################
# 3. Assign role to menu item (skip if already assigned)
EXISTING_ASSIGN=$(psql_cmd "SELECT guid FROM assignment WHERE menu_item_id='${MENU_GUID}' AND role_id='${ROLE_GUID}' AND tenant_id='${TENANT_ID}';")
if [[ -n "$EXISTING_ASSIGN" ]]; then
  printf '%b\n' "${YELLOW}  [SKIP] role '${ROLE_NAME}' already assigned to menu item${NC}"
else
  psql_cmd "INSERT INTO assignment (optlock, creationdate, modificationdate, guid, menu_item_id, role_id, tenant_id, creationuser)
            VALUES (0, now(), now(), gen_random_uuid()::varchar, '${MENU_GUID}', '${ROLE_GUID}', '${TENANT_ID}', 'register-script');" > /dev/null
  printf '%b\n' "${GREEN}  [OK] role '${ROLE_NAME}' assigned to menu item${NC}"
fi

printf '%b\n' "${GREEN}Done. Hard-refresh your browser to see the changes.${NC}"
