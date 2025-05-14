/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { V2NIMConversationType, V2NIMMessageSendingState, V2NIMMessageType } from '@nimsdk/base';
import { ChatInfo } from '../model/ChatInfo';
import { getNotificationMessageContent, getPinMessagesTips } from '../common/MessageHelper';
import { AvatarColorUntil, AvatarItem, CommonAvatar } from '@nimkit/common';
import { messageContent } from './MessageComponentBuilder';
import { MessageItemClick } from './MessageItemClick';
import { ChatKitConfig } from '../ChatKitConfig';

/**
 * 消息组件按照UI样式，划分为发送消息组件、接收消息组件、通知消息组件和提示消息组件
 */
@ComponentV2
export struct MessageComponent {
  @Require
  @Param
  message: NIMMessageInfo | undefined = undefined;
  @Require
  @Param
  chatInfo: ChatInfo
  @Param
  onMessageClick: MessageItemClick | undefined = undefined
  @Param
  onMoreButtonClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void = undefined
  @Param
  onPinItemClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void = undefined
  @Param
  showSelect: boolean = false;

  build() {
    if (this.message?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION) {
      NotificationMessageComponent({
        message: this.message,
        messageContent: getNotificationMessageContent(this.message, this.chatInfo)
      });
    } else if (this.message?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TIPS) {
      TipsMessageComponent({ message: this.message });
    } else if (this.message?.isReceiveMessage()) {
      ReceiveMessageComponent({
        message: this.message,
        chatUserInfo: this.chatInfo,
        onMessageClick: this.onMessageClick,
        showRadio: this.showSelect,
      });
    } else {
      SenderMessageComponent({
        message: this.message,
        chatUserInfo: this.chatInfo,
        onMessageClick: this.onMessageClick,
        showRadio: this.showSelect,
      });
    }
  }
}

// 发送消息组件
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
  message: NIMMessageInfo | undefined = undefined
  @Require
  @Param
  chatUserInfo: ChatInfo | undefined = undefined
  @Param
  onMessageClick: MessageItemClick | undefined = undefined
  @Param
  showRadio: boolean = false
  @Local
  radioOn: boolean = false

  build() {
    Column() {
      if (this.message !== undefined) {
        if (this.message?.getMessageTime() !== '') {
          Row() {
            Text(this.message?.getMessageTime()).fontColor($r('app.color.color_chat_desc'))
              .fontSize($r('app.float.chat_desc_text_font_size'))
          }.justifyContent(FlexAlign.Center).width('100%').height(20)
        }
        Row() {
          if (this.showRadio) {
            if (this.message.isRevokeMsg) {
              Text().margin({ top: (this.message?.getMessageHeight(this.getUIContext()) - 20) / 2, left: 16 })
                .height('20')
                .width('20')
            } else {
              Toggle({ type: ToggleType.Checkbox, isOn: this.message.isSelectedMsg })
                .margin({ top: (this.message?.getMessageHeight(this.getUIContext()) - 20) / 2, left: 16 })
                .height('20')
                .width('20')
                .onChange((value: boolean) => {
                  this.onMessageClick?.onMultiSelect?.(value, this.message)
                  this.radioOn = value;
                })
            }
          }
          Column() {
            Row() {
              if (this.message.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED) {
                Image($r("app.media.ic_chat_message_status_fail")).width(16).height(16)
                  .alignRules({
                    bottom: { anchor: "msgContainer", align: VerticalAlign.Bottom },
                    right: { anchor: "msgContainer", align: HorizontalAlign.Start }
                  }).margin({ right: 6 })
                  .onClick((event: ClickEvent) => {
                    if (this.onMessageClick) {
                      this.onMessageClick?.onSendFailClick?.(event, this.message)
                    }
                  })
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
              } else if (this.message.message.sendingState ===
              V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED && ChatKitConfig.messageReadState
                && this.message.configReadReceipt()) {
                if (!this.message.isRevokeMsg) {
                  if (this.message.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
                    if (this.message.readCount >= 0) {
                      Image(this.message.readCount == 0 ? $r('app.media.ic_chat_read_status_unread') :
                      $r('app.media.ic_chat_read_status_read'))
                        .width(16)
                        .height(16)
                        .alignRules({
                          bottom: { anchor: "msgContainer", align: VerticalAlign.Bottom },
                          right: { anchor: "msgContainer", align: HorizontalAlign.Start }
                        })
                        .margin({ right: 6 })
                    }

                  } else {
                    if (this.message.readCount !== -1) {
                      if (this.message.unReadCount == 0) {
                        Image(this.message.readCount == 0 ? $r('app.media.ic_chat_read_status_unread') :
                        $r('app.media.ic_chat_read_status_read')).width(16).height(16)
                          .alignRules({
                            bottom: { anchor: "msgContainer", align: VerticalAlign.Bottom },
                            right: { anchor: "msgContainer", align: HorizontalAlign.Start }
                          }).margin({ right: 6 })
                      } else {
                        Stack({}) {
                          Circle({ width: 15, height: 15 }).fill($r('app.color.color_chat_send'))
                          Progress({
                            value: this.message.readCount,
                            total: (this.message.readCount + this.message.unReadCount),
                            type: ProgressType.Eclipse
                          })
                            .width(13.8)
                            .height(13.8)
                            .color($r('app.color.color_chat_send'))
                            .backgroundColor($r('app.color.color_chat_page_bg'))
                            .style({
                              strokeWidth: 1
                            })
                            .onClick((event: ClickEvent) => {
                              this.onMessageClick?.onReadReceiptClick?.(event, this.message)
                            })
                        }
                        .alignRules({
                          bottom: { anchor: "msgContainer", align: VerticalAlign.Bottom },
                          right: { anchor: "msgContainer", align: HorizontalAlign.Start }
                        })
                        .margin({ right: 6 })
                        .onClick((event: ClickEvent) => {
                          this.onMessageClick?.onReadReceiptClick?.(event, this.message)
                        })
                      }
                    }
                  }
                }
              }
              messageContent({
                message: this.message,
                onMessageClick: this.onMessageClick,
                chatInfo: this.chatUserInfo
              })
                .backgroundColor($r('app.color.color_chat_send_message_bg'))
                .borderRadius(6)
                .onClick((event: ClickEvent) => {
                  if (this.showRadio) {
                    this.radioOn = !this.radioOn
                  }
                  this.onMessageClick?.onItemClick?.(event, this.message)
                })
                .margin({ top: 4, right: 6 })
                .flexShrink(1)
                .id("msgContainer")
            }
            .justifyContent(FlexAlign.End)
            .alignItems(VerticalAlign.Bottom)
            .margin({ right: 8 })
            .width('100%')
            //.height(this.message.getMessageHeight(this.getUIContext()))
            .gesture(LongPressGesture()
              .onAction((event: GestureEvent) => {
                this.onMessageClick?.onItemLongClick?.(event, this.message)
              }))

            if (this.message?.isPinMsg) {
              Row() {
                Image($r('app.media.ic_chat_message_pin')).height(12).width(12).margin({ top: 6 })
                Text(getPinMessagesTips(this.message, this.chatUserInfo))
                  .fontSize(12)
                  .fontColor($r('app.color.color_chat_pin_tips'))
                  .margin({ top: 6, left: 6 })
                  .maxLines(1)
                  .ellipsisMode(EllipsisMode.END)
              }.width('100%').height('26vp').margin({ bottom: 6, right: 12 }).justifyContent(FlexAlign.End)
            }
          }.alignItems(HorizontalAlign.End).margin({ left: 8 }).width('75%')

          CommonAvatar({
            item: new AvatarItem(this.chatUserInfo != null ?
            this.chatUserInfo?.getCurrentUserAvatarUrl() : '',
              this.chatUserInfo?.getCurrentUserAvatarName() ?? '',
              AvatarColorUntil.getBackgroundColorById(this.message.message.senderId),
            ),
            longPressGesture: () => {
              this.onMessageClick?.onAvatarLongPress?.( this.message)
            }
          })
            .width(36)
            .height(36)
            .borderRadius(20)
            .margin({ right: 16, top: 6 })
            .id("mineAvatar")
            .onClick(() => {
              this.onMessageClick?.onAvatarClick?.(this.message)
            })
        }
        .width('100%')
        .backgroundColor(this.message.isPinMsg ? $r('app.color.color_chat_pin_bg') :
        $r('app.color.color_chat_page_bg'))
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%').margin({ top: 6, bottom: 6 })
  }
}

// 接收消息组件
@ComponentV2
export struct ReceiveMessageComponent {
  AlignLeft: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
    'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
  }
  @Require
  @Param
  message: NIMMessageInfo | undefined = undefined
  @Require
  @Param
  chatUserInfo: ChatInfo | undefined = undefined
  @Param
  showRadio: boolean = false
  @Param
  onMessageClick: MessageItemClick | undefined = undefined
  @Local
  radioOn: boolean = false

  build() {
    Column() {
      if (this.message !== undefined) {
        if (this.message?.getMessageTime() !== '') {
          Row() {
            Text(this.message?.getMessageTime())
              .fontColor($r('app.color.color_chat_desc'))
              .fontSize($r('app.float.chat_desc_text_font_size'))
          }.justifyContent(FlexAlign.Center).width('100%').height(20)
          .margin({ top: 6 })
        }
        Row() {
          if (this.showRadio) {
            if (this.message.isRevokeMsg) {
              Text().margin({ top: (this.message?.getMessageHeight(this.getUIContext()) - 20) / 2, left: 16 })
                .height('20')
                .width('20')
            } else {
              Toggle({ type: ToggleType.Checkbox, isOn: this.message.isSelectedMsg })
                .margin({ top: (this.message?.getMessageHeight(this.getUIContext()) - 20) / 2, left: 16 })
                .height('20')
                .width('20')
                .onChange((value: boolean) => {
                  this.onMessageClick?.onMultiSelect?.(value, this.message)
                  // this.radioOn = value;
                })
            }
          }
          CommonAvatar({
            item: new AvatarItem(this.chatUserInfo != null ?
              this.chatUserInfo?.getChatUserAvatarUrl(this.message?.message) : '',
              this.chatUserInfo?.getChatUserAvatarName(this.message?.message) ?? '',
              AvatarColorUntil.getBackgroundColorById(this.message?.message.senderId ?? '')
            ),
            longPressGesture: () => {
              this.onMessageClick?.onAvatarLongPress?.( this.message)
            }
          })
            .width(36)
            .height(36)
            .borderRadius(20)
            .margin({ left: 16, top: 6 })
            .id("otherAvatar")
            .onClick(() => {
              this.onMessageClick?.onAvatarClick?.(this.message)
            })
          Column() {
            if (this.message?.message.conversationType !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
              Text(this.chatUserInfo?.getChatUserShowName(this.message?.message))
                .fontColor($r('app.color.color_chat_sub_title'))
                .fontSize($r('app.float.chat_subtitle_text_font_size'))
                .maxLines(1)
                .width(150)
                .textAlign(TextAlign.Start)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .ellipsisMode(EllipsisMode.END)
                .height(25)
            }

            Column() {
              messageContent({
                message: this.message,
                onMessageClick: this.onMessageClick,
                chatInfo: this.chatUserInfo
              })
                .backgroundColor($r('app.color.color_chat_receive_message_bg'))
                .borderRadius(6)
                .id("msgContainer")
                .alignRules(this.AlignLeft)
                .onClick((event: ClickEvent) => {
                  if (this.showRadio) {
                    this.radioOn = !this.radioOn
                  }
                  this.onMessageClick?.onItemClick?.(event, this.message)
                })
            }
            .width('100%')
            //.height(this.message?.getMessageHeight(this.getUIContext()))
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .gesture(LongPressGesture().onAction((event: GestureEvent) => {
              this.onMessageClick?.onItemLongClick?.(event, this.message)
            }))

            if (this.message?.isPinMsg) {
              Row() {
                Image($r('app.media.ic_chat_message_pin')).height(12).width(12).margin({ top: 6 })
                Text(getPinMessagesTips(this.message, this.chatUserInfo))
                  .fontSize(12)
                  .fontColor($r('app.color.color_chat_pin_tips'))
                  .margin({ top: 6, left: 6 })
                  .maxLines(1)
                  .ellipsisMode(EllipsisMode.CENTER)
              }.width('100%').height('26vp')
            }
          }.alignItems(HorizontalAlign.Start).margin({ left: 8, top: 6 }).width('68%')
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .backgroundColor(this.message?.isPinMsg ? $r('app.color.color_chat_pin_bg') :
        $r('app.color.color_chat_page_bg'))
        .id('itemContainer')
      }
    }.width('100%').padding({ top: 6, bottom: 6 })
  }
}

// 通知消息组件
@ComponentV2
export struct NotificationMessageComponent {
  @Require
  @Param
  message: NIMMessageInfo | null = null;
  @Require
  @Param
  messageContent: string;

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
          Text(this.messageContent ?? $r('app.string.chat_message_empty_notification_text'))
            .fontColor($r('app.color.color_chat_sub_title'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
            .padding({
              left: 6,
              top: 6,
              bottom: 6,
              right: 6
            })
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .ellipsisMode(EllipsisMode.END)
        }
        .width('100%')
        // .height(this.message?.getMessageHeight(this.getUIContext()))
        .padding({ top: 6, bottom: 6 })
        .justifyContent(FlexAlign.Center)
        .borderRadius(6)
        .id("msgContainer")
      }
    }.margin({ left: 60, right: 60 })
  }
}

// 提示消息组件
@ComponentV2
export struct TipsMessageComponent {
  @Require
  @Param
  message: NIMMessageInfo | null = null;

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
          Text(this.message?.message.text ?? $r('app.string.chat_message_empty_tip_text'))
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
        // .height(this.message?.getMessageHeight(this.getUIContext()))
        .padding({ top: 6, bottom: 6 })
        .margin({ left: 60, right: 60, top: 6 })
        .justifyContent(FlexAlign.Center)
        .borderRadius(6)
        .id("msgContainer")
      }
    }
  }
}

/**
 * 合并转发详情页中的消息组件
 */
@ComponentV2
export struct MergeDetailMessageComponent {
  AlignLeft: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
    'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
  }
  @Require
  @Param
  message: NIMMessageInfo | undefined = undefined
  @Require
  @Param
  chatUserInfo: ChatInfo | undefined = undefined
  @Param
  onMessageClick: MessageItemClick | undefined = undefined

  build() {
    Column() {
      if (this.message !== undefined) {
        if (this.message?.getMessageTime() !== '') {
          Row() {
            Text(this.message?.getMessageTime())
              .fontColor($r('app.color.color_chat_desc'))
              .fontSize($r('app.float.chat_desc_text_font_size'))
          }.justifyContent(FlexAlign.Center).width('100%').height(20)
          .margin({ top: 4 })
        }
        Row() {
          CommonAvatar({
            item: new AvatarItem(this.chatUserInfo != null ?
            this.chatUserInfo?.getChatUserAvatarUrl(this.message?.message) : '',
              this.chatUserInfo?.getChatUserAvatarName(this.message?.message) ?? '',
              AvatarColorUntil.getBackgroundColorById(this.message?.message.senderId ?? '')),
            longPressGesture: () => {
              this.onMessageClick?.onAvatarLongPress?.( this.message)
            }
          })
            .width(36)
            .height(36)
            .borderRadius(20)
            .margin({ left: 16, top: 3 })
            .id("otherAvatar")
            .onClick(() => {
              this.onMessageClick?.onAvatarClick?.(this.message)
            })

          Column() {
            Text(this.chatUserInfo?.getChatUserShowName(this.message?.message))
              .fontColor($r('app.color.color_chat_sub_title'))
              .fontSize($r('app.float.chat_subtitle_text_font_size'))
              .maxLines(1)
              .width(150)
              .textAlign(TextAlign.Start)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .ellipsisMode(EllipsisMode.END)
            Column() {
              messageContent({ message: this.message, onMessageClick: this.onMessageClick })
                .backgroundColor($r('app.color.color_chat_receive_message_bg'))
                .borderRadius(6)
                .id("msgContainer")
                .alignRules(this.AlignLeft)
                .onClick((event: ClickEvent) => {
                  this.onMessageClick?.onItemClick?.(event, this.message)
                })
            } .height(this.message?.getMessageHeight(this.getUIContext()))
            .margin({ top: 6 })
          }.alignItems(HorizontalAlign.Start).margin({ left: 8 }).width('68%')
          .gesture(LongPressGesture().onAction((event: GestureEvent) => {
            this.onMessageClick?.onItemLongClick?.(event, this.message)
          }))

        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .backgroundColor(this.message?.isPinMsg ? $r('app.color.color_chat_pin_bg') :
        $r('app.color.color_chat_page_bg'))
        .id('itemContainer')
      }
    }.width('100%').padding({ top: 3})
  }
}