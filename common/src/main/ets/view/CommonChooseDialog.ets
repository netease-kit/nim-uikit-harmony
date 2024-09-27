/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@CustomDialog
export struct CommonChooseDialog {
  controller?: CustomDialogController
  content1?: string | Resource
  content2?: string | Resource
  onItemChosen?: (index: number) => void
  cancel = () => {
    this.controller?.close()
  }

  build() {
    Column() {
      Column() {
        Text(this.content1)
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(() => {
            if (this.onItemChosen) {
              this.onItemChosen(1)
            }
            this.cancel()
          })

        Row()
          .height(1)
          .width('100%')
          .backgroundColor("#EFF1F4")

        Text(this.content2)
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(() => {
            if (this.onItemChosen) {
              this.onItemChosen(2)
            }
            this.cancel()
          })
      }
      .height(85)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 12, right: 12 })

      Column() {
        Text($r('app.string.mine_edit_cancel'))
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.cancel)
      }
      .height(42)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ top: 10, left: 12, right: 12 })

    }
    .backgroundColor(Color.Transparent)
  }
}
