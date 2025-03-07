/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatInfo } from '../model/ChatInfo';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { AvatarColorUntil, AvatarItem, CommonAvatar } from '@nimkit/common';
import { pinMessageContent } from './MessageComponentBuilder';
import { V2NIMMessageType } from '@nimsdk/base';
import { MessageItemClick } from './MessageItemClick';

/**
 * 标记页面中的消息组件
 */
@ComponentV2
export struct PinMessageComponent {
  AlignLeft: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
    'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
  }
  @Require
  @Param
  message?: NIMMessageInfo = undefined;
  @Require
  @Param
  chatUserInfo?: ChatInfo = undefined;
  @Param
  onMessageClick?: MessageItemClick = undefined
  @Param
  onMoreButtonClick?: (event: ClickEvent, msg?: NIMMessageInfo) => void = undefined
  @Param
  onPinItemClick?: (event: ClickEvent, msg?: NIMMessageInfo) => void = undefined

  build() {
    Column() {
      if (this.message) {
        Row() {
          CommonAvatar({
            item: new AvatarItem(this.chatUserInfo?.getChatUserAvatarUrl(this.message?.message.senderId ?? '') ?? '',
              this.chatUserInfo?.getChatUserAvatarName(this.message?.message.senderId ?? '') ?? '',
              AvatarColorUntil.getBackgroundColorById(this.message?.message.senderId ?? '')),
            longPressGesture: () => {
              this.onMessageClick?.onAvatarLongPress?.( this.message)
            }
          })
            .width(36)
            .height(36)
            .borderRadius(20)
            .margin({ left: 16, top: 16 })
            .id("otherAvatar")
            .onClick(() => {
              this.onMessageClick?.onAvatarClick?.(this.message)
            })
          Column() {
            Text(this.chatUserInfo?.getChatUserShowName(this.message?.message.senderId ?? ''))
              .fontColor($r('app.color.color_chat_sub_title'))
              .fontSize($r('app.float.chat_subtitle_text_font_size'))
              .maxLines(1)
              .width(150)
              .textAlign(TextAlign.Start)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .ellipsisMode(EllipsisMode.END)

            Text(this.message?.getMessageFormatTime())
              .fontColor($r('app.color.color_chat_desc'))
              .fontSize($r('app.float.chat_desc_text_font_size'))
              .margin({ top: 3 })
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
              this.onMoreButtonClick?.(event, this.message)
            })
        }
        .alignSelf(ItemAlign.Start)

        Blank()
          .height(1)
          .backgroundColor('#E4E9F2')
          .margin({
            left: 16,
            right: 16,
            top: 12
          })

        Column() {
          pinMessageContent({ message: this.message, onMessageClick: this.onMessageClick })
            .backgroundColor(this.message?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT ?
            Color.Transparent : $r('app.color.color_chat_receive_message_bg'))
            .borderRadius(6)
            .id("msgContainer")
            .alignRules(this.AlignLeft)
            .onClick((event: ClickEvent) => {
              this.onMessageClick?.onItemClick?.(event, this.message)
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
        .gesture(LongPressGesture().onAction((event: GestureEvent) => {
          this.onMessageClick?.onItemLongClick?.(event, this.message)
        }))
      }
    }
    .margin({
      left: 20,
      right: 20
    })
    .backgroundColor(Color.White)
    .borderRadius(8)
    .onClick((event: ClickEvent) => {
      this.onPinItemClick?.(event, this.message)
    })
  }
}