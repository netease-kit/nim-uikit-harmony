import { NIMMessageInfo } from '../model/NIMMessageInfo'

/// 文本消息详情展示页
@CustomDialog
export struct TextMessageDetailDialog {
  controller: CustomDialogController
  pathStack: NavPathStack = new NavPathStack()
  @BuilderParam message?: NIMMessageInfo

  build() {
    Column() {
      Scroll() {
        Text(this.message?.message.text)
          .width('100%')
          .textAlign(TextAlign.Center)
          .copyOption(CopyOptions.LocalDevice)
          .padding({
            left: 20,
            right: 20
          })
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')
      .height('100%')
      .margin({
        top: 56,
        bottom: 30
      })
      .alignSelf(ItemAlign.Center)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .onClick(() => {
      this.controller.close()
    })
  }
}