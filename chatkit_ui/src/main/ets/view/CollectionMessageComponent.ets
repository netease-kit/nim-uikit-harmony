import { DateUtils } from '../common/DateUtils';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { pinMessageContent } from '../view/MessageComponentBuilder';
import { MessageItemClick } from '../view/MessageItemClick';
import { AvatarColorUntil, AvatarItem, CommonAvatar, TailString } from '@nimkit/common';
import { V2NIMConversationType, V2NIMMessageType } from '@nimsdk/base';
import { CollectionMessageModel } from '../model/CollectionMessageModel';

@ComponentV2
export struct CollectionMessageComponent {
  AlignLeft: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
    'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
  }
  @Require
  @Param
  private collection?: CollectionMessageModel
  @Param
  private onMessageClick?: MessageItemClick = undefined
  @Param
  private onMoreButtonClick?: (event: ClickEvent, msg?: NIMMessageInfo) => void = undefined

  build() {
    Column() {
      if (this.collection) {
        Row() {
          CommonAvatar({
            item: new AvatarItem(this.collection.avatar,
              TailString(this.collection.senderName),
              AvatarColorUntil.getBackgroundColorById(this.collection.message?.message.senderId ?? ''))
          })
            .width(36)
            .height(36)
            .borderRadius(20)
            .margin({ left: 16, top: 16 })
            .id("otherAvatar")

          Column() {
            Text(this.collection.senderName)
              .fontColor($r('app.color.color_chat_sub_title'))
              .fontSize($r('app.float.chat_subtitle_text_font_size'))
              .maxLines(1)
              .textAlign(TextAlign.Start)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .ellipsisMode(EllipsisMode.END)

            Text(this.collection.message?.getConversationType() === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P ?
            $r("app.string.mine_collection_from_p2p", this.collection.conversationName) :
            $r("app.string.mine_collection_from_team", this.collection.conversationName))
              .fontColor($r('app.color.color_chat_desc'))
              .fontSize($r('app.float.chat_desc_text_font_size'))
              .margin({ top: 3 })
              .maxLines(1)
              .textAlign(TextAlign.Start)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .ellipsisMode(this.collection.message?.getConversationType() ===
              V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P ? EllipsisMode.CENTER : EllipsisMode.END)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 10, top: 16 })

          Image($r('app.media.ic_public_more_dot'))
            .width(32)
            .height(32)
            .padding({
              left: 3,
              right: 3,
              top: 3,
              bottom: 3
            })
            .margin({ top: 16, right: 16 })
            .onClick((event: ClickEvent) => {
              this.onMoreButtonClick?.(event, this.collection?.message)
            })
        }
        .alignSelf(ItemAlign.Start)

        Column() {
          pinMessageContent({ message: this.collection.message, onMessageClick: this.onMessageClick })
            .backgroundColor(this.collection.message?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT ?
            Color.Transparent : $r('app.color.color_chat_receive_message_bg'))
            .borderRadius(6)
            .id("msgContainer")
            .alignRules(this.AlignLeft)
            .gesture(LongPressGesture().onAction((event: GestureEvent) => {
              this.onMessageClick?.onItemLongClick?.(event, this.collection?.message)
            }))
            .onClick((event: ClickEvent) => {
              this.onMessageClick?.onItemClick?.(event, this.collection?.message)
            })
        }
        .alignItems(HorizontalAlign.Start)
        .alignSelf(ItemAlign.Start)
        .margin({
          left: 16,
          right: 16,
          top: 12,
          bottom: 16
        })

        Blank()
          .height(1)
          .backgroundColor('#E4E9F2')
          .margin({
            left: 16,
            right: 16
          })

        if (this.collection.collection?.updateTime) {
          Text(DateUtils.formatTime(this.collection.collection.updateTime))
            .fontColor($r('app.color.color_chat_desc'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
            .maxLines(1)
            .textAlign(TextAlign.Start)
            .alignSelf(ItemAlign.Start)
            .height(18)
            .margin({
              left: 16,
              right: 16,
              top: 10,
              bottom: 10
            })
        }
      }
    }
    .margin({
      left: 20,
      right: 20
    })
    .backgroundColor(Color.White)
    .borderRadius(8)
  }
}