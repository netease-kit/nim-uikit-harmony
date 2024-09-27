/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * 确认弹框
 */
@CustomDialog
export struct CommonConfirmDialog {
  //确认内容
  @State confirmContent: string | Resource = ''
  @State showCancelButton: boolean = true
  //取消按钮
  cancel?: () => void
  //确认按钮
  confirm?: () => void
  controller?: CustomDialogController

  build() {
    Column() {
      Text(this.confirmContent)
        .fontSize(20)
        .fontColor('#ff333333')
        .margin({ top: 40, bottom: 50 })
      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        if (this.showCancelButton) {
          Button($r('app.string.cancel'))
            .onClick(() => {
              this.controller?.close()
              if (this.cancel) {
                this.cancel()
              }
            })
            .backgroundColor(0xffffff)
            .fontColor('#ff666666')
        }

        Button($r('app.string.common_sure'))
          .onClick(() => {
            this.controller?.close()
            if (this.confirm) {
              this.confirm()
            }
          }).backgroundColor(0xffffff).fontColor('#ff007AFF')
      }.margin({ bottom: 10 })
    }
  }
}