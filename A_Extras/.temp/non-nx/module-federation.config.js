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

module.exports = mfConfig;