/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, CustomMessageUtils, getMultiLinePreviewFromAttachment, multiLineMessageCustomType } from '@nimkit/chatkit';
import { AvatarColorUntil, AvatarItem, CommonAvatar } from '@nimkit/common';
import { DateUtil } from '@nimkit/common';
import { V2NIMAIUser, V2NIMLocalConversation, V2NIMMessageCallAttachment, V2NIMMessageType } from '@nimsdk/base';

@ComponentV2
export struct ConversationAIUserViewItem {
  @Param aiUserInfo: V2NIMAIUser | null = null
  // @Param haveBeanAit: boolean = false
  @Param onItemClick?: () => void | undefined = undefined

  build() {
    if (this.aiUserInfo !== null) {
      Column() {
        // Row 1 头像
        Row() {
          Stack({
            alignContent: Alignment.TopEnd
          }) {
            CommonAvatar({
              item: new AvatarItem(this.aiUserInfo.avatar,
                this.getAvatarShowName(this.aiUserInfo.name || this.aiUserInfo.accountId),
                AvatarColorUntil.getBackgroundColorById(this.aiUserInfo.accountId)
              )
            })
            // 未读数显示，AIUser 不需要展示 unreadCount
            // if (this.conversationInfo.mute !== true && this.conversationInfo.unreadCount > 0) {
            //   Text(this.getUnreadCountStr(this.conversationInfo.unreadCount))
            //     .fontSize(12)
            //     .fontColor('#ffFFFFFF')
            //     .textAlign(TextAlign.Center)
            //     .backgroundColor('#ffF24957')
            //     .borderRadius(20)
            //     .height(18)
            //     .width(18 + (this.getUnreadCountStr(this.conversationInfo.unreadCount).length - 1) * 4)
            // }

          }
        }
        .width(42)
        .height(42)

        // Row 2 name
        Row() {
          //item 显示名称
          Text(this.aiUserInfo.name)
            .fontSize(12)
            .fontColor("#ff666666")
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(1)
        }
        .width(42)
        .height(20)
        .margin({
          top: 6,
          left: 0,
          right: 0
        }).alignItems(VerticalAlign.Center)
      }
      .width(62)
      .height(82)
      .onClick(() => {
        // this.goToChatPage()
        if (this.onItemClick !== undefined) {
          this.onItemClick()
        }
      })
      .padding({
        left: 20,
        top: 10,
        bottom: 10,
        // right: 20
      })
    }

  }

  /**
   * 获取未读数展示
   * @param unreadCount
   * @returns
   */
  getUnreadCountStr(unreadCount: number): string {
    if (unreadCount < 100) {
      return unreadCount + ''
    } else {
      return '99+'
    }
  }

  /**
   * 头像只显示后两位
   * @param sourceName
   * @returns
   */
  getAvatarShowName(sourceName: string): string {
    let size = sourceName.length
    if (size <= 2) {
      return sourceName
    } else {
      return sourceName.substring(size - 2)
    }
  }

  /**
   * 获取会话列表展示的内容
   * @param item
   * @returns
   */
  getConversationContent(item: V2NIMLocalConversation): string | Resource {
    switch (item.lastMessage?.messageType) {
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT:
        return item.lastMessage.text ?? ''
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE:
        return $r('app.string.imageMessageType')
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO:
        return $r('app.string.audioMessageType')
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO:
        return $r('app.string.videoMessageType')
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION:
        return $r('app.string.locationMessageType')
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE:
        return $r('app.string.fileMessageType')
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION:
        return $r('app.string.notificationMessageType')
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_TIPS:
        return $r('app.string.tipMessageType')
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL:
        if (item.lastMessage?.attachment) {
          const messageAttachment = item.lastMessage.attachment as V2NIMMessageCallAttachment
          if (messageAttachment.type == 1) {
            return $r('app.string.msg_type_rtc_audio')
          } else {
            return $r('app.string.msg_type_rtc_video')
          }
        }
        break
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM:
        if (item.lastMessage?.attachment) {
          const customType = CustomMessageUtils.typeOfCustomMessage(item.lastMessage.attachment)
          if (customType === multiLineMessageCustomType) {
            return getMultiLinePreviewFromAttachment(item.lastMessage?.attachment)
          }
        }
        break
    }
    return item.lastMessage?.text ?? $r('app.string.chatMessageNonsupportType')

  }
}
