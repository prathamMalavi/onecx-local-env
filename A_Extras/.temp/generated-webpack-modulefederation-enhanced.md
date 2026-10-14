

```ts
// New @module-federation/enhanced Approach for non nx applications. For nx applications, we can use the @nx/module-federation which uses module federation enhanced under the hood and provides better integration with nx and angular.
// This is a non nx application
// New @module-federation/enhanced Approach 
const { ModuleFederationPlugin } = require('@module-federation/enhanced/webpack');
const { ModifySourcePlugin, ReplaceOperation } = require('modify-source-webpack-plugin');
const webpack = require('webpack');
const isProduction = process.env.NODE_ENV === 'production';
const { getOneCXSharedRecommendations } = require('@onecx/accelerator');
const { dependencies } = require('./package.json');
const sharedEntries = {};

for (const libName of Object.keys(dependencies)) {
  const result = getOneCXSharedRecommendations(libName, {
    requiredVersion: dependencies[libName],
    shareScope: 'angular_21',
  });
  if (result !== false) {
    sharedEntries[libName] = result;
  }
}
const mfConfig = {
  name: 'onecx-angular-21-module-test',
  filename: 'remoteEntry.js',
  library: { type: 'module' },
  exposes: {
    './RemoteModule': 'src/remote-main.ts',
  },
  shared: sharedEntries,
  shareScope: 'angular_21',
  manifest: false,
};

const modifyMaterialPlugin = new ModifySourcePlugin({
  rules: [
    {
      test: (module) => {
        return (
          module.resource &&
          (module.resource.includes('@angular/material') ||
            module.resource.includes('@angular/cdk'))
        );
      },
      operations: [
        new ReplaceOperation(
          'all',
          'document\\.createElement\\(',
          'document.createElementFromMaterial({"this": this, "arguments": Array.from(arguments)},',
        ),
      ],
    },
  ],
});

const webpackConfig = {
  devServer: { allowedHosts: 'all' },
  plugins: [
    new ModuleFederationPlugin(mfConfig),
    modifyMaterialPlugin,
    new webpack.DefinePlugin({ ngDevMode: JSON.stringify(!isProduction) }),
  ],
  output: { uniqueName: 'onecx-angular-21-module-test', publicPath: 'auto' },
  module: { parser: { javascript: { importMeta: false } } },
  experiments: { topLevelAwait: true, outputModule: true },
  optimization: { runtimeChunk: false, splitChunks: false },
};





console.log("=====================================================================================");
console.log("=====================================================================================");
console.log("Module Federation CONFIG CREATED");
console.log("=====================================================================================");
console.log('');
console.log('```javascript');
console.log('');
console.log('Module Federation config', mfConfig);
console.log('');
console.log('```');
console.log('');
console.log("=====================================================================================");
console.log("=====================================================================================");
console.log("SHARED ENTRIES CONFIG CREATED");
console.log("=====================================================================================");
console.log('');
console.log('```javascript');
console.log('');
console.log('Shared entries', sharedEntries);
console.log('');
console.log('```');
console.log('');
console.log("=====================================================================================");
console.log("=====================================================================================");
console.log("WEBPACK CONFIG CREATED");
console.log("=====================================================================================");
console.log('');
console.log('```javascript');
console.log('');
console.log('Webpack config', webpackConfig);
console.log('');
console.log('```');
console.log('');

module.exports  = webpackConfig;

```
=====================================================================================
=====================================================================================
Module Federation CONFIG CREATED
=====================================================================================

```javascript

Module Federation config {
  name: 'onecx-angular-21-module-test',
  filename: 'remoteEntry.js',
  library: { type: 'module' },
  exposes: { './RemoteModule': 'src/remote-main.ts' },
  shared: {
    '@angular-architects/module-federation': {
      requiredVersion: '^20.0.0',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/animations': {
      requiredVersion: '^21.1.6',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/cdk': {
      requiredVersion: '^21.1.6',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/common': {
      requiredVersion: '^21.1.6',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/compiler': {
      requiredVersion: '^21.1.6',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/core': {
      requiredVersion: '^21.1.6',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/elements': {
      requiredVersion: '^21.1.16',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/forms': {
      requiredVersion: '^21.1.6',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/platform-browser': {
      requiredVersion: '^21.1.6',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@angular/router': {
      requiredVersion: '^21.1.6',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@ngx-translate/core': {
      requiredVersion: '^17.0.0',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@ngx-translate/http-loader': {
      requiredVersion: '^17.0.0',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@onecx/angular-accelerator': {
      requiredVersion: '^8.0.0-rc.7',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@onecx/angular-auth': {
      requiredVersion: '^8.0.0-rc.7',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@onecx/angular-integration-interface': {
      requiredVersion: '^8.0.0-rc.7',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@onecx/angular-utils': {
      requiredVersion: '^8.0.0-rc.7',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@onecx/angular-webcomponents': {
      requiredVersion: '^8.0.0-rc.7',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    '@onecx/accelerator': {
      requiredVersion: '^8.0.0-rc.7',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    primeng: {
      requiredVersion: '^21.1.3',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    },
    rxjs: {
      requiredVersion: '~7.8.0',
      shareScope: 'angular_21',
      singleton: false,
      strictVersion: false,
      eager: false
    }
  },
  shareScope: 'angular_21',
  manifest: false
}

```

=====================================================================================
=====================================================================================
SHARED ENTRIES CONFIG CREATED
=====================================================================================

```javascript

Shared entries {
  '@angular-architects/module-federation': {
    requiredVersion: '^20.0.0',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/animations': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/cdk': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/common': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/compiler': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/core': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/elements': {
    requiredVersion: '^21.1.16',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/forms': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/platform-browser': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@angular/router': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@ngx-translate/core': {
    requiredVersion: '^17.0.0',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@ngx-translate/http-loader': {
    requiredVersion: '^17.0.0',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@onecx/angular-accelerator': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@onecx/angular-auth': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@onecx/angular-integration-interface': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@onecx/angular-utils': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@onecx/angular-webcomponents': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  '@onecx/accelerator': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  primeng: {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  },
  rxjs: {
    requiredVersion: '~7.8.0',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false
  }
}

```

=====================================================================================
=====================================================================================
WEBPACK CONFIG CREATED
=====================================================================================

```javascript

Webpack config {
  devServer: { allowedHosts: 'all' },
  plugins: [
    ModuleFederationPlugin {
      _options: [Object],
      pluginName: 'ModuleFederationPlugin',
      coreModulePath: '../lib/container/ModuleFederationPlugin',
      name: 'ModuleFederationPlugin'
    },
    ModifySourcePlugin { options: [Object] },
    DefinePlugin { definitions: [Object] }
  ],
  output: { uniqueName: 'onecx-angular-21-module-test', publicPath: 'auto' },
  module: { parser: { javascript: [Object] } },
  experiments: { topLevelAwait: true, outputModule: true },
  optimization: { runtimeChunk: false, splitChunks: false }
}

```
