/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  V2NIMMessage,
  V2NIMMessageAttachment,
  V2NIMMessageImageAttachment,
  V2NIMMessageType
} from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService'
import { image } from '@kit.ImageKit'
import {
  ChatKitClient,
  ChatRepo,
  CustomMessageUtils,
  keyReplyMsgKey,
  mergedMessageCustomType,
  multiLineMessageCustomType,
  StorageRepo
} from '@nimkit/chatkit'
import { DateUtils } from '../common/DateUtils'
import { fileUri } from '@kit.CoreFileKit'
import { ChatConst } from '../constants/ChatConst'
import { JSONUtil } from '@nimkit/common'
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit'
import {
  NIMEStrAnyObj,
  V2NIMGetMediaResourceInfoResult,
  V2NIMMessageAIStatus,
  V2NIMMessageAIStreamStatus,
  V2NIMMessagePin,
  V2NIMMessageQuickComment,
  V2NIMMessageSendingState
} from '@nimsdk/base'
import { ChatKitConfig } from '../ChatKitConfig'
import { getMergedMessageContent, measureMessageHeight } from '../common/MessageHelper'
import fs from '@ohos.file.fs'

export function getAIResponseRequesterId(message: V2NIMMessage | undefined): string {
  if (!message) {
    return ''
  }

  const threadSenderId = message.threadReply?.senderId
  if (threadSenderId) {
    return threadSenderId
  }

  const remoteExt = message.serverExtension
  if (!remoteExt) {
    return ''
  }
  try {
    const remoteDic = JSON.parse(remoteExt) as object
    const msgReplyDic = remoteDic[keyReplyMsgKey] as object
    if (msgReplyDic) {
      return msgReplyDic['from'] as string
    }
  } catch (err) {
    Logger.debug('ChatKitUI', 'netease getAIResponseRequesterId', err)
  }
  return ''
}

export function canOperateAIResponseMessage(message: V2NIMMessage | undefined, loginUserId: string): boolean {
  const requesterId = getAIResponseRequesterId(message)
  return message?.aiConfig?.aiStatus === V2NIMMessageAIStatus.V2NIM_MESSAGE_AI_STATUS_RESPONSE &&
    requesterId.length > 0 &&
    requesterId === loginUserId
}

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
  // 是否为换行消息（多行消息，type=102）
  isMultiLineMsg: boolean = false
  // 是否为合并转发消息（合并转发消息，type=101）
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
  // 是否被反垃圾
  @Trace
  isServerAntiSpam: boolean = false
  // 是否为 anchor 高亮消息（用于跳转定位时的高亮动画）
  @Trace isAnchorHighlight: boolean = false
  @Trace quickComments: V2NIMMessageQuickComment[] = []
  // 缓存的缩略图 PixelMap（用于图片预览时作为占位图，避免网络不可用时预览黑屏）
  cachedThumbPixelMap: image.PixelMap | undefined = undefined
  // 语音转文字结果（运行时数据，不持久化）
  @Trace voiceToText?: string
  // 语音转文字加载中状态
  @Trace voiceToTextLoading: boolean = false
  // 翻译结果（最后一次翻译）
  @Trace translatedText?: string
  @Trace translatedTitle?: string
  @Trace translatedBody?: string
  @Trace translationLoading: boolean = false
  @Trace translationFailed: boolean = false
  @Trace showTranslatedText: boolean = false
  @Trace showOriginalText: boolean = true
  @Trace translationLanguageMismatch: boolean = false
  translationHydrated: boolean = false

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

    // 解析自定义消息类型
    if (message.messageType == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM && message.attachment != null) {
      this.customAttachment = CustomMessageUtils.dataOfCustomMessage(message.attachment)
      let customType = CustomMessageUtils.typeOfCustomMessage(message.attachment)
      // 合并转发消息 (type=101)
      if (customType == mergedMessageCustomType) {
        this.isMergeMsg = true
        this.mergedContent = getMergedMessageContent(this.customAttachment)
      }
      // 换行消息 (type=102)
      if (customType == multiLineMessageCustomType) {
        this.isMultiLineMsg = true
      }
    }

    // 解析回复
    this.parseReply(message)

    // 是否被反垃圾
    this.isServerAntiSpam = this.getServerAntispam()

    this.messageHeight = -1
  }

  // @Computed
  // get isReplyMsg():boolean{
  //   return this.replyMsg !== undefined
  // }

  setIsReply(reply: boolean) {
    this.isReplyMsg = reply
  }

  clearReplyInfo(): void {
    this.isReplyMsg = false
    this.replyMsg = undefined
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
        Logger.error('ChatKitUI', err)
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
              Logger.debug('ChatKitUI', 'netease parseReply', err.message)
            })

            if (messages && messages.length > 0) {
              this.replyMsg = new NIMMessageInfo(messages[0])
            }
          } catch (err) {
            Logger.error('ChatKitUI', err)
          }
        }
      } catch (err) {
        Logger.error('ChatKitUI', err)
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

  setQuickComments(comments: V2NIMMessageQuickComment[]): void {
    this.quickComments = comments
    this.messageHeight = -1
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
      let senderId = this.getDisplaySenderId()
      result = senderId.substring(senderId.length - 2, senderId.length)
    }
    if (this.message != null && this.message.senderId != null) {
      let senderId = this.getDisplaySenderId()
      result = senderId.substring(senderId.length - 2, senderId.length)
    }
    return result
  }

  getMessageType(): V2NIMMessageType {
    return this.message.messageType
  }

  isAiStreamMessage(): boolean {
    return this.message.aiConfig?.aiStream ?? false
  }

  /**
   * 是否为 AI 回复消息。对齐 Android isAIResponseMsg()
   */
  isAIResponseMsg(): boolean {
    return this.message.aiConfig?.aiStatus === V2NIMMessageAIStatus.V2NIM_MESSAGE_AI_STATUS_RESPONSE
  }

  isAIResponseFromAIUser(): boolean {
    return this.isAIResponseMsg() && !!this.message.aiConfig?.accountId
  }

  canOperateAIResponse(): boolean {
    return canOperateAIResponseMessage(this.message, ChatKitClient.getLoginUserId())
  }

  getDisplaySenderId(): string {
    const aiAccountId = this.message.aiConfig?.accountId
    if (this.isAIResponseMsg() && aiAccountId) {
      return aiAccountId
    }
    return this.message.senderId
  }

  isAiStreamStreaming(): boolean {
    const status = this.message.aiConfig?.aiStreamStatus ??
      V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_GENERATED
    return status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_PLACEHOLDER ||
      status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING
  }

  isAIStreamInProgress(): boolean {
    return this.isAIResponseMsg() && !this.isAiStreamFinished()
  }

  canOperateInMultiSelect(): boolean {
    // Keep failed messages available for local batch actions
    return !this.isRevokeMsg &&
      this.message.sendingState !== V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING &&
      !this.isAIStreamInProgress()
  }

  isAiStreamFinished(): boolean {
    const status = this.message.aiConfig?.aiStreamStatus ??
      V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_GENERATED
    return status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_NONE ||
      status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STOPPED ||
      status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_UPDATED ||
      status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_GENERATED ||
      status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_ABORTED
  }

  isReceiveMessage(): boolean {
    return this.isReceiveMsg || this.isAIResponseFromAIUser()
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

  private getServerAntispam(): boolean {
    // 是否被反垃圾
    if (!this.message.localExtension) {
      return false
    }

    // is json && json.isServerAntispam = true, return true
    try {
      const json: NIMEStrAnyObj = JSON.parse(this.message.localExtension)
      if (json.isServerAntispam) {
        return true
      } else {
        return false
      }
    } catch (error) {
      return false
    }
  }
}

export class RevokeInfo {
  isLocalRevoke: boolean = false
  revokeTime: number = 0
  isEditMsg: boolean = false
  revokeMsgText: string = ''
  revokeMsgClientId: string = ''
  revokeMsgAttachment: string = ''  // 用于自定义消息（如富文本消息）的附件

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
      revokeInfo.revokeMsgAttachment = localObject?.[ChatConst.revokeMsgAttachmentKey] ?? ''
      return revokeInfo
    }

    return undefined
  }
}
