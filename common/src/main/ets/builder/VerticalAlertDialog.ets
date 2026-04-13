/// 上下按钮排列的提示弹框
/// 【按钮1】
/// 【按钮2】
@CustomDialog
export struct VerticalAlertDialog {
  controller?: CustomDialogController
  title: ResourceStr = ''
  message?: ResourceStr
  firstButtonText: ResourceStr = ''
  secondButtonText: ResourceStr = ''
  firstButtonColor: ResourceColor = '#337EFF'
  secondButtonColor: ResourceColor = '#337EFF'
  firstAction?: () => void
  secondAction?: () => void

  build() {
    Column() {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .margin({ top: 20 })
        .padding({ left: 20, right: 20 })

      if (this.message) {
        Text(this.message)
          .fontSize(13)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
          .margin({ top: 8, bottom: 4 })
          .padding({ left: 20, right: 20 })
      }

      // 分割线
      Row()
        .height(0.5)
        .width('100%')
        .backgroundColor('#EFF1F4')
        .margin({ top: 16 })

      // 第一个按钮
      Button(this.firstButtonText, { type: ButtonType.Normal })
        .fontSize(17)
        .fontColor(this.firstButtonColor)
        .backgroundColor(Color.White)
        .width('100%')
        .height(48)
        .onClick(() => {
          this.firstAction?.()
          this.controller?.close()
        })

      // 分割线
      Row()
        .height(0.5)
        .width('100%')
        .backgroundColor('#EFF1F4')

      // 第二个按钮（底部圆角与外层 Column 一致）
      Button(this.secondButtonText, { type: ButtonType.Normal })
        .fontSize(17)
        .fontColor(this.secondButtonColor)
        .backgroundColor(Color.White)
        .width('100%')
        .height(48)
        .borderRadius({ bottomLeft: 14, bottomRight: 14 })
        .onClick(() => {
          this.secondAction?.()
          this.controller?.close()
        })
    }
    .width(270)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .clip(true)
  }
}