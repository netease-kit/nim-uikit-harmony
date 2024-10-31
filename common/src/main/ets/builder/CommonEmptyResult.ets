/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@ComponentV2
export struct CommonEmptyResult {
  @Param emptyImage?: Resource = $r('app.media.empty_image')
  @Param tips?: ResourceStr = $r('app.string.empty_tips')
  @Param emptyImageHeight?: number = 91
  @Param emptyImageWidth?: number = 122
  @Param fontSize?: number = 14
  @Param fontColor?: ResourceStr = '#B3B7BC'

  build() {
    Column() {
      Image(this.emptyImage)
        .width(this.emptyImageWidth)
        .height(this.emptyImageHeight)
        .objectFit(ImageFit.Contain)
        .margin({ top: 80 })

      Text(this.tips)
        .fontSize(this.fontSize)
        .fontColor(this.fontColor)
        .margin({
          top: 8
        })

    }
    .width('100%').height('100%')
    .backgroundColor(Color.Transparent)
  }
}