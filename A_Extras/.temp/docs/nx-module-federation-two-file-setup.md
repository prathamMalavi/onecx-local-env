# Two-file webpack setup for `@nx/module-federation` apps

This guide explains how to split the module federation configuration into two files when
using `@nx/angular/module-federation` in an Nx-based Angular application.

## File structure

```
my-app/
  module-federation.config.ts   ← MF app name, exposes, and shared dependency rules
  webpack.config.ts             ← Applies MF config to Angular's base webpack config
```

## Why TypeScript config files work here

Nx compiles TypeScript config files before passing them to webpack (via
`@nx/angular:webpack-browser` or equivalent builders). This is different from
non-Nx apps using `ngx-build-plus`, which loads configs through Node.js `require()`
and therefore only supports `.js`.

---

## `module-federation.config.ts`

Declares what the application exposes and how its dependencies are shared. Using
`getOneCXSharedRecommendations` from `@onecx/accelerator` is recommended to
automatically apply the correct sharing settings for OneCX packages.

```ts
import { ModuleFederationConfig } from '@nx/module-federation'
import { getOneCXSharedRecommendations } from '@onecx/accelerator'

const config: ModuleFederationConfig = {
  name: 'my-app',
  exposes: {
    './RemoteEntry': 'src/main.ts',
  },
  shared: (libraryName, sharedConfig) => {
    return getOneCXSharedRecommendations(libraryName, sharedConfig)
  },
}

export default config
```

**Notes:**
- `name` must match the app name registered in the shell.
- `exposes` maps public keys to source entry points. The shell uses these keys when
  loading the remote.
- `shared` receives each library name and its default Nx sharing config, and returns
  the final sharing config (or `false` to skip sharing).

---

## `webpack.config.ts`

Applies the module federation config to the Angular base webpack config provided by Nx.
Additional webpack customizations (plugins, output settings, etc.) belong here.

```ts
import { Configuration } from 'webpack'
import { withModuleFederation } from '@nx/angular/module-federation'
import config from './module-federation.config'

export default async function (baseConfig: Configuration) {
  const withMf = await withModuleFederation(config, {
    shareScope: 'angular_21', // required for Angular 21 remotes; use 'default' for Angular 18–20
  })

  const webpackConfig = withMf(baseConfig)

  // Add any additional webpack customization here, e.g.:
  // return {
  //   ...webpackConfig,
  //   plugins: [...(webpackConfig.plugins ?? []), myExtraPlugin],
  //   output: { ...webpackConfig.output, publicPath: 'auto' },
  // }

  return webpackConfig
}
```

**Notes:**
- `withModuleFederation` uses `@module-federation/enhanced` under the hood.
- `shareScope` controls which scope shared packages are registered into.
  Use `'angular_21'` for Angular 21 remotes and `'default'` for Angular 18–20 remotes.
- The function signature must be `async (baseConfig: Configuration) => Configuration`
  because Nx passes the Angular base webpack config as the argument.
- The returned object is the final webpack config that Nx passes to webpack.

---

## `angular.json` / project.json wiring

In `project.json` (or `angular.json` for workspace-level), point the build target to
the TypeScript webpack config:

```json
{
  "targets": {
    "build": {
      "executor": "@nx/angular:webpack-browser",
      "options": {
        "customWebpackConfig": {
          "path": "apps/my-app/webpack.config.ts"
        }
      }
    }
  }
}
```

---

## Required share-scope mapping (Angular 21)

| Remote Angular version | shareScope value |
|------------------------|-----------------|
| Angular 18 / 19 / 20  | `default`       |
| Angular 21             | `angular_21`    |

This mapping is required so the shell resolves shared packages from the correct scope.

---

## Comparison with non-Nx (`@module-federation/enhanced` direct)

| Aspect                | Nx (`@nx/angular/module-federation`)    | Non-Nx (`@module-federation/enhanced`) |
|-----------------------|-----------------------------------------|----------------------------------------|
| Config file extension | `.ts`                                   | `.js` (no `ts-node` by default)        |
| MF plugin setup       | `withModuleFederation()` handles it     | `new ModuleFederationPlugin(config)`   |
| Shared helper         | `shared(libraryName, sharedConfig) =>…` | Custom `buildSharedEntries()` function |
| Base config           | Nx passes Angular base config as arg    | `ngx-build-plus` merges via `extraWebpackConfig` |
