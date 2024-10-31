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
import { ChatConst } from '../constants/ChatConst';
import { JSONUtil } from '@nimkit/common';
import { systemDateTime } from '@kit.BasicServicesKit';
import { V2NIMMessagePin } from '@nimsdk/base';
import { ChatKitConfig } from '../ChatKitConfig';

@ObservedV2
export class NIMMessageInfo {
  // IM  SDK 层的消息对象
  @Trace message: V2NIMMessage;
  // 未读数量
  @Trace unReadCount: number = 100;
  // 已读数量
  @Trace readCount: number = -1;
  // 消息下载或上传进度
  @Trace downloadProgress: number = -1;
  // 消息附件
  attachment: V2NIMMessageAttachment | null = null;
  // 上一条消息的发送时间，用于判断该消息展示时候是否需要展示发送时间
  lastMessageTime: number = 0;
  // 是否是接收消息，UI渲染时使用
  @Trace isReceiveMsg: boolean = false;
  // 是否为撤回消息
  @Trace isRevokeMsg: boolean = false;
  // 是否为撤回可编辑
  @Trace revokeEditMsg: boolean = false;
  // 是否为PIN消息
  @Trace isPinMsg: boolean = false;
  // 撤回消息扩展
  revokeInfo: RevokeInfo | undefined = undefined
  //pin信息
  pinInfo: V2NIMMessagePin | undefined = undefined

  constructor(msg: V2NIMMessage) {
    this.message = msg
    this.parseMessage(msg)
  }

  parseMessage(message: V2NIMMessage) {
    this.isReceiveMsg = this.message.senderId != ChatKitClient.getLoginUserId();
    this.revokeInfo = RevokeInfo.parseRevokeInfo(message)
    if (this.revokeInfo != null) {
      this.isRevokeMsg = true
      this.revokeEditMsg = this.revokeInfo?.isEditMsg &&
        (systemDateTime.getTime() - this.revokeInfo.revokeTime < ChatKitConfig.messageRevokeTimeLimit)
    }
  }

  checkRevokeEdit(): boolean {
    if (this.revokeInfo != null) {
      this.isRevokeMsg = true
      this.revokeEditMsg = this.revokeInfo?.isEditMsg &&
        (systemDateTime.getTime() - this.revokeInfo.revokeTime < ChatKitConfig.messageRevokeTimeLimit)
      return this.revokeEditMsg
    }
    return false;
  }

  configReadReceipt(): boolean {
    return this.message.messageConfig?.readReceiptEnabled ?? false
  }

  updateMessageStatus(message: V2NIMMessage) {
    this.message = message;
  }

  setLastMessageTime(time: number) {
    this.lastMessageTime = time;
  }

  setPinMessage(pinMsg: V2NIMMessagePin | undefined) {
    if (pinMsg !== undefined) {
      this.pinInfo = pinMsg
      this.isPinMsg = true
    } else {
      this.isPinMsg = false
      this.pinInfo = undefined
    }

  }

  setDownloadProgress(progress: number) {
    this.downloadProgress = progress;
  }

  setReadCount(readCount: number, unreadCount: number) {
    this.unReadCount = unreadCount;
    this.readCount = readCount;
  }

  getCreateTime(): number {
    return this.message.createTime;
  }

  // 获取消息时间
  getMessageFormatTime(): string {
    return DateUtils.formatTime(this.lastMessageTime, this.message.createTime)
  }

  // 获取消息时间（根据消息时间展示的间隔）
  getMessageTime(): string {
    let result = '';
    if (this.message.createTime - this.lastMessageTime > ChatKitConfig.messageTimeGap) {
      result = DateUtils.formatTime(this.lastMessageTime, this.message.createTime)
    }
    return result;
  }

  getConversationId() {
    return this.message.conversationId;
  }

  getMessageClientId(): string {
    return this.message.messageClientId;
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

  isPinMessage(): boolean {
    return this.isPinMsg
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

export class RevokeInfo {
  isLocalRevoke: boolean = false
  revokeTime: number = 0
  isEditMsg: boolean = false
  revokeMsgText: string = ''
  revokeMsgClientId: string = ''

  static parseRevokeInfo(msg: V2NIMMessage): RevokeInfo | undefined {
    if (msg == undefined || msg.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT ||
      msg.localExtension == undefined
      || !msg.localExtension?.includes(ChatConst.revokeLocalKey)) {
      return undefined
    }

    let localExtension = msg.localExtension
    if (JSONUtil.isJSONString(localExtension)) {
      let localObject = JSON.parse(localExtension) as object
      let revokeInfo = new RevokeInfo()
      revokeInfo.revokeMsgText = localObject?.[ChatConst.revokeMsgTextKey]
      revokeInfo.revokeMsgClientId = localObject?.[ChatConst.revokeMsgClientIdKey]
      revokeInfo.revokeTime = localObject?.[ChatConst.revokeLocalTimeKey]
      revokeInfo.isLocalRevoke = localObject?.[ChatConst.revokeLocalKey]
      revokeInfo.isEditMsg = localObject?.[ChatConst.revokeMsgEditKey]
      return revokeInfo
    }

    return undefined
  }
}
