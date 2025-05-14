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
} from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService'
import {
  ChatKitClient,
  ChatRepo,
  CustomMessageUtils,
  keyReplyMsgKey,
  mergedMessageCustomType,
  StorageRepo
} from '@nimkit/chatkit'
import { DateUtils } from '../common/DateUtils'
import { fileUri } from '@kit.CoreFileKit'
import { ChatConst } from '../constants/ChatConst'
import { JSONUtil } from '@nimkit/common'
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit'
import { V2NIMGetMediaResourceInfoResult, V2NIMMessageAIStreamStatus, V2NIMMessagePin } from '@nimsdk/base'
import { ChatKitConfig } from '../ChatKitConfig'
import { getMergedMessageContent, measureMessageHeight } from '../common/MessageHelper'
import fs from '@ohos.file.fs'

@ObservedV2
export class NIMMessageInfo {
  // IM  SDK 层的消息对象
  @Trace message: V2NIMMessage
  // 未读数量
  @Trace unReadCount: number = 100
  // 已读数量
  @Trace readCount: number = -1
  // 消息下载或上传进度
  @Trace downloadProgress: number = -1
  @Trace messageHeight = -1
  // 消息附件
  attachment: V2NIMMessageAttachment | null = null
  // 自定义消息附件
  customAttachment: object | null = null
  // 上一条消息的发送时间，用于判断该消息展示时候是否需要展示发送时间
  @Trace lastMessageTime: number = 0
  // 是否是接收消息，UI渲染时使用
  isReceiveMsg: boolean = false
  // 是否为撤回消息
  isRevokeMsg: boolean = false
  // 是否为撤回可编辑
  @Trace revokeEditMsg: boolean = false
  // 是否为PIN消息
  @Trace isPinMsg: boolean = false
  // 是否为合并转发消息
  isMergeMsg: boolean = false
  mergedContent: string = ''
  // 是否为合并转发详情页中的消息
  isMergeDetailMsg: boolean = false
  // 是否为多选选中
  @Trace isSelectedMsg: boolean = false
  //是否为回复消息
  @Trace
  isReplyMsg: boolean = false
  // 回复消息
  @Trace replyMsg: NIMMessageInfo | undefined = undefined
  // 撤回消息扩展
  revokeInfo: RevokeInfo | undefined = undefined
  //pin信息
  pinInfo: V2NIMMessagePin | undefined = undefined

  constructor(msg: V2NIMMessage) {
    this.message = msg
    this.parseMessage(msg)
  }

  async parseMessage(message: V2NIMMessage) {
    this.isReceiveMsg = this.message.senderId != ChatKitClient.getLoginUserId()

    // 解析撤回
    this.revokeInfo = RevokeInfo.parseRevokeInfo(message)
    if (this.revokeInfo != null) {
      this.isRevokeMsg = true
      this.revokeEditMsg = this.revokeInfo?.isEditMsg &&
        (systemDateTime.getTime() - this.revokeInfo.revokeTime < ChatKitConfig.messageRevokeTimeLimit)
    }

    // 解析合并转发
    if (message.messageType == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM && message.attachment != null) {
      this.customAttachment = CustomMessageUtils.dataOfCustomMessage(message.attachment)
      let customType = CustomMessageUtils.typeOfCustomMessage(message.attachment)
      if (customType == mergedMessageCustomType) {
        this.isMergeMsg = true
        this.mergedContent = getMergedMessageContent(this.customAttachment)
      }
    }

    // 解析回复
    this.parseReply(message)

    this.messageHeight = -1
  }

  // @Computed
  // get isReplyMsg():boolean{
  //   return this.replyMsg !== undefined
  // }

  setIsReply(reply: boolean) {
    this.isReplyMsg = reply
  }

  async parseReply(message: V2NIMMessage) {
    // 优先使用 thread 方案
    if (message.threadReply) {
      this.isReplyMsg = true
      try {
        const messages = await ChatRepo.getMessageListByRefers([message.threadReply])
        if (messages.length > 0) {
          this.replyMsg = new NIMMessageInfo(messages[0])
        }
      } catch (err) {
        console.error(err)
      }
      return
    }

    // 非 thread 方案
    const remoteExt = message.serverExtension
    if (remoteExt) {
      try {
        const remoteDic = JSON.parse(remoteExt) as object
        const msgReplyDic = remoteDic[keyReplyMsgKey] as object
        if (msgReplyDic) {
          try {
            this.isReplyMsg = true
            const messages = await ChatRepo.getMessageListByRefers([{
              messageClientId: msgReplyDic['idClient'] as string,
              messageServerId: msgReplyDic['idServer'] as string,
              senderId: msgReplyDic['from'] as string,
              createTime: msgReplyDic['time'] as number,
              conversationId: msgReplyDic['to'] as string,
              receiverId: msgReplyDic['receiverId'] as string,
              conversationType: msgReplyDic['scene'] as number,
            }]).catch((err: BusinessError) => {
              console.debug('netease parseReply', err.message)
            })

            if (messages && messages.length > 0) {
              this.replyMsg = new NIMMessageInfo(messages[0])
            }
          } catch (err) {
            console.error(err)
          }
        }
      } catch (err) {
        console.error(err)
      }
    }
  }

  checkRevokeEdit(): boolean {
    if (this.revokeInfo != null) {
      this.isRevokeMsg = true
      this.revokeEditMsg = this.revokeInfo?.isEditMsg &&
        (systemDateTime.getTime() - this.revokeInfo.revokeTime < ChatKitConfig.messageRevokeTimeLimit)
      return this.revokeEditMsg
    }
    return false
  }

  configReadReceipt(): boolean {
    return this.message.messageConfig?.readReceiptEnabled ?? false
  }

  updateMessageStatus(message: V2NIMMessage) {
    this.message = message
  }

  setLastMessageTime(time: number) {
    this.lastMessageTime = time
  }

  setSelected(isSelected: boolean) {
    this.isSelectedMsg = isSelected
  }

  getMessageHeight(context: UIContext): number {
    if (this.messageHeight < 0) {
      this.messageHeight = measureMessageHeight(context, this)
    }
    return this.messageHeight
  }

  setPinMessage(pinMsg: V2NIMMessagePin | undefined) {
    if (pinMsg !== undefined) {
      this.pinInfo = pinMsg
      this.isPinMsg = true
    } else {
      this.isPinMsg = false
      this.pinInfo = undefined
    }
    this.messageHeight = -1

  }

  setDownloadProgress(progress: number) {
    this.downloadProgress = progress
  }

  setReadCount(readCount: number, unreadCount: number) {
    this.unReadCount = unreadCount
    this.readCount = readCount
  }

  getCreateTime(): number {
    return this.message.createTime
  }

  // 获取消息时间
  getMessageFormatTime(): string {
    return DateUtils.formatTime(this.message.createTime, this.lastMessageTime)
  }

  // 获取消息时间（根据消息时间展示的间隔）
  getMessageTime(): string {
    let result = ''
    if (this.message.createTime - this.lastMessageTime > ChatKitConfig.messageTimeGap) {
      result = DateUtils.formatTime(this.message.createTime, this.lastMessageTime)
    }
    return result
  }

  getConversationId() {
    return this.message.conversationId
  }

  getConversationType() {
    return ChatKitClient.nim.conversationIdUtil.parseConversationType(this.getConversationId())
  }

  getMessageClientId(): string {
    return this.message.messageClientId
  }

  getAvatarName(): string {
    let result = ''
    if (this.message != null && this.message != null) {
      result = this.message.senderId.substring(this.message.senderId.length - 2, this.message.senderId.length)
    }
    if (this.message != null && this.message.senderId != null) {
      result = this.message.senderId.substring(this.message.senderId.length - 2, this.message.senderId.length)
    }
    return result
  }

  getMessageType(): V2NIMMessageType {
    return this.message.messageType
  }

  isAiStreamMessage(): boolean {
    return this.message.aiConfig?.aiStream ?? false
  }

  isFinishedAiStream(): boolean {
    return (this.message.aiConfig?.aiStreamStatus ??
    V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_GENERATED) >
    V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_PLACEHOLDER
  }

  isReceiveMessage(): boolean {
    return this.isReceiveMsg
  }

  isPinMessage(): boolean {
    return this.isPinMsg
  }

  isMergeMessage(): boolean {
    return this.isMergeMsg
  }

  isMergeDetailMessage(): boolean {
    return this.isMergeDetailMsg
  }

  getImageUrl(): string {
    if (this.message.messageType == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      let iamgeAttachment = this.message.attachment as V2NIMMessageImageAttachment
      if (iamgeAttachment) {
        if (iamgeAttachment.path) {
          if (fs.accessSync(iamgeAttachment.path)) {
            const uri = fileUri.getUriFromPath(iamgeAttachment.path)
            return uri
          }
        }
        return iamgeAttachment.url ?? ''
      }
    }
    return ''
  }

  async getImageThumbUrl(): Promise<string> {
    if (this.message.messageType == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      let iamgeAttachment = this.message.attachment as V2NIMMessageImageAttachment
      if (iamgeAttachment) {
        if (iamgeAttachment.path) {
          if (fs.accessSync(iamgeAttachment.path)) {
            const uri = fileUri.getUriFromPath(iamgeAttachment.path)
            return uri
          }
        }
        const thumbResult: V2NIMGetMediaResourceInfoResult | undefined =
          await StorageRepo.getImageThumbUrl(iamgeAttachment, {
            width: ChatConst.imageMessageWidth
          })
        if (!thumbResult) {
          return iamgeAttachment.url ?? ''
        } else {
          return thumbResult.url ?? ''
        }
      }
    }
    return ''
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