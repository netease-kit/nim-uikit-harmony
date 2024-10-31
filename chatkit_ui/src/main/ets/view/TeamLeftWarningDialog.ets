/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * 群无效弹框
 */
@CustomDialog
export struct TeamLeftWarningDialog {
  controller?: CustomDialogController
  confirm?: () => void

  build() {
    Column() {

      Text($r('app.string.chat_team_error_tip_title'))
        .fontSize($r('app.float.chat_title_text_font_size'))
        .fontColor($r('app.color.color_chat_title'))
        .margin({ top: 20 })

      Text($r('app.string.chat_team_error_tip_content'))
        .fontSize($r('app.float.chat_subtitle_text_font_size'))
        .fontColor($r('app.color.color_chat_sub_title'))
        .margin({ top: 20, bottom: 20 })

      Line().height(1).width('100%').backgroundColor($r('app.color.chat_input_background'))

      Text($r('app.string.common_sure'))
        .fontSize($r('app.float.chat_title_text_font_size'))
        .fontColor('#ff1861DF')
        .onClick(() => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm()
          }
        })
    }
    .padding({
      top: 20,
      bottom: 5,
      left: 24,
      right: 24
    })

  }
}