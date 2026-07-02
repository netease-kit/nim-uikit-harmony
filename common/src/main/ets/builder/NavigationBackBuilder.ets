/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

// 通用导航栏
interface NavigationBackBuilderParams {
  title?: ResourceStr;
  titleSuffix?: ResourceStr; // 标题后缀，如 "(在线)" / "(离线)"，始终完整显示
  titleSuffixIcon?: Resource; // 标题后缀图标，如听筒图标
  subtitle?: ResourceStr; // 标题下方副标题
  leftButtonTitle?: ResourceStr;
  leftButtonColor?: ResourceColor;
  leftButtonIcon?: Resource;
  leftButtonAction?: (() => void);
  showDivideLine?: boolean;
  rightButtonTitle?: ResourceStr;
  rightButtonColor?: ResourceColor;
  rightButtonIcon?: Resource;
  rightButtonAction?: (() => void);
  backgroundColor?: ResourceColor;
  buttonTextWidth?: number;
  onlineState?: boolean;
  // 正在输入提示（始终占位，通过 visibility 控制显隐）
  enableTypingIndicator?: boolean;
  showTypingIndicator?: boolean;
  typingIndicatorText?: ResourceStr;
}

@Builder
export function NavigationBackBuilder(params?: NavigationBackBuilderParams) {
  Column() {
    Row() {
      if (params?.leftButtonTitle || params?.leftButtonIcon) {
        if (params?.leftButtonTitle) {
          Text(params?.leftButtonTitle)
            .fontSize(16)
            .fontColor(params?.leftButtonColor)
            .width(32)
            .height(18)
            .margin({ left: 20 })
            .onClick(params?.leftButtonAction)
        } else if (params?.leftButtonIcon) {
          Image(params?.leftButtonIcon)
            .width(32)
            .height(32)
            .padding({
              left: 3,
              right: 3,
              top: 3,
              bottom: 3
            })
            .margin({ left: 20 })
            .onClick(params?.leftButtonAction)
        }
      } else {
        Image($r('app.media.nav_back'))
          .margin({ left: 20 })
          .width(32)
          .height(26)
          .objectFit(ImageFit.Contain)
          .padding({
            left: 9,
            right: 15,
            top: 5,
            bottom: 5.5
          })
          .onClick(params?.leftButtonAction)
      }

      // 标题区域：两行结构，昵称居中，正在输入提示在下方
      Column() {
        // 第一行：昵称 + 后缀 + 后缀图标
        Row() {
          Text(params?.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: (params?.titleSuffix || params?.titleSuffixIcon) ? '70%' : '100%' })

          if (params?.titleSuffix) {
            Text(params.titleSuffix)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .flexShrink(0) // 不允许收缩，始终完整显示
          }

          if (params?.titleSuffixIcon) {
            Image(params.titleSuffixIcon)
              .width(16)
              .height(16)
              .margin({ left: 4 })
              .flexShrink(0) // 不允许收缩，始终完整显示
          }
        }
        .justifyContent(FlexAlign.Center)

        if (params?.subtitle !== undefined) {
          Text(params.subtitle)
            .fontSize(11)
            .fontColor('#999999')
            .padding({ top: 2, bottom: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (params?.enableTypingIndicator && params?.typingIndicatorText !== undefined) {
          // 第二行：正在输入提示（始终占位，visibility 控制显隐）
          Text(params.typingIndicatorText)
            .fontSize(11)
            .fontColor('#999999')
            .visibility(params?.showTypingIndicator ? Visibility.Visible : Visibility.Hidden)
            .padding({ top: 2, bottom: 2 })
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({
        left: params?.buttonTextWidth ? (params.buttonTextWidth - 32 + 8) : 8,
        right: (params?.rightButtonTitle || params?.rightButtonIcon) ? 8 : 60
      })
      .layoutWeight(1)

      if (params?.rightButtonTitle) {
        Text(params?.rightButtonTitle)
          .fontSize(16)
          .fontColor(params?.rightButtonColor)
          .width(params?.buttonTextWidth ?? 32)
          .height(18)
          .margin({ right: 20 })
          .onClick(params?.rightButtonAction)
          .textAlign(TextAlign.End)
      }

      if (params?.rightButtonIcon) {
        Image(params?.rightButtonIcon)
          .width(32)
          .height(32)
          .padding({
            left: 3,
            right: 3,
            top: 3,
            bottom: 3
          })
          .margin({ right: 20 })
          .onClick(params?.rightButtonAction)
      }
    }
    .height(56)
    .alignItems(VerticalAlign.Center)

    if (params?.showDivideLine) {
      Row()
        .width('100%')
        .height(1)
        .backgroundColor("#E9EFF5")
    }
  }
  .width('100%')
  .justifyContent(FlexAlign.End)
  .backgroundColor(params?.backgroundColor ?? Color.White)
  .expandSafeArea([SafeAreaType.KEYBOARD])
  .zIndex(1)
}
