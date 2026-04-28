/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { CommonAvatar, UserAvatarNameItem } from '@nimkit/common';
import { memberHistoryMessageContent } from './MessageComponentBuilder';
import { V2NIMMessageType } from '@nimsdk/base';
import { MessageItemClick } from './MessageItemClick';

/**
 * 标记页面中的消息组件
 */
@ComponentV2
export struct MemberHistoryMessageComponent {
  AlignLeft: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
    'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
  }
  @Require
  @Param
  message?: NIMMessageInfo = undefined;

  @Require
  @Param
  userAvatarName?: UserAvatarNameItem = undefined;

  @Param
  onMessageClick?: MessageItemClick = undefined


  build() {
    Column() {
      if (this.message) {
        Text(this.message?.getMessageFormatTime())
          .fontColor($r('app.color.color_chat_desc'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .margin({ top: 3 })

        Row() {
          CommonAvatar({
            item: this.userAvatarName?.avatar,
          })
            .width(36)
            .height(36)
            .borderRadius(20)
            .margin({ left: 16, top: 16 })
            .id("otherAvatar")

          Column() {
            Text(this.userAvatarName?.name ?? "")
              .fontColor($r('app.color.color_chat_sub_title'))
              .fontSize($r('app.float.chat_subtitle_text_font_size'))
              .maxLines(1)
              .width('100%')
              .textAlign(TextAlign.Start)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .ellipsisMode(EllipsisMode.END)

            memberHistoryMessageContent({ message: this.message, onMessageClick: this.onMessageClick })
              .backgroundColor($r('app.color.color_chat_receive_message_bg'))
              .borderRadius({
                topLeft: 0,
                topRight: 8,
                bottomLeft: 8,
                bottomRight: 8
              })
              .id("msgContainer")
              .alignRules(this.AlignLeft)
              .onClick((event: ClickEvent) => {
                this.onMessageClick?.onItemClick?.(event, this.message)
              })

          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 10, top: 16, right: 16 })

        }
        .alignItems(VerticalAlign.Top)
        .alignSelf(ItemAlign.Start)

      }
    }
    .backgroundColor(Color.White)
    .borderRadius(8)
    .onClick((event: ClickEvent) => {
      this.onMessageClick?.onItemClick?.(event, this.message)
    })
  }
}