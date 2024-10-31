/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import BuildProfile from '../../../BuildProfile'
import { KitReport } from './KitReport'

export class CoreKitClient {
  static init(param: CoreKitInitParam) {
    KitReport.reportToServer({
      appKey: param.appKey,
      component: 'ChatKit',
      version: BuildProfile.HAR_VERSION,
      imVersion: param.imVersion ?? '',
      platform: 'harmony',
      reportType: 'init',
      timeStamp: Date.now()
    })
  }
}

export interface CoreKitInitParam {
  //NIM 应用 AppKey
  appKey: string,

  //NIM SDK 版本
  imVersion?: string,
}