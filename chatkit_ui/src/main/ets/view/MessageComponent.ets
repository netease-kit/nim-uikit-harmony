/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NIMMessageInfo } from '../model/NIMMessageInfo';
import {
  NotificationMessageComponent,
  ReceiveMessageComponent,
  SenderMessageComponent,
  TipsMessageComponent
} from '../view/MsgBaseComponent';
import { V2NIMMessageType } from '@nimsdk/base';
import { ChatInfo } from '../model/ChatInfo';
import { getNotificationMessageContent } from '../common/MessageHelper';

@ComponentV2
export struct MessageComponent {
  @Require
  @Param
  private message: NIMMessageInfo | undefined = undefined;
  @Require
  @Param
  private chatInfo: ChatInfo
  @Require
  @Param
  private onItemClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
  @Require
  @Param
  private onItemLongClick?: (event: GestureEvent, msg: NIMMessageInfo | undefined) => void
  @Require
  @Param
  private onAvatarClick?: (msg: NIMMessageInfo | undefined) => void

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
        onItemLongClick: this.onItemLongClick,
        onItemClick: this.onItemClick,
        onAvatarClick: this.onAvatarClick,
      });
    } else {
      SenderMessageComponent({
        message: this.message,
        chatUserInfo: this.chatInfo,
        onItemLongClick: this.onItemLongClick,
        onItemClick: this.onItemClick,
        onAvatarClick: this.onAvatarClick
      });
    }
  }
}