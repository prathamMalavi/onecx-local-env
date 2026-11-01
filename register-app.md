# Register an app in the local environment

Edit `register-app.template.json` with your app's identifiers and OneCX product base path, then preview the generated registration:

```bash
python3 register-app.py register-app.template.json --dry-run
```

Generate the files and merge the product/app entry into the selected workspace JSON:

```bash
python3 register-app.py register-app.template.json
```

The script does not call live services or import the workspace. Review the resulting diff before importing anything. Importing `workspace` uses the repository's workspace operator, which recreates the selected workspace; it can reset live workspace changes.

## Required fields

- `productName`: Product Store product key.
- `appID`: Product Store microfrontend ID.
- `base-url`: OneCX product path, such as `/my-demo-app`. Also accepts `baseUrl`.

Use letters, digits, dots, and hyphens in `productName` and `appID`; the existing importers split filenames on underscores.

## Optional fields and defaults

All options are optional; the script uses the current local-env conventions unless overridden:

| Field | Default |
|---|---|
| `displayName` | `productName` |
| `description` | `displayName` |
| `productVersion` | `xxx` |
| `iconName` | `pi-briefcase` |
| `multitenancy` | `true` |
| `imageUrl` | empty string |
| `appName` | `appID` |
| `appVersion` | `xxx` |
| `mfeRoute` | `productName` |
| `remoteBaseUrl` | `/mfe/<mfeRoute>/` |
| `remoteEntry` | `<remoteBaseUrl>remoteEntry.js` |
| `exposedModule` | `./RemoteModule` |
| `technology` | `WEBCOMPONENTMODULE` |
| `type` | `MODULE` |
| `remoteName`, `tagName` | `appID` |
| `shareScope` (also `sharescope`) | omitted; set explicitly to match the app's Angular/module-federation sharing config |
| `tenant`, `workspace` | `default`, `ADMIN` |
| `workspaceAppBasePath` | `/` |
| `menuItem` | omitted; workspace availability is registered, but no navigation menu item is added |
| `permission` / `permissions` | omitted; no permissions file is generated |
| `assignPermissionsToRoles` | omitted; no role assignment is made |

A simple app with overrides could look like:

```json
{
  "productName": "my-demo-app",
  "appID": "my-demo-app-ui",
  "base-url": "/my-demo-app",
  "displayName": "Demo App",
  "mfeRoute": "my-demo-app",
  "remoteBaseUrl": "/mfe/my-demo-app/",
  "shareScope": "angular_21",
  "permission": [
    { "resource": "DEMO", "action": "VIEW" }
  ],
  "assignPermissionsToRoles": ["onecx-admin"],
  "menuItem": {
    "name": "Demo App",
    "key": "DEMO_APP",
    "url": "/my-demo-app/"
  }
}
```

`permission` may also be a resource-to-actions object, for example `{ "DEMO": ["VIEW", "EDIT"] }`. Supplying `assignPermissionsToRoles` generates/merges the corresponding role assignment; permissions alone only register their definitions.

The input can also be an array of app objects. Use `--root /path/to/local-env` to target another checkout and `--overwrite` to replace existing generated product, MFE, or permission files. The workspace product/app entry is updated in place, and generated role assignments are merged. `--dry-run` validates and previews without writing.

After review, import the relevant data using `./import-onecx.sh -d product`, `mfe`, `permission`, `assignment`, or `workspace`. Import only the types you generated; workspace import recreates the selected workspace.
