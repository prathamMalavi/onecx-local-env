# Integrate a Locally Running App into OneCX Shell

> **Sources:** `.Ps-Docs/compiled-docs` → `extend/local-mfe`, `first-app/app_setup_cli`, `first-app/app_setup_manual`, `first-app/create_angular_app`, `extend/add_application_manually`
>
> **Goal:** `npm start` app on `localhost:4200` → visible in menu for ALL users → opens at `http://onecx.localhost/onecx-shell/admin/<your-app>`

---

## Which Path Should You Take?

The compiled-docs defines **two approaches**. Pick based on your situation:

| Situation | Approach |
|-----------|----------|
| Your app was generated with `npx @onecx/create-workspace` and has a `helm/values.yaml` | **Path A: CLI** (faster, automated) |
| Your app is any Angular app without OneCX Helm structure | **Path B: Manual** (JSON files by hand) |

Both paths require the **same Step 1** (Traefik routing) and the **same final import step**.

---

## STEP 1 — Start Your App and Route Traffic via Traefik

> **Source:** `extend/local-mfe.html` — *"This is the recommended procedure for integrating a locally running microfrontend"*

### 1a. Start your Angular app

```bash
# For nx-based apps (uses --disableHostCheck, no space before =):
npm run start -- --port=4200 --host 0.0.0.0 --disableHostCheck --publicHost=http://localhost:4200

# For standard ng-based apps (uses --disable-host-check with space):
npm run start -- --port 4200 --host 0.0.0.0 --disable-host-check --public-host=http://localhost:4200
```

**Why these flags:**
- `--host 0.0.0.0` — makes the dev server reachable from inside Docker (not just 127.0.0.1)
- `--disableHostCheck` — prevents Angular blocking requests that come from `onecx.localhost` hostname
- `--publicHost` — tells Angular its public URL so `remoteEntry.js` is built with correct paths

**Checkpoint — verify before continuing:**
```
http://localhost:4200/remoteEntry.js
```
You must see a JavaScript file. If you see an error, fix the app before continuing.

---

### 1b. Register with Traefik using `toggle-mfes.sh`

Run from the **`onecx-local-env` root folder**:

```bash
# Replace "my-app" with your app name, 4200 with your port
./toggle-mfes.sh -a my-app:4200:/mfe/my-app
```

**What this command does:**
Creates `init-data/traefik/active/my-app_4200.yml`. Traefik watches that folder live — no restart needed.

The generated Traefik config maps:
```
http://onecx.localhost/mfe/my-app/...  →  http://host.docker.internal:4200/...
```

**Other useful toggle-mfes.sh commands:**
```bash
./toggle-mfes.sh -l               # List currently integrated MFEs
./toggle-mfes.sh -d my-app:4200   # Remove the integration
./toggle-mfes.sh -c               # Remove ALL integrations
```

**Checkpoint — verify before continuing:**
```
http://onecx.localhost/mfe/my-app/remoteEntry.js
```
Must show the same JS file as step 1a. If this fails, Traefik is not routing. Check that OneCX is running (`./start-onecx.sh`).

---

## STEP 2 — Register App in Product Store + Workspace + Menu

Choose your path:

---

### PATH A: CLI Approach (requires `helm/values.yaml` in your app)

> **Source:** `first-app/app_setup_cli.html`, `first-app/create_angular_app.html#synchronization`

Run these commands **from your app's root folder**:

#### A1. Sync — creates all product-store JSON files automatically

```bash
npx @onecx/local-env-cli sync ui my-app /my-app ./helm/values.yaml \
  -e /path/to/onecx-local-env \
  -n my-app-ui
```

**Arguments explained:**
- `ui` — type of service being registered
- `my-app` — product name (used in file names and URLs)
- `/my-app` — product base path (becomes the URL segment in the shell)
- `./helm/values.yaml` — your app's Helm values file (the CLI reads MFE config from here)
- `-e /path/to/onecx-local-env` — **adjust this** to your actual onecx-local-env folder path
- `-n my-app-ui` — name for the microfrontend service

**What this creates in `onecx-local-env`:**
- `onecx-data/product-store/products/my-app.json`
- `onecx-data/product-store/microservices/my-app_my-app-ui.json`
- `onecx-data/product-store/microfrontends/my-app_my-app-ui_main.json`
- `onecx-data/permission/my-app_my-app-ui.json`
- `onecx-data/permission-assignment/my-app.json`
- Updates `onecx-data/workspace/default_ADMIN.json` products array

#### A2. Add menu entry

> **Source:** `first-app/create_angular_app.html#adding-menu-entry`

```bash
npx @onecx/local-env-cli menu create my-app-ui /my-app/feature "My App" \
  -e /path/to/onecx-local-env
```

**Arguments explained:**
- `my-app-ui` — the microfrontend service name (same as `-n` in sync command)
- `/my-app/feature` — the path to your app's feature module inside the shell. The full URL becomes:
  `http://onecx.localhost/onecx-shell/admin/my-app/feature`
- `"My App"` — the label shown in the sidebar menu
- `-e /path/to/onecx-local-env` — path to your onecx-local-env folder

**What this creates:**
Adds a menu item entry to `onecx-data/workspace/default_ADMIN.json` under `PORTAL_MAIN_MENU`.

> **CLI NOTE:** By default, the CLI creates menu entries visible to all workspace roles. If you need to explicitly control roles, edit the created entry in `default_ADMIN.json` and ensure the `roles` array contains `["onecx-admin", "onecx-user"]` — see the Manual step below for the exact JSON structure.

Then **skip to STEP 3** (import).

---

### PATH B: Manual Approach (any app, no Helm required)

> **Source:** `first-app/app_setup_manual.html`, `extend/add_application_manually`

All files go into **`onecx-local-env`** (not your app folder). Run all `cat` commands from the `onecx-local-env` root.

You need values from your `webpack.config.js`. Open it and note:
```js
new ModuleFederationPlugin({
  name: "my-app",            // ← remoteName
  exposes: {
    "./OneCXMyAppModule": …  // ← exposedModule
  }
})
```
And from your `*.remote.module.ts`:
```ts
customElements.define('ocx-my-app-component', element);
//                    ^^^^^^^^^^^^^^^^^^^^ tagName
```

---

#### B1. Product definition
**File:** `onecx-data/product-store/products/my-app.json`
**Naming rule:** `{product-name}.json`

```bash
cat > onecx-data/product-store/products/my-app.json << 'EOF'
{
  "version": "xxx",
  "description": "My App",
  "imageUrl": "",
  "iconName": "pi-briefcase",
  "displayName": "My App",
  "basePath": "/my-app",
  "provider": "My Team",
  "classifications": ["Custom"],
  "multitenancy": false,
  "undeployed": false
}
EOF
```

**Critical field:** `basePath` — becomes the URL segment in the shell. Final URL = `http://onecx.localhost/onecx-shell/admin` + `/my-app`.

---

#### B2. Microservice definition
**File:** `onecx-data/product-store/microservices/my-app_my-app-ui.json`
**Naming rule:** `{product-name}_{service-name}.json`

```bash
cat > onecx-data/product-store/microservices/my-app_my-app-ui.json << 'EOF'
{
  "version": "xxx",
  "name": "my-app-ui",
  "description": "My App UI",
  "type": "ui"
}
EOF
```

---

#### B3. Microfrontend definition
**File:** `onecx-data/product-store/microfrontends/my-app_my-app-ui_main.json`
**Naming rule:** `{product-name}_{service-name}_{component-name}.json`

```bash
cat > onecx-data/product-store/microfrontends/my-app_my-app-ui_main.json << 'EOF'
{
  "appVersion": "xxx",
  "appName": "My App UI",
  "description": "My App main UI component",
  "remoteBaseUrl": "/mfe/my-app/",
  "remoteEntry": "/mfe/my-app/remoteEntry.js",
  "exposedModule": "./OneCXMyAppModule",
  "technology": "WEBCOMPONENTMODULE",
  "remoteName": "my-app",
  "tagName": "ocx-my-app-component",
  "type": "MODULE",
  "deprecated": false,
  "undeployed": false
}
EOF
```

**Critical fields — these MUST match your webpack.config.js / remote module:**

| Field | Must match |
|-------|-----------|
| `remoteBaseUrl` | The path you used in `toggle-mfes.sh` (Step 1b). Must end with `/` |
| `remoteEntry` | `remoteBaseUrl` + `remoteEntry.js` |
| `exposedModule` | The key under `exposes:` in `webpack.config.js` |
| `remoteName` | The `name:` value in `ModuleFederationPlugin` in `webpack.config.js` |
| `tagName` | The string in `customElements.define(...)` in your `*.remote.module.ts` |

---

#### B4. Permissions definition
**File:** `onecx-data/permission/my-app_my-app-ui.json`
**Naming rule:** `{product-name}_{service-name}.json`

```bash
cat > onecx-data/permission/my-app_my-app-ui.json << 'EOF'
{
  "name": "my-app-ui",
  "permissions": [
    { "resource": "PAGE", "action": "VIEW", "description": "Permission to view the page" }
  ]
}
EOF
```

Add more `resource/action` pairs if your app has write/admin actions.

---

#### B5. Permission assignment
**File:** `onecx-data/permission-assignment/my-app.json`
**Naming rule:** `{product-name}.json`

```bash
cat > onecx-data/permission-assignment/my-app.json << 'EOF'
{
  "id": "onecx-local-env_import-permission-assignments_my-app",
  "assignments": {
    "my-app": {
      "my-app-ui": {
        "onecx-admin": {
          "PAGE": ["VIEW"]
        },
        "onecx-user": {
          "PAGE": ["VIEW"]
        }
      }
    }
  }
}
EOF
```

**Both `onecx-admin` and `onecx-user` must have `VIEW`** — otherwise the app will only be accessible to admins.

---

#### B6. Register in workspace + add menu entry
**File:** `onecx-data/workspace/default_ADMIN.json`

You need to make **two edits** to this file:

**Edit 1 — Add to `products` array:**

Find the end of the `products` array inside `"ADMIN": {`. Add this entry (with a comma after the last existing entry):

```json
{
  "productName": "my-app",
  "baseUrl": "/my-app",
  "microfrontends": [
    {
      "appId": "my-app-ui",
      "basePath": "/"
    }
  ]
}
```

- `productName` — must match the filename of your product JSON (B1), without `.json`
- `baseUrl` — must match `basePath` from your product JSON (B1)
- `appId` — must match `name` from your microservice JSON (B2)

---

**Edit 2 — Add menu entry to `PORTAL_MAIN_MENU.children`:**

Find `"key": "PORTAL_MAIN_MENU"` in the `menuItems` array. Inside its `children` array, add this entry:

```json
{
  "key": "PMM_MY_APP",
  "name": "My App",
  "url": "/my-app",
  "disabled": false,
  "position": 99,
  "badge": "pi-briefcase",
  "external": false,
  "target": "_self",
  "i18n": {
    "de": "Meine App",
    "en": "My App"
  },
  "roles": ["onecx-admin", "onecx-user"],
  "children": []
}
```

**Why this controls visibility for ALL users:**
- `"roles": ["onecx-admin", "onecx-user"]` — the workspace service filters menu items per the logged-in user's role. You MUST include **both** roles here or users with `onecx-user` role will not see the menu item at all.
- `"url": "/my-app"` — this is workspace-relative. The shell resolves it to `http://onecx.localhost/onecx-shell/admin/my-app`
- `"key": "PMM_MY_APP"` — must be unique across all menu items in the file

---

## STEP 3 — Import Data into Running Services

> **Source:** `scripts/import.html`, `extend/custom-imports.html`

The JSON files on disk are just config files. This script sends them via HTTP to the running OneCX services (Product Store, Workspace, Permission services) where they are stored in Postgres.

Run from **`onecx-local-env` root**:

```bash
# Import everything (recommended first time — safe to re-run):
./import-onecx.sh -d all
```

Or import only what you changed (faster for subsequent runs):

```bash
./import-onecx.sh -d product -x      # B1 — product definition
./import-onecx.sh -d ms -x           # B2 — microservice definition
./import-onecx.sh -d mfe -x          # B3 — microfrontend definition
./import-onecx.sh -d permission -x   # B4 — permissions
./import-onecx.sh -d assignment -x   # B5 — permission assignments
./import-onecx.sh -d workspace -x    # B6 — workspace + menu entry
```

**What `-x` does:** Skips the Docker services health check (saves time). Only remove it if services might not be running.

**Imports do NOT overwrite** data you manually changed in the UI after the last import.

---

## STEP 4 — Verify

1. Open `http://onecx.localhost/onecx-shell/admin`
2. Log in with `onecx` / `onecx` (admin user)
3. The sidebar should show **"My App"** menu item
4. Click it → navigates to `http://onecx.localhost/onecx-shell/admin/my-app` and your app loads inside the shell
5. Log out → log in as a user-role account → "My App" should still be visible

---

## Troubleshooting

### Menu item not visible for `onecx-user` role

This is the most common issue. Check in order:

1. **`roles` array in the menu item** (Step B6 / default_ADMIN.json):
   Must be `"roles": ["onecx-admin", "onecx-user"]` — NOT just `["onecx-admin"]`

2. **Permission assignment** (Step B5):
   `onecx-user` must have at least one action assigned (e.g., `"PAGE": ["VIEW"]`). Without a permission assignment, the workspace service may filter out the menu item for that role.

3. **Re-run workspace import:**
   ```bash
   ./import-onecx.sh -d workspace -x
   ```

4. **Hard-refresh browser:** `Ctrl+Shift+R` — the shell caches workspace config aggressively.

---

### App loads blank / shows error inside the shell

1. **Check remoteEntry.js is reachable via Traefik:**
   Open `http://onecx.localhost/mfe/my-app/remoteEntry.js` — must show JS, not 404.
   If 404 → toggle-mfes.sh integration is missing or app is not running → redo Step 1.

2. **Check `remoteName` matches webpack:**
   The `remoteName` in `microfrontends/my-app_my-app-ui_main.json` must exactly match the `name:` value in `ModuleFederationPlugin` in your `webpack.config.js`.

3. **Check `exposedModule` matches webpack:**
   The `exposedModule` in the microfrontend JSON must exactly match the key in `exposes:` in `webpack.config.js` (e.g. `./OneCXMyAppModule`).

4. **`ngDevMode is not defined` error in browser console:**
   > Source: `first-app/enable_hot_reload.html#angular-ngdevmode-error`
   
   Add to `webpack.config.js`:
   ```js
   const webpack = require('webpack');
   const isProduction = process.env.NODE_ENV === 'production';
   // inside module.exports:
   plugins: [
     new webpack.DefinePlugin({
       ngDevMode: isProduction ? 'false' : 'true'
     })
   ]
   ```
   And in `package.json` scripts:
   ```json
   "build": "NODE_ENV=production nx build"
   ```

---

### Local changes not visible after editing source

> Source: `first-app/enable_hot_reload.html#local-changes-not-visible`

If a Docker container for the same app is still running, Traefik may route to it instead of your local dev server.

Stop the container:
```bash
docker compose stop my-app-ui
```

Then your `toggle-mfes.sh` routing takes over.

---

## Removal

> Source: `first-app/app_removal.html`

```bash
# 1. Remove Traefik routing (immediate, no restart needed)
./toggle-mfes.sh -d my-app:4200

# 2. Delete JSON files you created
rm onecx-data/product-store/products/my-app.json
rm onecx-data/product-store/microservices/my-app_my-app-ui.json
rm onecx-data/product-store/microfrontends/my-app_my-app-ui_main.json
rm onecx-data/permission/my-app_my-app-ui.json
rm onecx-data/permission-assignment/my-app.json

# 3. Edit default_ADMIN.json — remove the product entry and menu item manually

# 4. Re-import to apply removals
./import-onecx.sh -d workspace -x
```

> **Note:** Product Store data (product, MFE, MS records) that were already imported into Postgres persist until the volume is wiped (`./stop-onecx.sh -c`). The import script does not delete existing records — it only adds/updates.

---

## Files Summary

```
onecx-local-env/
│
│  ← Created by toggle-mfes.sh (Step 1b)
├── init-data/traefik/active/
│   └── my-app_4200.yml
│
│  ← Created/edited in Step 2 (Path B manual, or by CLI in Path A)
└── onecx-data/
    ├── product-store/
    │   ├── products/
    │   │   └── my-app.json                    (B1)
    │   ├── microservices/
    │   │   └── my-app_my-app-ui.json          (B2)
    │   └── microfrontends/
    │       └── my-app_my-app-ui_main.json     (B3)
    ├── permission/
    │   └── my-app_my-app-ui.json              (B4)
    ├── permission-assignment/
    │   └── my-app.json                        (B5)
    └── workspace/
        └── default_ADMIN.json                 (B6 — edited, not created)
```
