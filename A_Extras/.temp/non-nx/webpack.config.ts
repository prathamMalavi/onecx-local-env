
/*
import { Configuration } from 'webpack'
import { withModuleFederation } from '@nx/angular/module-federation'
import config from './module-federation.config'

export default async function (baseConfig: Configuration) {
  const withMf = await withModuleFederation(config, {
    shareScope: 'angular_21' // required for Angular 21 remotes
  })

  return withMf(baseConfig) // additional custom webpack configuration can be added here
}
*/