# OneCX UI Integration Agent

This agent automates the integration of UI microfrontends into the OneCX local environment.

## Capabilities

1. **Docker Image Integration** - Build and deploy UI as Docker container
2. **Hot Reload Setup** - Configure local development with hot reload
3. **Product Registration** - Sync product data with OneCX
4. **Traefik Configuration** - Set up routing for MFE

## Configuration

The agent reads configuration from a `onecx-integration.config.json` file in your UI project root.

### Configuration File (`onecx-integration.config.json`)

```json
{
  "product": {
    "name": "my-product",
    "displayName": "My Product",
    "description": "Product description",
    "basePath": "/my-product",
    "iconName": "pi-briefcase"
  },
  "ui": {
    "name": "my-product-ui",
    "mfePath": "myProduct",
    "exposedModule": "./MyProductModule",
    "remoteName": "my-product",
    "tagName": "my-product-webcomponent",
    "port": 6021
  },
  "bff": {
    "name": "my-product-bff",
    "url": "http://my-product-bff:8080"
  },
  "paths": {
    "helmValues": "./helm/values.yaml",
    "dockerfile": "./Dockerfile",
    "proxyConfig": "./proxy.conf.js",
    "webpackConfig": "./webpack.config.js",
    "distFolder": "./dist"
  },
  "onecxLocalEnv": {
    "path": "/path/to/onecx-local-env",
    "version": "v2"
  },
  "integration": {
    "mode": "docker",
    "profile": "all",
    "autoImport": true
  }
}
```

## Usage

### Interactive Mode

```bash
# Run the agent interactively
npx onecx-integration-agent
```

### Command Line Mode

```bash
# Docker image integration
npx onecx-integration-agent docker --config ./onecx-integration.config.json

# Hot reload setup
npx onecx-integration-agent hot-reload --config ./onecx-integration.config.json

# Full sync (product, permissions, workspace)
npx onecx-integration-agent sync --config ./onecx-integration.config.json
```

## Agent Actions

### 1. Docker Image Integration

Workflow:
1. Read configuration from `onecx-integration.config.json`
2. Build the UI project (`npm run build`)
3. Build Docker image
4. Sync product data using `@onecx/local-env-cli`
5. Create/update compose file
6. Start services

### 2. Hot Reload Setup

Workflow:
1. Read configuration
2. Create traefik hot reload config in `init-data/traefik/active/`
3. Update proxy.conf.js if needed
4. Stop Docker container (if running)
5. Restart traefik
6. Provide start command for local dev server

### 3. Cleanup

Workflow:
1. Remove traefik config
2. Remove compose entries
3. Optionally remove product data

## Agent Decision Logic

```
IF user wants hot reload:
  - Check if UI is synced with OneCX
  - Create traefik config with configured port
  - Stop Docker container
  - Provide npm start command

ELSE IF user wants docker integration:
  - Check if image exists or needs building
  - Sync product data
  - Create/update compose file
  - Start services

ALWAYS:
  - Validate configuration
  - Check for existing conflicts
  - Provide rollback instructions
```

## Environment Detection

The agent automatically detects:
- `helm/values.yaml` → Extract product/MFE configuration
- `package.json` → Get project name and build commands
- `webpack.config.js` → Get exposed module name
- Existing `onecx-local-env` → Validate paths

## Error Handling

| Error | Resolution |
|-------|------------|
| Missing config file | Prompt user for required values |
| Invalid helm values | Fall back to manual config |
| Docker build failure | Show build logs, suggest fixes |
| Port already in use | Suggest alternative port |
| Traefik routing conflict | Check priority, suggest resolution |

## Skill Definition

For use with GitHub Copilot or similar AI assistants:

```yaml
name: onecx-ui-integration
description: Integrate OneCX UI microfrontends into local environment
triggers:
  - "integrate ui"
  - "onecx integration"
  - "hot reload setup"
  - "deploy ui to onecx"
inputs:
  - config_path: Path to onecx-integration.config.json
  - mode: "docker" | "hot-reload"
  - ui_path: Path to UI project
  - env_path: Path to onecx-local-env
outputs:
  - compose_file: Generated compose file
  - traefik_config: Hot reload traefik config
  - start_command: Command to start services
```
