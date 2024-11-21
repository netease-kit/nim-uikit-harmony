/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * Request params of protocol:
 * uploadLogUrl
 */
export class UploadLogUrlRequest {
  public url: string
  public info: UploadLogUrlParams

  public constructor(url: string, info: UploadLogUrlParams) {
    this.url = url
    this.info = info
  }
}

/**
 * Params of 'UploadLogUrlRequest'
 */
export class UploadLogUrlParams {
  public sdklogUploadType: number

  public constructor(sdklogUploadType: number) {
    this.sdklogUploadType = sdklogUploadType
  }
}
