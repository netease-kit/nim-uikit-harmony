/// 两个按钮的提示弹框
/// 【取消】|【确定】
@CustomDialog
export struct DoubleAlertDialog {
  pathStack: NavPathStack = new NavPathStack()
  controller?: CustomDialogController
  title: ResourceStr = ""
  message?: ResourceStr
  sureText: ResourceStr = $r('app.string.common_sure')
  cancelText: ResourceStr = $r('app.string.cancel')
  sureTextColor: ResourceColor = "#007AFF"
  cancelTextColor: ResourceColor = "#666666"
  sureAction?: () => void
  cancelAction?: () => void

  build() {
    Column() {
      Text(this.title)
        .fontSize(17)
        .margin({ top: 19 })
        .height(22)

      Text(this.message)
        .fontSize(13)
        .fontColor("#333333")
        .height(35)
        .margin({ top: 10 })

      Row()
        .height(1)
        .width('100%')
        .backgroundColor("#EFF1F4")
        .margin({ top: 10 })

      Row() {
        Button(this.cancelText, { type: ButtonType.Normal })
          .fontSize(17)
          .fontColor(this.cancelTextColor)
          .backgroundColor(Color.White)
          .width(135)
          .height(44)
          .onClick(() => {
            this.cancelAction?.()
            this.controller?.close()
          })

        Column()
          .width(1)
          .height('100%')
          .backgroundColor("#EFF1F4")

        Button(this.sureText, { type: ButtonType.Normal })
          .fontSize(17)
          .fontColor(this.sureTextColor)
          .backgroundColor(Color.White)
          .width(135)
          .height(44)
          .onClick(() => {
            this.sureAction?.()
            this.controller?.close()
          })
      }
      .height(44)
      .width(270)
      .alignItems(VerticalAlign.Center)
    }
    .height(140)
    .width(270)
    .backgroundColor(Color.White)
  }
}