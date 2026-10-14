Without using getOnecxSharedRecommendations 

```ts
// This is a non nx application using the old @angular-architects/module-federation approach. 
// New @module-federation/enhanced Approach for non nx applications. For nx applications, we can use the @nx/module-federation which uses module federation enhanced under the hood and provides better integration with nx and angular.

const {
  ModifyEntryPlugin,
} = require('@angular-architects/module-federation/src/utils/modify-entry-plugin');
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

const sharedEntries = {
  '@angular/core': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@angular/common': {
    requiredVersion: 'auto',
    includeSecondaries: { skip: ['@angular/common/http/testing'] },
    shareScope: 'angular_21',
  },
  '@angular/common/http': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@angular/forms': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@angular/platform-browser': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@angular/router': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  rxjs: { requiredVersion: 'auto', includeSecondaries: true, shareScope: 'angular_21' },
  '@onecx/angular-integration-interface': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@onecx/angular-utils': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@onecx/angular-webcomponents': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@onecx/angular-accelerator': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@onecx/angular-auth': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@ngx-translate/core': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  '@ngx-translate/http-loader': {
    requiredVersion: 'auto',
    includeSecondaries: true,
    shareScope: 'angular_21',
  },
  primeng: { requiredVersion: 'auto', includeSecondaries: true, shareScope: 'angular_21' },
};

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
  '@angular/core': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/core/event-dispatch-contract.min.js': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/core/primitives/di': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/core/primitives/event-dispatch': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/core/primitives/signals': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/core/rxjs-interop': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/core/testing': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/common': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/common/http': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/common/testing': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/common/upgrade': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/forms': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/forms/signals': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/forms/signals/compat': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/platform-browser': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/platform-browser/animations': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/platform-browser/animations/async': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/platform-browser/testing': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/router': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  '@angular/router/testing': {
    requiredVersion: '^21.1.6',
    shareScope: 'angular_21',
    version: '21.1.6'
  },
  rxjs: {
    requiredVersion: '~7.8.0',
    shareScope: 'angular_21',
    version: '7.8.0'
  },
  'rxjs/ajax': {
    requiredVersion: '~7.8.0',
    shareScope: 'angular_21',
    version: '7.8.0'
  },
  'rxjs/fetch': {
    requiredVersion: '~7.8.0',
    shareScope: 'angular_21',
    version: '7.8.0'
  },
  'rxjs/operators': {
    requiredVersion: '~7.8.0',
    shareScope: 'angular_21',
    version: '7.8.0'
  },
  'rxjs/testing': {
    requiredVersion: '~7.8.0',
    shareScope: 'angular_21',
    version: '7.8.0'
  },
  'rxjs/webSocket': {
    requiredVersion: '~7.8.0',
    shareScope: 'angular_21',
    version: '7.8.0'
  },
  '@onecx/angular-integration-interface': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-integration-interface/mocks': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-utils': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-utils/guards': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-utils/mocks': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-utils/style': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-utils/theme/primeng': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-webcomponents': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-accelerator': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-accelerator/migrations.json': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-accelerator/testing': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@onecx/angular-auth': {
    requiredVersion: '^8.0.0-rc.7',
    shareScope: 'angular_21',
    version: '8.0.0-rc.7'
  },
  '@ngx-translate/core': {
    requiredVersion: '^17.0.0',
    shareScope: 'angular_21',
    version: '17.0.0'
  },
  '@ngx-translate/http-loader': {
    requiredVersion: '^17.0.0',
    shareScope: 'angular_21',
    version: '17.0.0'
  },
  primeng: {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/accordion': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/animateonscroll': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/api': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/autocomplete': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/autofocus': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/avatar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/avatargroup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/badge': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/base': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/basecomponent': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/baseeditableholder': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/baseinput': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/basemodelholder': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/bind': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/blockui': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/breadcrumb': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/button': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/buttongroup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/card': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/carousel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/cascadeselect': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/chart': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/checkbox': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/chip': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/classnames': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/colorpicker': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/config': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/confirmdialog': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/confirmpopup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/contextmenu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/dataview': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/datepicker': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/dialog': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/divider': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/dock': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/dom': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/dragdrop': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/drawer': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/dynamicdialog': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/editor': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/fieldset': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/fileupload': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/floatlabel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/fluid': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/focustrap': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/galleria': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/iconfield': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/angledoubledown': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/angledoubleleft': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/angledoubleright': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/angledoubleup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/angledown': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/angleleft': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/angleright': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/angleup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/arrowdown': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/arrowdownleft': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/arrowdownright': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/arrowleft': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/arrowright': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/arrowup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/ban': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/bars': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/baseicon': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/blank': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/calendar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/caretleft': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/caretright': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/check': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/chevrondown': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/chevronleft': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/chevronright': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/chevronup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/exclamationtriangle': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/eye': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/eyeslash': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/filter': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/filterfill': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/filterslash': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/home': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/infocircle': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/minus': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/pencil': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/plus': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/refresh': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/search': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/searchminus': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/searchplus': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/sortalt': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/sortamountdown': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/sortamountupalt': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/spinner': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/star': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/starfill': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/thlarge': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/times': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/timescircle': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/trash': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/undo': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/upload': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/windowmaximize': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/icons/windowminimize': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/iftalabel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/image': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/imagecompare': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/inplace': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/inputgroup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/inputgroupaddon': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/inputicon': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/inputmask': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/inputnumber': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/inputotp': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/inputtext': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/keyfilter': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/knob': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/listbox': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/megamenu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/menu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/menubar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/message': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/metergroup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/motion': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/multiselect': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/orderlist': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/organizationchart': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/overlay': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/overlaybadge': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/paginator': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/panel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/panelmenu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/passthrough': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/password': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/picklist': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/popover': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/progressbar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/progressspinner': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/radiobutton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/rating': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/ripple': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/scroller': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/scrollpanel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/scrolltop': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/select': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/selectbutton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/skeleton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/slider': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/speeddial': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/splitbutton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/splitter': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/stepper': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/steps': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/styleclass': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/table': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/tabs': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/tag': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/terminal': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/textarea': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/tieredmenu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/timeline': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/toast': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/togglebutton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/toggleswitch': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/toolbar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/tooltip': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/tree': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/treeselect': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/treetable': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/ts-helpers': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/accordion': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/autocomplete': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/avatar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/avatargroup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/badge': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/blockui': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/breadcrumb': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/button': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/card': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/carousel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/cascadeselect': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/chart': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/checkbox': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/chip': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/colorpicker': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/confirmdialog': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/confirmpopup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/contextmenu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/dataview': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/datepicker': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/dialog': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/divider': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/dock': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/drawer': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/editor': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/fieldset': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/fileupload': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/floatlabel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/fluid': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/galleria': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/iconfield': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/iftalabel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/image': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/imagecompare': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/inplace': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/inputgroup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/inputgroupaddon': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/inputicon': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/inputmask': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/inputnumber': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/inputotp': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/inputtext': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/knob': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/listbox': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/megamenu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/menu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/menubar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/message': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/metergroup': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/motion': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/multiselect': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/orderlist': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/organizationchart': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/overlay': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/overlaybadge': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/paginator': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/panel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/panelmenu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/password': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/picklist': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/popover': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/progressbar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/progressspinner': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/radiobutton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/rating': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/scroller': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/scrollpanel': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/scrolltop': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/select': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/selectbutton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/skeleton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/slider': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/speeddial': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/splitbutton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/splitter': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/stepper': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/table': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/tabs': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/tag': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/terminal': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/textarea': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/tieredmenu': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/timeline': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/toast': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/togglebutton': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/toggleswitch': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/toolbar': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/tooltip': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/tree': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/treeselect': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/types/treetable': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/usestyle': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
  },
  'primeng/utils': {
    requiredVersion: '^21.1.3',
    shareScope: 'angular_21',
    version: '21.1.3'
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