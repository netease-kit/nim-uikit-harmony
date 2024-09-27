/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { VideoItemView } from './VideoItemView';

/*
  视频查看器
 */
@CustomDialog
export struct VideoViewerDialog {
  controller?: CustomDialogController
  videoUrl?: string
  videoRatio?: number = 2 // 元素宽高比

  build() {
    Column() {
      VideoItemView({
        videoUrl: this.videoUrl,
        videoRatio: this.videoRatio
      })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onClick(() => {
      this.controller?.close()
    })
  }
}