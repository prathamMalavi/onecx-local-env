// @module-federation/enhanced approach for non-Nx applications.
// Configuration is split into two files:
//   module-federation.config.js  — declares app name, exposes, and shared dependencies
//   webpack.config.js            — applies the MF plugin and additional webpack settings
//
// NOTE: TypeScript (.ts) config files are not supported here because ngx-build-plus loads
// extraWebpackConfig via Node.js require(), which has no TypeScript support. ts-node is not
// installed in this project. TypeScript webpack configs only work in Nx applications, where
// the Nx build system compiles them before passing them to webpack.
'use strict';

const { ModuleFederationPlugin } = require('@module-federation/enhanced/webpack');
const { ModifySourcePlugin, ReplaceOperation } = require('modify-source-webpack-plugin');
const webpack = require('webpack');
const mfConfig = require('./module-federation.config');

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

module.exports = {
  plugins: [
    new ModuleFederationPlugin(mfConfig),
    modifyMaterialPlugin,
    new webpack.DefinePlugin({ ngDevMode: JSON.stringify(!isProduction) }),
  ],
  devServer: { allowedHosts: 'all' },
  output: { uniqueName: 'onecx-angular-21-module-test', publicPath: 'auto' },
  module: { parser: { javascript: { importMeta: false } } },
  experiments: { outputModule: true, topLevelAwait: true },
  optimization: { runtimeChunk: false, splitChunks: false },
};
