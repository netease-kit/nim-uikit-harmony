/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMMessage,
  V2NIMMessageAttachment,
  V2NIMMessageImageAttachment,
  V2NIMMessageType
} from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService';
import { ChatKitClient } from '@nimkit/chatkit';
import { DateUtils } from '../common/DateUtils';
import { fileUri } from '@kit.CoreFileKit';

@ObservedV2
export class NIMMessageInfo {
  @Trace message: V2NIMMessage;
  unReadCount: number = -1;
  readCount: number = -1;
  @Trace
  downloadProgress: number = -1;
  attachment: V2NIMMessageAttachment | null = null;
  lastMessageTime: number = 0;
  @Trace
  isReceiveMsg: boolean = false;

  constructor(msg: V2NIMMessage) {
    this.message = msg
    this.isReceiveMsg = this.message.senderId != ChatKitClient.getLoginUserId();
  }

  updateMessageStatus(message: V2NIMMessage) {
    this.message = message;
  }

  setLastMessageTime(time: number) {
    this.lastMessageTime = time;
  }

  setDownloadProgress(progress: number) {
    this.downloadProgress = progress;
  }

  getCreateTime(): number {
    return this.message.createTime;
  }

  getMessageTime(): string {
    let result = '';
    if (this.message.createTime - this.lastMessageTime > 300000) {
      result = DateUtils.formatTime(this.lastMessageTime, this.message.createTime)
    }
    return result;
  }

  getConversationId() {
    return this.message.conversationId;
  }

  getAvatarName(): string {
    let result = '';
    if (this.message != null && this.message != null) {
      result = this.message.senderId.substring(this.message.senderId.length - 2, this.message.senderId.length)
    }
    if (this.message != null && this.message.senderId != null) {
      result = this.message.senderId.substring(this.message.senderId.length - 2, this.message.senderId.length)
    }
    return result;
  }

  getMessageType(): V2NIMMessageType {
    return this.message.messageType;
  }


  isReceiveMessage(): boolean {
    return this.isReceiveMsg
  }

  getImageUrl(): string {
    if (this.message.messageType == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      let iamgeAttachment = this.message.attachment as V2NIMMessageImageAttachment;
      if (iamgeAttachment != null) {
        if (iamgeAttachment.path !== undefined) {
          return fileUri.getUriFromPath(iamgeAttachment.path);
        }
        return iamgeAttachment.url ?? '';
      }

    } else if (this.message.messageType == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
      let videoAttachment = this.message.attachment as V2NIMMessageImageAttachment;
      if (videoAttachment != null) {
        if (videoAttachment.path !== undefined) {
          return fileUri.getUriFromPath(videoAttachment.path);
        }
        return videoAttachment.url ?? '';
      }
    }
    return '';
  }
}

