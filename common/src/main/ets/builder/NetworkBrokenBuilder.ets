/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/// 断网横幅
@ComponentV2
export struct NetworkBrokenBuilder {
  build() {
    Column() {
      Text($r('app.string.common_network_error'))
        .fontSize(14)
        .fontColor('#FC596A')
        .width('100%')
        .height(36)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(36)
    .backgroundColor('#FEE3E6')
  }
}