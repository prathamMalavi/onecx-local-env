'use strict';

const { getOneCXSharedRecommendations } = require('@onecx/accelerator');
const { dependencies } = require('./package.json');
const path = require('path');
const fs = require('fs');

// When expanding secondary entry points we iterate a dependency's own exports map
// (e.g. node_modules/rxjs/package.json → exports: { '.', './operators', ... }).
// '.'             = the package root — already registered as shared[libName] above.
// './package.json' = metadata export some packages declare; not an importable module.
const EXPORTS_BLACKLIST = ['.', './package.json'];

/**
 * Builds the module federation shared map from this project's dependencies.
 *
 * Two things happen per package:
 *
 * 1. getOneCXSharedRecommendations decides whether the package should be shared
 *    at all and with what MF settings (singleton, eager, strictVersion, etc.).
 *    If it returns false the package is not shared.
 *
 * 2. If the recommendation includes `includeSecondaries: true`, we also register
 *    every secondary entry point the package publishes (e.g. `rxjs/operators`,
 *    `@angular/core/rxjs-interop`). This is needed because @module-federation/enhanced
 *    does not expand secondary entry points automatically. Without this, a consumer
 *    that imports `rxjs/operators` would not reuse the shared copy and would bundle
 *    its own duplicate instead.
 *    We find secondary entry points by reading the package's own `exports` map in
 *    node_modules. fs.existsSync guards against packages that are listed in
 *    dependencies but not yet installed (e.g. optional or peer packages).
 */
function buildSharedEntries(deps) {
  const shared = {};

  for (const libName of Object.keys(deps)) {
    // Pass the version range from package.json directly — no need for 'auto' resolution.
    const recommendation = getOneCXSharedRecommendations(libName, {
      requiredVersion: deps[libName],
      includeSecondaries: true,
    });

    if (recommendation === false) continue;

    const { includeSecondaries, ...mfConfig } = recommendation;
    const entryConfig = { ...mfConfig, shareScope: 'angular_21' };
    shared[libName] = entryConfig;

    if (includeSecondaries) {
      const pkgJsonPath = path.join(__dirname, 'node_modules', libName, 'package.json');
      if (!fs.existsSync(pkgJsonPath)) continue;

      const pkgJson = JSON.parse(fs.readFileSync(pkgJsonPath, 'utf8'));
      if (!pkgJson.exports) continue;

      for (const exportKey of Object.keys(pkgJson.exports)) {
        if (EXPORTS_BLACKLIST.includes(exportKey)) continue;
        shared[`${libName}/${exportKey.replace('./', '')}`] = entryConfig;
      }
    }
  }

  return shared;
}

module.exports = {
  name: 'onecx-angular-21-module-test',
  filename: 'remoteEntry.js',
  // Use ES module output so the container name does not need to be a valid JS identifier.
  // This matches the Angular-architect/module-federation default and works with Angular 21
  // which uses ES module output (experiments.outputModule: true).
  library: { type: 'module' },
  exposes: {
    './RemoteModule': 'src/remote-main.ts',
  },
  shared: buildSharedEntries(dependencies),
  shareScope: 'angular_21',
  // Disable the manifest plugin: it requires a standalone webpack context to locate
  // the remoteEntry chunk, which is not available when building via ngx-build-plus.
  manifest: false,
};
