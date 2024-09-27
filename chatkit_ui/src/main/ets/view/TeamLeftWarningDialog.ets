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

      Text($r('app.string.chat_team_error_tip_content'))
        .fontSize(16)
        .fontColor('#ff333333')

      Blank().height(50)

      Text($r('app.string.common_sure'))
        .fontSize(16)
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
      left: 12,
      right: 12
    })

  }
}