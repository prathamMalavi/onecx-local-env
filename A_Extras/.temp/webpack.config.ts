//@ts-check
// New @module-federation/enhanced Approach for non nx applications. For nx applications, we can use the @nx/module-federation which uses module federation enhanced under the hood and provides better integration with nx and angular.
// This is a non nx application
const { ModifySourcePlugin, ReplaceOperation } = require('modify-source-webpack-plugin');
const webpack = require('webpack');
const isProduction = process.env.NODE_ENV === 'production';
const mfConfig = 

//@ts-ignore  
const modifyMaterialPlugin = new ModifySourcePlugin({
  rules: [
    {
      test: (module: any) => {
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







// cd /root/onecx/apps/test-apps/onecx-angular-21-module-test
// npm start -- --host 0.0.0.0 --port 4201 --disable-host-check





// Old Architech Approach 

// const {
//   ModifyEntryPlugin,
// } = require('@angular-architects/module-federation/src/utils/modify-entry-plugin');
// const {
//   share,
//   withModuleFederationPlugin,
// } = require('@angular-architects/module-federation/webpack');
// const { ModifySourcePlugin, ReplaceOperation } = require('modify-source-webpack-plugin');
// const webpack = require('webpack');
// const isProduction = process.env.NODE_ENV === 'production';

// const modifyMaterialPlugin = new ModifySourcePlugin({
//   rules: [
//     {
//       test: (module) => {
//         return (
//           module.resource &&
//           (module.resource.includes('@angular/material') ||
//             module.resource.includes('@angular/cdk'))
//         );
//       },
//       operations: [
//         new ReplaceOperation(
//           'all',
//           'document\\.createElement\\(',
//           'document.createElementFromMaterial({"this": this, "arguments": Array.from(arguments)},',
//         ),
//       ],
//     },
//   ],
// });

// const sharedEntries = share({
//     '@angular/core': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@angular/common': {
//       requiredVersion: 'auto',
//       includeSecondaries: { skip: ['@angular/common/http/testing'] },
//       shareScope: 'angular_21',
//     },
//     '@angular/common/http': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@angular/forms': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@angular/platform-browser': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@angular/router': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     rxjs: { requiredVersion: 'auto', includeSecondaries: true, shareScope: 'angular_21' },
//     '@onecx/angular-integration-interface': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@onecx/angular-utils': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@onecx/angular-webcomponents': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@onecx/angular-accelerator': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@onecx/angular-auth': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@ngx-translate/core': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     '@ngx-translate/http-loader': {
//       requiredVersion: 'auto',
//       includeSecondaries: true,
//       shareScope: 'angular_21',
//     },
//     primeng: { requiredVersion: 'auto', includeSecondaries: true, shareScope: 'angular_21' },
//   });

// const config = withModuleFederationPlugin({
//   name: 'onecx-angular-21-module-test',
//   filename: 'remoteEntry.js',
//   exposes: {
//     './RemoteModule': 'src/remote-main.ts',
//   },
//   shared: sharedEntries,
//   shareScope: 'angular_21',
// });

// config.devServer = { allowedHosts: 'all' };
// const plugins = config.plugins.filter((plugin) => !(plugin instanceof ModifyEntryPlugin));

// const webpackConfig = {
//   ...config,
//   plugins: [
//     ...plugins,
//     modifyMaterialPlugin,
//     new webpack.DefinePlugin({ ngDevMode: JSON.stringify(!isProduction) }),
//   ],
//   output: { uniqueName: 'onecx-angular-21-module-test', publicPath: 'auto' },
//   module: { parser: { javascript: { importMeta: false } } },
//   experiments: { ...config.experiments, topLevelAwait: true },
//   optimization: { runtimeChunk: false, splitChunks: false },
// };


// console.log("=====================================================================================");
// console.log("=====================================================================================");
// console.log("Module Federation CONFIG CREATED");
// console.log("=====================================================================================");
// console.log('');
// console.log('```javascript');
// console.log('');
// console.log('Module Federation config', config);
// console.log('');
// console.log('```');
// console.log('');
// console.log("=====================================================================================");
// console.log("=====================================================================================");
// console.log("SHARED ENTRIES CONFIG CREATED");
// console.log("=====================================================================================");
// console.log('');
// console.log('```javascript');
// console.log('');
// console.log('Shared entries', sharedEntries);
// console.log('');
// console.log('```');
// console.log('');
// console.log("=====================================================================================");
// console.log("=====================================================================================");
// console.log("WEBPACK CONFIG CREATED");
// console.log("=====================================================================================");
// console.log('');
// console.log('```javascript');
// console.log('');
// console.log('Webpack config', webpackConfig);
// console.log('');
// console.log('```');
// console.log('');

// module.exports = webpackConfig;



