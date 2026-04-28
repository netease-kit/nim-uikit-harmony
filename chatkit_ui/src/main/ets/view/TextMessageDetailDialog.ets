import { parseMessageText } from '../common/MessageHelper'
import { NEEmojiParseResult } from '../manager/NEEmojiManager'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { parseTextWithLinks, TextNode, TextNodeType, LinkInfo } from '../utils/TextNodeParser'
import { LinkClickUtils } from '../utils/LinkClickUtils'
import { common } from '@kit.AbilityKit'
import { getMultiLineBody, getMultiLineTitle, isMultiLineMessage } from '@nimkit/chatkit'

@CustomDialog
export struct TextMessageDetailDialog {
  controller: CustomDialogController
  @BuilderParam message: NIMMessageInfo | undefined
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  private onLinkClick(linkInfo: LinkInfo) {
    LinkClickUtils.handleLinkClick(this.context, linkInfo)
  }

  private isCurrentMultiLineMessage(): boolean {
    return this.message ? isMultiLineMessage(this.message.message) : false
  }

  private getCurrentMultiLineTitle(): string {
    if (!this.message || !this.isCurrentMultiLineMessage()) {
      return ''
    }
    return getMultiLineTitle(this.message.message)
  }

  private getCurrentMultiLineBody(): string {
    if (!this.message || !this.isCurrentMultiLineMessage()) {
      return ''
    }
    return getMultiLineBody(this.message.message)
  }

  @Builder
  private LinkableText(content: string, fontColor: ResourceColor, textAlign: TextAlign = TextAlign.Center,
    topMargin: number = 0, isBold: boolean = false) {
    Text() {
      ForEach(parseMessageText(content), (item: NEEmojiParseResult) => {
        if (item.text) {
          ForEach(parseTextWithLinks(item.text), (textNode: TextNode) => {
            if (textNode.type === TextNodeType.LINK && textNode.linkInfo) {
              Span(textNode.text)
                .fontSize($r('app.float.chat_message_text_font_size'))
                .textCase(TextCase.Normal)
                .fontColor('#337EFF')
                .onClick(() => {
                  if (textNode.linkInfo) {
                    this.onLinkClick(textNode.linkInfo)
                  }
                })
            } else {
              Span(textNode.text)
                .fontSize($r('app.float.chat_message_text_font_size'))
                .textCase(TextCase.Normal)
                .fontColor(fontColor)
                .fontWeight(isBold ? FontWeight.Bold : FontWeight.Normal)
            }
          })
        } else if (item.emoji) {
          ImageSpan($rawfile(`emoji/${item.emoji.file}`))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Fill)
            .verticalAlign(ImageSpanAlignment.CENTER)
        }
      })
    }
    .width('100%')
    .textAlign(textAlign)
    .copyOption(CopyOptions.LocalDevice)
    .margin({ top: topMargin })
  }

  build() {
    if (!this.message) {
      Column() {}
    } else {
      Column() {
        Scroll() {
          Column() {
            if (this.isCurrentMultiLineMessage()) {
              if (this.getCurrentMultiLineTitle().length > 0) {
                this.LinkableText(this.getCurrentMultiLineTitle(), $r('app.color.color_chat_title'),
                  TextAlign.Start, 0, true)
              }
              if (this.getCurrentMultiLineBody().length > 0) {
                this.LinkableText(this.getCurrentMultiLineBody(), $r('app.color.color_chat_title'),
                  TextAlign.Start, this.getCurrentMultiLineTitle().length > 0 ? 8 : 0, false)
              }
            } else {
              this.LinkableText(this.message.message.text ?? '', $r('app.color.color_chat_title'))
            }
          }
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 8, bottom: 8 })
        }
        .width('100%')
        .height('100%')
        .margin({ top: 56, bottom: 30 })
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
}
