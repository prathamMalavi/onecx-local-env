Using getOnecxSharedRecommendations 


```ts
const {
  ModifyEntryPlugin,
} = require('@angular-architects/module-federation/src/utils/modify-entry-plugin');
const { getOneCXSharedRecommendations } = require('@onecx/accelerator');
const { dependencies } = require('./package.json');

const sharedEntries = {};
for (const libName of Object.keys(dependencies)) {
  const result = getOneCXSharedRecommendations(libName, { requiredVersion: 'auto', includeSecondaries: true })
  if (result !== false) {
    sharedEntries[libName] = result
  }
}


const {
  share,
  withModuleFederationPlugin,
} = require('@angular-architects/module-federation/webpack');
const { ModifySourcePlugin, ReplaceOperation } = require('modify-source-webpack-plugin');
const webpack = require('webpack');
const isProduction = process.env.NODE_ENV === 'production';

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

const mfConfig = withModuleFederationPlugin({
  name: 'onecx-angular-21-module-test',
  filename: 'remoteEntry.js',
  exposes: {
    './RemoteModule': 'src/remote-main.ts',
  },
  shared: share(sharedEntries),
  shareScope: 'angular_21',
});

mfConfig.devServer = { allowedHosts: 'all' };
const plugins = mfConfig.plugins.filter((plugin) => !(plugin instanceof ModifyEntryPlugin));

const webpackConfig = {
  ...mfConfig,
  plugins: [
    ...plugins,
    modifyMaterialPlugin,
    new webpack.DefinePlugin({ ngDevMode: JSON.stringify(!isProduction) }),
  ],
  output: { uniqueName: 'onecx-angular-21-module-test', publicPath: 'auto' },
  module: { parser: { javascript: { importMeta: false } } },
  experiments: { ...mfConfig.experiments, topLevelAwait: true },
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

module.exports = webpackConfig;



```




=====================================================================================
=====================================================================================
Module Federation CONFIG CREATED
=====================================================================================

```javascript

Module Federation config {
  output: { publicPath: 'auto' },
  optimization: { runtimeChunk: false },
  resolve: { alias: {} },
  experiments: { outputModule: true },
  plugins: [
    ModuleFederationPlugin { _options: [Object] },
    NormalModuleReplacementPlugin {
      resourceRegExp: /./,
      newResource: [Function (anonymous)]
    }
  ],
  devServer: { allowedHosts: 'all' }
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
    eager: false,
    version: '20.0.0'
  },
  '@angular/animations': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.6'
  },
  '@angular/cdk': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.6'
  },
  '@angular/common': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.6'
  },
  '@angular/compiler': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.6'
  },
  '@angular/core': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.6'
  },
  '@angular/elements': {
    requiredVersion: '^21.1.16',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.16'
  },
  '@angular/forms': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.6'
  },
  '@angular/platform-browser': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.6'
  },
  '@angular/router': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.6'
  },
  '@ngx-translate/core': {
    requiredVersion: '^17.0.0',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '17.0.0'
  },
  '@ngx-translate/http-loader': {
    requiredVersion: '^17.0.0',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '17.0.0'
  },
  '@onecx/angular-accelerator': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-auth': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-integration-interface': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-utils': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-webcomponents': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '8.0.0-rc.7'
  },
  '@onecx/accelerator': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '8.0.0-rc.7'
  },
  primeng: {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '21.1.3'
  },
  rxjs: {
    requiredVersion: '~7.8.0',
    shareScope: 'angular_21',
    singleton: false,
    strictVersion: false,
    eager: false,
    version: '7.8.0'
  }
}

```

=====================================================================================
=====================================================================================
WEBPACK CONFIG CREATED
=====================================================================================

```javascript

Webpack config {
  output: { uniqueName: 'onecx-angular-21-module-test', publicPath: 'auto' },
  optimization: { runtimeChunk: false, splitChunks: false },
  resolve: { alias: {} },
  experiments: { outputModule: true, topLevelAwait: true },
  plugins: [
    ModuleFederationPlugin { _options: [Object] },
    NormalModuleReplacementPlugin {
      resourceRegExp: /./,
      newResource: [Function (anonymous)]
    },
    ModifySourcePlugin { options: [Object] },
    DefinePlugin { definitions: [Object] }
  ],
  devServer: { allowedHosts: 'all' },
  module: { parser: { javascript: [Object] } }
}

```

