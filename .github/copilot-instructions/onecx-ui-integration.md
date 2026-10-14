# OneCX UI Integration Skill

This skill helps integrate OneCX UI microfrontends into the local environment.

## When to Use

Use this skill when the user wants to:
- Integrate a UI microfrontend into OneCX
- Set up hot reload for local development
- Deploy a custom application to OneCX local environment
- Troubleshoot MFE routing or loading issues

## Required Information

Before proceeding, gather the following from the user or detect from the project:

1. **UI Project Path** - Location of the Angular/React UI project
2. **OneCX Local Env Path** - Location of onecx-local-env repository
3. **Integration Mode** - `docker` (containerized) or `hot-reload` (local dev)
4. **Product Name** - Unique identifier for the product
5. **MFE Path** - URL path for the microfrontend (e.g., `bookCatalog` for `/mfe/bookCatalog/`)
6. **Port** (for hot-reload) - Local dev server port

## Detection Strategy

### From `helm/values.yaml`:
```yaml
app:
  routing:
    path: /mfe/<mfePath>/   # Extract mfePath
  operator:
    microfrontend:
      specs:
        main:
          exposedModule: ./<ModuleName>Module
          remoteName: <remote-name>
          tagName: <tag-name>-webcomponent
```

### From `package.json`:
```json
{
  "name": "<project-name>"
}
```

### From `webpack.config.js`:
```javascript
name: '<remote-name>',
exposes: {
  './<ModuleName>Module': './src/app/<module>.remote.module.ts'
}
```

## Integration Steps

### Docker Image Integration

1. **Build the UI**
   ```bash
   cd <ui-project-path>
   rm -rf .nx/cache ./dist
   npm run build
   ```

2. **Build Docker Image**
   ```bash
   docker build --no-cache -t <product-name>-ui:latest .
   ```

3. **Sync Product Data**
   ```bash
   npx @onecx/local-env-cli sync ui <product-name> /<base-path> ./helm/values.yaml \
     -e <onecx-local-env-path> -n <product-name>-ui
   ```

4. **Create Menu Entry**
   ```bash
   npx @onecx/local-env-cli menu create <product-name>-ui /<base-path>/<feature> "<Display Name>" \
     -e <onecx-local-env-path>
   ```

5. **Create Compose File** at `<onecx-local-env>/<product-name>.compose.yaml`:
   ```yaml
   include:
     - compose.yaml
   services:
     <product-name>-ui:
       image: <product-name>-ui:latest
       container_name: <product-name>-ui
       environment:
         APP_BASE_HREF: /mfe/<mfePath>/
         APP_ID: <product-name>-ui
         PRODUCT_NAME: <product-name>
         BFF_URL: "http://<product-name>-bff:8080"
       labels:
         - traefik.http.services.<product-name>-ui.loadbalancer.server.port=8080
         - traefik.http.routers.<product-name>-ui.rule=Host(`onecx.localhost`) && PathPrefix(`/mfe/<mfePath>/`)
       networks:
         - onecx
       profiles:
         - all
   ```

6. **Start Services**
   ```bash
   cd <onecx-local-env-path>
   docker compose -f <product-name>.compose.yaml --profile all up -d --build
   ```

### Hot Reload Integration

1. **Sync Product Data** (same as Docker)

2. **Create Traefik Config** at `<onecx-local-env>/init-data/traefik/active/<product>_<port>.yml`:
   ```yaml
   http:
     routers:
       local_<product>:
         rule: "Host(`onecx.localhost`) && PathPrefix(`/mfe/<mfePath>/`)"
         service: local_<product>
         priority: 500
         middlewares:
           - strip_<product>
     middlewares:
       strip_<product>:
         stripPrefix:
           prefixes:
             - "/mfe/<mfePath>"
     services:
       local_<product>:
         loadBalancer:
           servers:
             - url: "http://host.docker.internal:<port>/"
   ```

3. **Stop Docker Container**
   ```bash
   docker stop <product-name>-ui
   ```

4. **Restart Traefik**
   ```bash
   cd <onecx-local-env-path>
   docker compose restart traefik
   ```

5. **Start Local Dev Server**
   ```bash
   cd <ui-project-path>
   npm start -- --port <port> --host 0.0.0.0 --disable-host-check
   ```

## Common Issues and Solutions

### Issue: "host not found in upstream"
**Cause:** BFF service referenced in nginx config doesn't exist
**Solution:** Set `BFF_URL` environment variable to valid URL or modify nginx locations.conf

### Issue: "remoteEntry.js 404"
**Cause:** Container not running or routing misconfigured
**Solutions:**
1. Check container: `docker ps -a | grep <product>`
2. Check logs: `docker logs <product-name>-ui`
3. Verify routing path matches `APP_BASE_HREF`

### Issue: "Failed to fetch dynamically imported module"
**Cause:** Module Federation loading failure
**Solutions:**
1. Verify exposed module name matches registration
2. Check remoteEntry.js is accessible
3. Verify CORS headers are set

### Issue: UI not in shell menu
**Cause:** Missing workspace/menu registration
**Solution:** Run menu create command or manually add to workspace JSON

## File Locations Reference

| Purpose | Path |
|---------|------|
| Product definition | `onecx-data/product-store/products/<product>.json` |
| MFE registration | `onecx-data/product-store/microfrontends/<product>_<ui>_main.microfrontend.json` |
| Permissions | `onecx-data/permission/<product>_<ui>.json` |
| Permission assignments | `onecx-data/permission-assignment/<product>.json` |
| Workspace | `onecx-data/workspace/default_ADMIN.json` |
| Hot reload config | `init-data/traefik/active/<product>_<port>.yml` |
| Docker compose | `<product>.compose.yaml` |

## Access URLs

- Shell: `http://onecx.localhost/onecx-shell/admin/`
- MFE direct: `http://onecx.localhost/mfe/<mfePath>/remoteEntry.js`
- Traefik dashboard: `http://localhost:8082/dashboard/`
