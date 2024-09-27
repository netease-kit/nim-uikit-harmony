/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

// 通用导航栏
interface NavigationTitleBuilderParams {
  title?: ResourceStr;
  brandIcon?: Resource;
  firstButtonTitle?: ResourceStr;
  firstButtonColor?: ResourceColor;
  firstButtonIcon?: Resource;
  firstButtonAction?: (() => void);
  secondButtonTitle?: ResourceStr;
  secondButtonColor?: ResourceColor;
  secondButtonIcon?: Resource;
  secondButtonAction?: (() => void);
  backgroundColor?: ResourceColor;
}

@Builder
export function NavigationTitleBuilder(params: NavigationTitleBuilderParams) {

  Column() {
    Row() {
      if (params.brandIcon) {
        Image(params.brandIcon)
          .margin({ left: 20 })
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
      }

      if (params.title) {
        Text(params.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .height(32)
          .width('100%')
          .margin({ left: params.brandIcon ? 12 : 20, right: 12 })
          .layoutWeight(2)
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Row()
        .height(1)
        .layoutWeight(1)

      if (params.firstButtonTitle) {
        Text(params.firstButtonTitle)
          .fontSize(16)
          .fontColor(params.firstButtonColor)
          .width(32)
          .height(18)
          .margin({ right: 20 })
          .onClick(params.firstButtonAction)
      }

      if (params.firstButtonIcon) {
        Image(params.firstButtonIcon)
          .width(32)
          .height(32)
          .padding({
            left: 3,
            right: 3,
            top: 3,
            bottom: 3
          })
          .margin({ right: (params.secondButtonTitle || params.secondButtonIcon) ? 10 : 20 })
          .onClick(params.firstButtonAction)
      }

      if (params.secondButtonTitle) {
        Text(params.secondButtonTitle)
          .fontSize(16)
          .fontColor(params.secondButtonColor)
          .width(32)
          .height(18)
          .margin({ right: 20 })
          .onClick(params.secondButtonAction)
      }

      if (params.secondButtonIcon) {
        Image(params.secondButtonIcon)
          .width(32)
          .height(32)
          .padding({
            left: 3,
            right: 3,
            top: 3,
            bottom: 3
          })
          .margin({ right: 20 })
          .onClick(params.secondButtonAction)
      }
    }
    .height(55)
    .alignSelf(ItemAlign.Start)

    Row()
      .width('100%')
      .height(1)
      .backgroundColor("#E9EFF5")
  }
  .height(56)
  .width('100%')
  .backgroundColor(params.backgroundColor ?? Color.White)
}