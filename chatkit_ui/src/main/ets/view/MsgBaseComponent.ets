/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMMessageSendingState } from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { AvatarColorUntil, AvatarItem, CommonAvatar } from '@nimkit/common';
import { ChatInfo } from '../model/ChatInfo';
import { getMessageHeight, measureTextHeight } from '../common/MessageHelper';
import { V2NIMConversationType } from '@nimsdk/base';
import { messageContent } from './MessageContentComponent';

@ComponentV2
export struct SenderMessageComponent {
  AlignLeft: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
    'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
  }
  AlignRight: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
    'right': { 'anchor': '__container__', 'align': HorizontalAlign.End }
  }
  @Require
  @Param
  private message: NIMMessageInfo | undefined = undefined;
  @Require
  @Param
  private chatUserInfo: ChatInfo | undefined = undefined;
  @Require
  @Param
  private onItemClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined,) => void
  @Require
  @Param
  private onItemLongClick?: (event: GestureEvent, msg: NIMMessageInfo | undefined) => void
  @Require
  @Param
  private onAvatarClick?: (msg: NIMMessageInfo | undefined) => void

  build() {
    Column() {
      if (this.message != null) {
        if (this.message?.getMessageTime() !== '') {
          Row() {
            Text(this.message?.getMessageTime()).fontColor($r('app.color.color_chat_desc'))
              .fontSize($r('app.float.chat_desc_text_font_size'))
          }.justifyContent(FlexAlign.Center).width('100%').height(20)
        }
        RelativeContainer() {
          Row() {
            CommonAvatar({
              item: new AvatarItem(this.chatUserInfo != null ?
              this.chatUserInfo?.getCurrentUserAvatarUrl() : '',
                this.chatUserInfo?.getCurrentUserAvatarName() ?? '',
                AvatarColorUntil.getBackgroundColorById(this.message.message.senderId),
              )
            }).width(36)
              .height(36)
              .borderRadius(20)
          }
          .justifyContent(FlexAlign.Center)
          .width(32)
          .height(32)
          .borderRadius(16)
          .margin({ right: 16, top: 6 })
          .alignRules(this.AlignRight)
          .id("mineAvatar")
          .onClick((event: ClickEvent) => {
            this.onAvatarClick?.(this.message)
          })

          //NodeContainer(new MessageNodeController(true, this.message))
          messageContent({ message: this.message, onItemLongClick: this.onItemLongClick })
            .backgroundColor($r('app.color.color_chat_send_message_bg'))
            .borderRadius(6)
            .id("msgContainer")
            .gesture(LongPressGesture().onAction((event: GestureEvent) => {
              this.onItemLongClick?.(event, this.message)
            }))
            .onClick((event: ClickEvent) => {
              this.onItemClick?.(event, this.message)
            })
            .flexShrink(1)
            .margin({ left: 60, right: 60, top: 6 })
            .alignRules(this.AlignRight)
          if (this.message.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED) {
            Image($r('app.media.ic_chat_message_status')).width(16).height(16)
              .alignRules({
                bottom: { anchor: "msgContainer", align: VerticalAlign.Bottom },
                right: { anchor: "msgContainer", align: HorizontalAlign.Start }
              }).margin({ right: 6 })
          } else if (this.message.message.sendingState ===
          V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
            Progress({ value: 0, total: 100, type: ProgressType.Ring })
              .width(16)
              .height(16)
              .color($r('app.color.color_chat_send'))
              .style({ strokeWidth: 3, status: ProgressStatus.LOADING })
              .alignRules({
                bottom: { anchor: "msgContainer", align: VerticalAlign.Bottom },
                right: { anchor: "msgContainer", align: HorizontalAlign.Start }
              })
              .margin({ right: 6 })
          }
        }.width('100%').height(getMessageHeight(this.getUIContext(), this.message))
      }
    }.width('100%').padding({ top: 6, bottom: 6 })
  }
}


@ComponentV2
export struct ReceiveMessageComponent {
  AlignLeft: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
    'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
  }
  @Require
  @Param
  private message: NIMMessageInfo | undefined = undefined;
  @Require
  @Param
  private chatUserInfo: ChatInfo | undefined = undefined;
  @Require
  @Param
  private onItemClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined,) => void
  @Require
  @Param
  private onItemLongClick?: (event: GestureEvent, msg: NIMMessageInfo | undefined,) => void
  @Require
  @Param
  private onAvatarClick?: (msg: NIMMessageInfo | undefined) => void

  build() {
    Column() {
      if (this.message !== null) {
        if (this.message?.getMessageTime() !== '') {
          Row() {
            Text(this.message?.getMessageTime())
              .fontColor($r('app.color.color_chat_desc'))
              .fontSize($r('app.float.chat_desc_text_font_size'))
          }.justifyContent(FlexAlign.Center).width('100%').height(20)
          .margin({ top: 6 })
        }
        RelativeContainer() {
          CommonAvatar({
            item: new AvatarItem(this.chatUserInfo != null ?
            this.chatUserInfo?.getChatUserAvatarUrl(this.message?.message.senderId ?? '') : '',
              this.chatUserInfo?.getChatUserAvatarName(this.message?.message.senderId ?? '') ?? '',
              AvatarColorUntil.getBackgroundColorById(this.message?.message.senderId ?? ''))
          })
            .width(36)
            .height(36)
            .borderRadius(20)
            .margin({ left: 16, top: 6 })
            .id("otherAvatar")
            .onClick((event: ClickEvent) => {
              this.onAvatarClick?.(this.message)
            })
          Column() {
            if (this.message?.message.conversationType !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
              Text(this.chatUserInfo?.getChatUserShowName(this.message?.message.senderId ?? ''))
                .fontColor($r('app.color.color_chat_sub_title'))
                .fontSize($r('app.float.chat_subtitle_text_font_size'))
                .maxLines(1)
                .width(150)
                .textAlign(TextAlign.Start)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .ellipsisMode(EllipsisMode.END)

            }

            messageContent({ message: this.message, onItemLongClick: this.onItemLongClick })
              .backgroundColor($r('app.color.color_chat_receive_message_bg'))
              .borderRadius(6)
              .id("msgContainer")
              .margin({ top: 6 })
              .alignRules(this.AlignLeft)
              .gesture(LongPressGesture().onAction((event: GestureEvent) => {
                this.onItemLongClick?.(event, this.message)
              }))
              .onClick((event: ClickEvent) => {
                this.onItemClick?.(event, this.message)
              })
          }.alignItems(HorizontalAlign.Start).margin({ left: 60, right: 60, top: 6 })
        }.width('100%').height(getMessageHeight(this.getUIContext(), this.message))
      }
    }.width('100%').padding({ top: 6, bottom: 6 })
  }
}


@ComponentV2
export struct NotificationMessageComponent {
  @Require
  @Param
  message: NIMMessageInfo | null = null;
  @Require
  @Param
  private messageContent: string;

  build() {
    Column() {
      if (this.message !== null && this.messageContent !== '') {
        if (this.message?.getMessageTime() !== '') {
          Text(this.message?.getMessageTime())
            .fontColor($r('app.color.color_chat_desc'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(20)
        }
        Row() {
          Text(this.messageContent)
            .fontColor($r('app.color.color_chat_sub_title'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
            .padding({
              left: 6,
              top: 6,
              bottom: 6,
              right: 6
            })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .ellipsisMode(EllipsisMode.END)
        }
        .width('100%')
        .height(measureTextHeight(this.getUIContext(), this.messageContent, 2))
        .padding({ top: 6, bottom: 6 })
        .justifyContent(FlexAlign.Center)
        .borderRadius(6)
        .id("msgContainer")
      }
    }.margin({ left: 60, right: 60 })
  }
}


@ComponentV2
export struct TipsMessageComponent {
  @Require
  @Param
  private message: NIMMessageInfo | null = null;

  build() {
    Column() {
      if (this.message !== null && this.message.message.text !== undefined && this.message.message.text !== '') {
        if (this.message?.getMessageTime() !== '') {
          Row() {
            Text(this.message?.getMessageTime()).fontColor($r('app.color.color_chat_desc'))
              .fontSize($r('app.float.chat_desc_text_font_size'))
          }.justifyContent(FlexAlign.Center).width('100%').height(20)
        }
        Row() {
          Text(this.message?.message.text)
            .lineHeight(20)
            .padding({
              left: 6,
              top: 6,
              bottom: 6,
              right: 6
            })
            .fontColor($r('app.color.color_chat_sub_title'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
        }
        .width('100%')
        .height(getMessageHeight(this.getUIContext(), this.message))
        .padding({ top: 6, bottom: 6 })
        .margin({ left: 60, right: 60, top: 6 })
        .justifyContent(FlexAlign.Center)
        .borderRadius(6)
        .id("msgContainer")
      }
    }
  }
}



