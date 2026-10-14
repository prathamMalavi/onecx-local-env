# OneCX Local Env Deployment Issues — Root Cause Analysis

> **Context:** Generated app `onecx-book-catalog` deployed using `onecx-local-env-cli` following the documented steps. Four cascading issues prevented the UI from being accessible. This document explains each issue, why it happened, how it was resolved, and what must change to prevent it.

---

## CLI-Generated Files and Their Purpose

| File | Generator | Import method | Idempotent on restart? |
|------|-----------|---------------|------------------------|
| `onecx-book-catalog.compose.yaml` | `docker create` | Used by Docker Compose directly | n/a |
| `init-data/traefik/active/bookCatalog_4200.yml` | `sync ui` (hot reload) | Traefik file-watch (live) | ✅ |
| `onecx-data/product-store/products/onecx-book-catalog.json` | `sync ui` | `PUT /operator/product/v1/update/<product>` | ✅ upsert |
| `onecx-data/product-store/microfrontends/onecx-book-catalog_<appId>_main.json` | `sync ui` | `PUT /operator/mfe/v1/<product>/<appId>` | ✅ upsert |
| `onecx-data/product-store/microservices/onecx-book-catalog_onecx-book-catalog-ui.json` | `sync ui` | `PUT /operator/ms/v1/<product>/<appId>` | ✅ upsert |
| `onecx-data/permission/onecx-book-catalog_onecx-book-catalog-ui.json` | `sync ui` | `PUT /operator/v1/<product>/<appId>` | ✅ upsert |
| `onecx-data/permission-assignment/onecx-book-catalog.json` | `sync ui` | `POST /exim/v1/assignments/operator` | ✅ replaces |
| `onecx-data/workspace/default_ADMIN.json` (modified) | `sync ui` + `menu create` | `POST /exim/v1/workspace/import` | ❌ SKIPS existing |

**Key:** All product-store and permission imports use **operator (PUT) endpoints** — these upsert on every restart. The workspace import uses the **ExIm (POST) endpoint** — this skips existing workspaces and is the source of issues 1 and 2.

---

## Issue 1: Application not added to workspace

### Why it happened
`sync ui` and `menu create` correctly update `onecx-data/workspace/default_ADMIN.json` with the product entry and menu item. When `start-onecx.sh` runs `import-onecx.sh`, the workspace ExIm call (`POST /exim/v1/workspace/import`) returns:
```json
{"workspaces": {"ADMIN": "SKIPPED"}}
```
HTTP status 200 — but nothing is written. The import script only checks the HTTP code, not the response body, so it reports success.

### Root cause
The workspace ExIm is **designed for initial bootstrap only**. It creates workspaces that don't exist. Once `ADMIN` exists (after first startup), every subsequent call is silently ignored.

### Diagnosis
```bash
curl -s -X POST http://onecx-workspace-svc/exim/v1/workspace/import \
  -H "Content-Type: application/json" -d @onecx-data/workspace/default_ADMIN.json
# Returns: {"workspaces":{"ADMIN":"SKIPPED"}}
```

### Resolution
Use the workspace REST API directly — it does not skip existing workspaces:
- `GET /internal/workspaces/search/{name}` — get workspace ID
- `POST /internal/products` — add product to workspace (idempotent)

**Script:** `.github/skills/onecx-local-env-cli.scripts/register-workspace.sh`

### What was wrong
Nothing in the CLI or local-env setup was broken. The limitation is inherent to the workspace ExIm API design. The official docs did not mention this constraint.

---

## Issue 2: Menu entry not visible

### Why it happened
Same cause as Issue 1. `menu create` adds the menu entry to `default_ADMIN.json` under `workspaces.ADMIN.menuItems`. The workspace ExIm skips the import → menu item never written to DB.

### Root cause
Workspace ExIm SKIPPED — menu items in `default_ADMIN.json` never applied.

### Resolution
Use `POST /exim/v1/workspace/{name}/menu/import` which **replaces the full menu tree** for a specific workspace and **does not skip existing workspaces**. This endpoint returns `{"status": "UPDATED"}`.

The agent-owned `register-workspace.sh` script reads the full `menuItems` array from `default_ADMIN.json` and posts it to this endpoint. Since it replaces the entire tree, any entries added by the CLI (`sync ui`, `menu create`) are included.

> ⚠️ **Warning:** `POST /exim/v1/workspace/{name}/menu/import` is a full REPLACE — not a merge. Do not call it with a partial payload or it will delete all other menu items.

---

## Issue 3: Blank screen after clicking menu entry

### Why it happened
The menu URL was set to `/onecx-book-catalog` (base path only, no sub-route). When the shell navigates to this URL:
1. Shell strips the product `base_url` (`/onecx-book-catalog`) from the URL
2. Angular router receives the remainder (empty string)
3. The app routing module uses `matcher: startsWith('book')` — empty string doesn't start with `book`
4. No route matches → blank white screen

### Root cause
The `menu create` command was called with `--url /onecx-book-catalog` instead of `--url /onecx-book-catalog/<angular-route>`. There was no documentation warning about this requirement.

### The `book-c` explanation
`book-c` was tried randomly and worked — because the Angular router uses `startsWith('book')`:
```typescript
// app-routing.module.ts
{ matcher: startsWith('book'), loadChildren: () => import('./book/book.module') }
```
`book-c`, `book`, `book-catalog`, `books` → all match. `main`, empty string → do NOT match.

**The correct approach:** Read `src/app/app-routing.module.ts` in the PoC. For `matcher: startsWith('X')`, use `X` as the route suffix. For `path: 'X'`, use `X`.

### Resolution
Changed menu URL to `/onecx-book-catalog/book-c` in `default_ADMIN.json`.

### What was wrong in the docs/CLI
The SKILL.md and CLI documentation did not state that the menu URL must include a valid Angular route suffix. The deployer agent now reads the routing module to derive this automatically.

---

## Issue 4: Permission error "Missing permission key: BOOK#SEARCH"

### Why it happened — CLI bug

`sync ui` in the CLI (`sync-microfrontends.ts`) names the MFE file using the webpack `remoteName`:
```typescript
// sync-microfrontends.ts
const fileName = `${params.productName}_${spec.remoteName}_${key}.json`;
//                                         ^^^^^^^^^^^^^^^^
//                 uses helm values.operator.microfrontend.specs.main.remoteName
//                 e.g., 'book-catalog' (webpack module federation name)
```

The second segment of this filename becomes the `app_id` in the product-store DB.

The permission file uses the image-derived `uiName`:
```typescript
// sync-permissions.ts
const fileName = `${params.productName}_${params.appName}.json`;
//                                         ^^^^^^^^^^^^^^
//                 uses image.repository last segment
//                 e.g., 'onecx-book-catalog-ui' (Kubernetes service name)
```

These are **different values**:

| What | Value | Source |
|------|-------|--------|
| MFE file second segment | `book-catalog` | `remoteName` from helm values |
| Permission file second segment | `onecx-book-catalog-ui` | Image repository last segment |
| Product-store `app_id` in DB | `book-catalog` | From MFE filename second segment |
| Permission `app_id` in DB | `onecx-book-catalog-ui` | From permission filename second segment |

When the MFE loads, the shell passes it the product-store config where `appId = 'book-catalog'`. The MFE uses this `appId` to call the permission service. The permission service finds no permissions for `book-catalog` (they are under `onecx-book-catalog-ui`) → returns empty → Unauthorized.

### Resolution
1. Renamed MFE file: `onecx-book-catalog_book-catalog_main.json` → `onecx-book-catalog_onecx-book-catalog-ui_main.json`
2. Fixed `default_ADMIN.json` workspace `appId` from `book-catalog` to `onecx-book-catalog-ui`
3. Re-ran import to update product-store

The deployer agent's Step 3a now handles this automatically by comparing the MFE filename second segment with the permission filename second segment, renaming the file if they differ, and patching `default_ADMIN.json`.

---

## Core CLI Bug

**Files:** `src/commands/sync/ui/sync-microfrontends.ts` and `src/commands/sync/ui/sync-workspace.ts` in `onecx-local-env-cli`

**Bug:** Both use `spec.remoteName` where they should use `params.uiName`.

```typescript
// sync-microfrontends.ts — BUG:
const fileName = `${params.productName}_${spec.remoteName}_${key}.json`;
// CORRECT:
const fileName = `${params.productName}_${params.uiName}_${key}.json`;

// sync-workspace.ts — BUG:
const microfrontend = { appId: spec.remoteName, basePath: "/" };
// CORRECT:
const microfrontend = { appId: params.uiName, basePath: "/" };
```

`params.uiName` comes from `image.repository` last segment (e.g., `onecx-book-catalog-ui`) and is what the permission system uses. `spec.remoteName` is the webpack module federation name (e.g., `book-catalog`) and should only be used in the MFE JSON content (`remoteName`, `appName` fields), not in the filename or workspace `appId`.

### Suggested fix for CLI
Change both files above. For `sync-microfrontends.ts`, use `params.uiName` as the second filename segment. For `sync-workspace.ts`, use `params.uiName` as `appId`.

---

## Root Cause: Wrong Endpoint Used in onecx-local-env

The workspace import skips because `import-workspaces.sh` uses the **wrong endpoint**:

| Endpoint | Method | Behavior | Use case |
|----------|--------|----------|----------|
| `/exim/v1/workspace/import` | POST | **Creates only** — skips if workspace exists | First-time bootstrap |
| `/exim/v1/workspace/operator` | POST | **Upserts** — creates or updates | Incremental updates |

**Current code (`import-workspaces.sh`):**
```bash
url="http://onecx-workspace-svc/exim/v1/workspace/import"  # WRONG
```

**Should be:**
```bash
url="http://onecx-workspace-svc/exim/v1/workspace/operator"  # CORRECT
```

Product-store and permission both use **operator endpoints** → idempotent upsert works.
Workspace uses the **ExIm import endpoint** → skips existing → broken.

---

## Required Fixes in Upstream Repos

### Fix 1: `onecx-local-env` — Use operator endpoint

**File:** `onecx-data/workspace/import-workspaces.sh`

Change the URL from `/exim/v1/workspace/import` to `/exim/v1/workspace/operator`. This makes workspace imports behave like product-store and permission imports — idempotent upsert on every restart.

### Fix 2: `onecx-local-env-cli` — Use `uiName` not `remoteName`

**File 1:** `src/commands/sync/ui/sync-microfrontends.ts`
- Use `params.uiName` as the second filename segment (not `spec.remoteName`)

**File 2:** `src/commands/sync/ui/sync-workspace.ts`
- Use `params.uiName` as the workspace `appId` (not `spec.remoteName`)

This ensures MFE `app_id` matches permission `app_id`.

### Fix 3: `onecx-local-env-cli` — Validate menu URL

**File:** `src/commands/menu/create-menu-entry.ts`

Either warn if URL has no route suffix, or document clearly that `/<base-path>/<angular-route>` is required.

---

## Workaround Until Fixes Are Merged

The agent-owned script `.github/skills/onecx-local-env-cli.scripts/register-workspace.sh` uses REST APIs to work around the endpoint issue. It does NOT use DB injection — only standard workspace REST endpoints.

Once Fix 1 is merged to `onecx-local-env`, the script becomes unnecessary.

---

## Changes Made (Temporary Workarounds)

| File | Change | Why temporary |
|------|--------|---------------|
| `.0_agents-deployer/.github/agents/deployer.agent.md` | Added Step 3a (fix CLI bug), Step 3c (register workspace) | Until CLI fixes merged |
| `.0_agents-deployer/.github/skills/onecx-local-env-cli.scripts/register-workspace.sh` | Agent-owned REST API script | Until local-env uses operator endpoint |
| `onecx-data/product-store/microfrontends/` | Renamed file manually | Until CLI fix merged |
| `onecx-data/workspace/default_ADMIN.json` | Fixed `appId` and menu URL manually | Until CLI fix merged |

---

## Summary

| Issue | Root cause | Permanent fix (upstream) |
|-------|------------|--------------------------|
| Product not in workspace | `import-workspaces.sh` uses wrong endpoint (`/import` not `/operator`) | **onecx-local-env**: Change endpoint in import script |
| Menu not visible | Same as above | Same as above |
| Blank screen | CLI doesn't validate menu URL route | **onecx-local-env-cli**: Add validation or docs |
| Permission error | CLI uses `remoteName` instead of `uiName` | **onecx-local-env-cli**: Fix `sync-microfrontends.ts` and `sync-workspace.ts` |
