import { parseMessageText } from '../common/MessageHelper'
import { NEEmojiParseResult } from '../manager/NEEmojiManager'
import { NIMMessageInfo } from '../model/NIMMessageInfo'

/// 文本消息详情展示页
@CustomDialog
export struct TextMessageDetailDialog {
  controller: CustomDialogController
  pathStack: NavPathStack = new NavPathStack()
  @BuilderParam message: NIMMessageInfo | undefined

  build() {
    if (this.message) {
      Column() {
        Scroll() {
          Text() {
            ForEach(parseMessageText(this.message.message.text), (item: NEEmojiParseResult) => {
              if (item.text) {
                Span(item.text)
                  .fontSize($r('app.float.chat_message_text_font_size'))
                  .textCase(TextCase.Normal)
                  .fontColor($r('app.color.color_chat_title'))
              } else if (item.emoji) {
                ImageSpan($rawfile(`emoji/${item.emoji.file}`)).width('18')
                  .height('18')
                  .objectFit(ImageFit.Fill)
                  .verticalAlign(ImageSpanAlignment.CENTER)
              }
            })
          }
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
        this.controller?.close()
      })
    }
  }
}