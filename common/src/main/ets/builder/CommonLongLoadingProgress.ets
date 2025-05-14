/**
 * CommonLongLoadingProgress
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−04-11
 *
 * Copyright © 2025 Netease. All rights reserved.
 */

@Extend(Column)
function cardStyle() {
  .backgroundColor(Color.White)
  .width('100%')
}

@Extend(Text)
function centerTitleStyle() {
  .fontColor('#182431')
  .fontSize(14)
  .height(22)
  .alignSelf(ItemAlign.Center)
  .margin({ left: 12, top: 6 })
}

@ComponentV2
export struct CommonLongLoadingProgress {
  @Param contentText?: Resource | undefined = undefined
  build() {
    Column() {
      Column() {
        LoadingProgress()
          .width(50)
          .height(50)
          .color('#51AFF8')
      }
      .cardStyle()
      .width('100%')
      Text(this.contentText)
          .centerTitleStyle()
    }
    .height('100%')
    .width('100%')
  }
}