/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { http } from '@kit.NetworkKit';

export interface ReportInfo {
  appKey: string,

  //组件名
  component: string
  version: string
  imVersion: string,
  platform: string,
  reportType: string, //init,pv,uv,apiEvent
  timeStamp: number
}

export class KitReport {
  static reportUrl: string =
    'https://statistic.live.126.net/statics/report/xkit/action';

  static reportToServer(info: ReportInfo) {
    let httpClient = http.createHttp();
    httpClient.request(KitReport.reportUrl,
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'charset': 'utf-8'
        },
        extraData: info,
        connectTimeout: 60000, // 可选，默认为60000ms
        readTimeout: 60000, // 可选，默认为60000ms
      }, (err, data) => {
        if (!err) {
          console.debug('xKitReport report success')
        }
        console.debug('xKitReport report failed')
      })

  }
}