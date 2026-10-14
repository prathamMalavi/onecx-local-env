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


module.exports = {
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

