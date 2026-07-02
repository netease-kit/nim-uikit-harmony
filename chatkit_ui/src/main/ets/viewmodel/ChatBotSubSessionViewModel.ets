/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  ChatRepo,
  TopicRepo
} from '@nimkit/chatkit';
import {
  V2NIMMessage,
  V2NIMMessageAIStatus,
  V2NIMMessageSendingState,
  V2NIMMessageType,
  V2NIMQueryDirection,
  V2NIMRemoveTopicsParams,
  V2NIMSendMessageParams,
  V2NIMSendMessageResult,
  V2NIMSendTopicMessageParams,
  V2NIMSortOrder,
  V2NIMTopic,
  V2NIMTopicRefer,
  V2NIMUpdateTopicParams
} from '@nimsdk/base';
import { BusinessError } from '@kit.BasicServicesKit';
import { NECommonUtils } from '@nimkit/common';
import { ChatP2PViewModel } from './ChatP2PViewModel';
import { ChatConst } from '../constants/ChatConst';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { sendMessageFailedTips } from '../common/MessageHelper';
import { ChatBotSubSessionParam } from '../model/ChatBotSubSessionParam';

const CHAT_BOT_TOPIC_TAG = '[ChatBotSubSession]'
const CHAT_BOT_TOPIC_TITLE_MAX_LENGTH = 20

@ObservedV2
export class ChatBotSubSessionViewModel extends ChatP2PViewModel {
  @Trace currentTopic: V2NIMTopic | undefined = undefined
  @Trace isPlaceholderTopic: boolean = true
  @Trace currentTopicDeleted: boolean = false
  private topicCreatedListener?: (topic: V2NIMTopic) => void
  private topicRemovedListener?: () => void
  private pendingTopicMessageClientIds: string[] = []
  private topicListenerRegistered: boolean = false

  private onTopicsRemovedListener = (topics: V2NIMTopicRefer[]): void => {
    if (!this.currentTopic || topics.length <= 0) {
      return
    }
    const removed = topics.find((topic: V2NIMTopicRefer) => topic.conversationId === this.currentTopic?.conversationId &&
      topic.topicId === this.currentTopic?.topicId &&
      topic.createTime === this.currentTopic?.createTime)
    if (!removed) {
      return
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.onTopicsRemoved current topicId=${this.currentTopic.topicId}`)
    this.markCurrentTopicRemoved()
  }

  private onTopicUpdatedListener = (topic: V2NIMTopic): void => {
    if (!this.isSameTopic(topic)) {
      return
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.onTopicUpdated topicId=${topic.topicId}`)
    this.currentTopic = topic
  }

  initSubSession(param: ChatBotSubSessionParam): void {
    this.currentTopic = param.topic
    this.isPlaceholderTopic = param.topic === undefined
    this.currentTopicDeleted = false
    this.pendingTopicMessageClientIds = []
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} initSubSession conversationId=${param.conversationId} topicId=${param.topic?.topicId ?? -1} placeholder=${this.isPlaceholderTopic}`)
    this.registerTopicListeners()
  }

  private isSameTopic(topic?: V2NIMTopic): boolean {
    if (!topic || !this.currentTopic) {
      return false
    }
    return topic.conversationId === this.currentTopic.conversationId &&
      topic.topicId === this.currentTopic.topicId &&
      topic.createTime === this.currentTopic.createTime
  }

  private isMessageInCurrentTopic(message: V2NIMMessage): boolean {
    if (!this.currentTopic) {
      return false
    }
    const refer = message.topicRefer
    return refer !== undefined &&
      refer.conversationId === this.currentTopic.conversationId &&
      refer.topicId === this.currentTopic.topicId &&
      refer.createTime === this.currentTopic.createTime
  }

  private filterCurrentTopicMessages(messages: V2NIMMessage[]): V2NIMMessage[] {
    return messages.filter((message: V2NIMMessage) => this.isMessageInCurrentTopic(message))
  }

  private addPendingTopicMessage(messageClientId: string): void {
    if (messageClientId.length <= 0 || this.pendingTopicMessageClientIds.includes(messageClientId)) {
      return
    }
    this.pendingTopicMessageClientIds.push(messageClientId)
  }

  private removePendingTopicMessage(messageClientId: string): void {
    this.pendingTopicMessageClientIds =
      this.pendingTopicMessageClientIds.filter((clientId: string) => clientId !== messageClientId)
  }

  private isPendingTopicMessage(message: V2NIMMessage): boolean {
    return this.pendingTopicMessageClientIds.includes(message.messageClientId)
  }

  private upsertTopicMessage(message: V2NIMMessage): void {
    const updated = this.chatInfo?.updateMessageStatus(message)
    if (!updated) {
      this.chatInfo?.setReceiveMsg(true, [message])
    }
    this.clearRootReplyForCurrentTopic()
  }

  private clearRootReplyInfo(msgInfo?: NIMMessageInfo): void {
    if (!msgInfo || !this.currentTopic) {
      return
    }
    const rootClientId = this.currentTopic.messageClientId
    if (!rootClientId || msgInfo.message.threadReply?.messageClientId !== rootClientId) {
      return
    }
    msgInfo.clearReplyInfo()
  }

  private clearRootReplyForCurrentTopic(): void {
    if (!this.currentTopic) {
      return
    }
    const messages = this.chatInfo?.msgList.getMessageList() ?? []
    messages.forEach((msgInfo: NIMMessageInfo) => {
      this.clearRootReplyInfo(msgInfo)
    })
  }

  private buildAutoTopicName(message: V2NIMMessage): string {
    const resourceManager = getContext().resourceManager
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      const text = (message.text ?? '').trim().replace(/\s+/g, ' ')
      if (text.length <= 0) {
        return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_untitled').id)
      }
      return text.length > CHAT_BOT_TOPIC_TITLE_MAX_LENGTH ? text.substring(0, CHAT_BOT_TOPIC_TITLE_MAX_LENGTH) : text
    }
    const date = new Date(message.createTime > 0 ? message.createTime : Date.now())
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    const time = `${hour}:${minute}`
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      return `${resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_image').id)} ${time}`
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
      return `${resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_file').id)} ${time}`
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      return `${resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_audio').id)} ${time}`
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
      return `${resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_video').id)} ${time}`
    }
    return `${resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_message').id)} ${time}`
  }

  private async updateAutoTopicName(topic: V2NIMTopic, message: V2NIMMessage): Promise<void> {
    if (topic.topicName && topic.topicName.length > 0) {
      return
    }
    const topicName = this.buildAutoTopicName(message)
    if (topicName.length <= 0) {
      return
    }
    try {
      const updatedTopic = await TopicRepo.updateTopic({
        topic: topic,
        topicName: topicName
      })
      if (this.isSameTopic(updatedTopic)) {
        this.currentTopic = updatedTopic
      }
    } catch (error) {
      const err = error as Error
      Logger.error('ChatKitUI', 'ChatBotSubSessionViewModel updateAutoTopicName error', err.message)
    }
  }

  onReceiveFun = (messages: V2NIMMessage[]) => {
    if (this.isPlaceholderTopic) {
      return
    }
    const topicMessages = this.filterCurrentTopicMessages(messages)
    if (topicMessages.length <= 0) {
      return
    }
    this.handleReceiveMessages(topicMessages)
    this.clearRootReplyForCurrentTopic()
    setTimeout(() => {
      this.clearRootReplyForCurrentTopic()
    }, 100)
  }

  onSendFun = async (message: V2NIMMessage): Promise<void> => {
    const isPendingTopicMessage = this.isPendingTopicMessage(message)
    const isCurrentTopicMessage = this.isMessageInCurrentTopic(message)
    if (message.conversationId !== this.conversationId || (!isCurrentTopicMessage && !isPendingTopicMessage)) {
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} onSendMessage ignore clientId=${message.messageClientId} topicId=${message.topicRefer?.topicId ?? -1} pending=${isPendingTopicMessage}`)
      return
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} onSendMessage accept clientId=${message.messageClientId} state=${message.sendingState} topicId=${message.topicRefer?.topicId ?? -1} pending=${isPendingTopicMessage}`)
    if (message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
      if (message.messageClientId !== this.sendingMsgClientId) {
        this.sendingMsgClientId = message.messageClientId
        const msgInfo = this.chatInfo?.pushMessage(message)
        this.clearRootReplyInfo(msgInfo)
        this.chatInfo?.setReceiveMsg(true, [message])
      }
      return
    }

    const result = this.chatInfo?.updateMessageStatus(message)
    if (!result) {
      this.chatInfo?.setReceiveMsg(true, [message])
    }
    if (message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED) {
      this.removePendingTopicMessage(message.messageClientId)
      this.toHandleSendMessageSuccess(message)
    }
  }

  async getMessageList(): Promise<NIMMessageInfo[]> {
    let result: NIMMessageInfo[] = []
    this.chatInfo?.cleanMessage()
    this.setAnchorMessage(undefined)
    if (!this.currentTopic) {
      this.hasMore = false
      this.hasLoadData = true
      this.chatInfo?.setReceiveMsg(true, [])
      return result
    }

    let hasError = false
    const messageList: V2NIMMessage[] = await TopicRepo.getTopicMessageList({
      topic: this.currentTopic,
      limit: ChatConst.chatMessagePageSize,
      direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC,
      sortOrder: V2NIMSortOrder.V2NIM_SORT_ORDER_DESC
    }).then((topicResult) => {
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.getTopicMessageList success topicId=${this.currentTopic?.topicId ?? -1} count=${topicResult.replyList.length} hasMore=${topicResult.hasMore}`)
      this.hasMore = topicResult.hasMore
      return topicResult.replyList
    }).catch((err: BusinessError) => {
      hasError = true
      Logger.error('ChatKitUI', 'ChatBotSubSessionViewModel getMessageList error', err.code, err.message)
      return []
    })

    if (hasError) {
      return result
    }

    for (let index = messageList.length - 1; index >= 0; index--) {
      const msgInfo = this.chatInfo?.pushMessage(messageList[index])
      if (msgInfo !== undefined) {
        this.clearRootReplyInfo(msgInfo)
        result.push(msgInfo)
      }
    }
    setTimeout(() => {
      this.clearRootReplyForCurrentTopic()
    }, 100)
    this.chatInfo?.setReceiveMsg(true, result.map((receiveMsg: NIMMessageInfo) => receiveMsg.message))
    this.toHandleQueryMessage(result, messageList)
    this.hasLoadData = true
    return result
  }

  async sendMessage(msg: V2NIMMessage, params?: V2NIMSendMessageParams, progress?: (percentage: number) => void): Promise<void> {
    try {
      if (this.isPlaceholderTopic || this.currentTopic === undefined) {
        this.addPendingTopicMessage(msg.messageClientId)
      }
      const mergedParams = this.beforeSendMessage(params)
      const topicParams: V2NIMSendTopicMessageParams = {
        sendMessageParams: mergedParams
      }
      if (this.isPlaceholderTopic || this.currentTopic === undefined) {
        topicParams.createTopicParams = {
          topicName: this.buildAutoTopicName(msg)
        }
      }
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.sendTopicMessage conversationId=${this.conversationId} topicId=${this.currentTopic?.topicId ?? -1} create=${this.currentTopic === undefined}`)
      const result: V2NIMSendMessageResult = await TopicRepo.sendTopicMessage(
        msg,
        this.conversationId,
        this.currentTopic,
        topicParams,
        progress
      )
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.sendTopicMessage success clientId=${result.message.messageClientId} topicId=${result.message.topicRefer?.topicId ?? -1} createTime=${result.message.topicRefer?.createTime ?? 0}`)
      const resultTopic = result.message.topicRefer
      if (resultTopic !== undefined && (this.currentTopic === undefined || this.isPlaceholderTopic)) {
        Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.getTopicByRefer topicId=${resultTopic.topicId}`)
        const createdTopic = await TopicRepo.getTopicByRefer(resultTopic)
        if (createdTopic) {
          Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topic created topicId=${createdTopic.topicId}`)
          this.currentTopic = createdTopic
          this.isPlaceholderTopic = false
          this.topicCreatedListener?.(createdTopic)
          await this.updateAutoTopicName(createdTopic, result.message)
        }
      }
      if (result.message.topicRefer !== undefined || this.isMessageInCurrentTopic(result.message)) {
        this.removePendingTopicMessage(result.message.messageClientId)
        this.upsertTopicMessage(result.message)
      }
      if (result.message.aiConfig) {
        NECommonUtils.showToast($r('app.string.chat_ai_message_progressing'))
      }
    } catch (error) {
      this.removePendingTopicMessage(msg.messageClientId)
      const err = error as BusinessError
      Logger.error('ChatKitUI', 'netease send topic message error', err.code, err.message)
      sendMessageFailedTips(msg, err, this.conversationId)
    }
  }

  async replyMessage(msg: V2NIMMessage, replyMsg: V2NIMMessage, params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void): Promise<void> {
    if (!this.currentTopic) {
      this.sendMessage(msg, params, progress)
      return
    }
    const mergedParams = this.beforeSendMessage(params)
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.replyTopicMessage topicId=${this.currentTopic.topicId}`)
    TopicRepo.replyTopicMessage(msg, replyMsg, this.currentTopic, mergedParams, progress)
      .catch((err: BusinessError) => {
        Logger.error('ChatKitUI', 'net ease reply topic message error', err.code, err.message)
        sendMessageFailedTips(msg, err, this.conversationId)
      })
  }

  async getMoreMessageList(): Promise<NIMMessageInfo[]> {
    const anchorMsg = this.chatInfo?.msgList.getData(0)
    if (this.isLoading || anchorMsg === undefined || !this.currentTopic) {
      return []
    }
    this.isLoading = true
    let result: NIMMessageInfo[] = []
    try {
      const topicResult = await TopicRepo.getTopicMessageList({
        topic: this.currentTopic,
        anchorMessage: anchorMsg.message,
        limit: ChatConst.chatMessagePageSize,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC,
        sortOrder: V2NIMSortOrder.V2NIM_SORT_ORDER_DESC
      })
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.getTopicMessageList more topicId=${this.currentTopic.topicId} count=${topicResult.replyList.length} hasMore=${topicResult.hasMore}`)
      this.hasMore = topicResult.hasMore
      if (this.chatInfo) {
        result = this.chatInfo.unshiftMessage(topicResult.replyList)
        result.forEach((msgInfo: NIMMessageInfo) => {
          this.clearRootReplyInfo(msgInfo)
        })
      }
      setTimeout(() => {
        this.clearRootReplyForCurrentTopic()
      }, 100)
      this.toHandleQueryMessage(result, topicResult.replyList)
    } catch (err) {
      const error = err as BusinessError
      Logger.error('ChatKitUI', 'ChatBotSubSessionViewModel getMoreMessageList error', error.code, error.message)
      if (this.networkBroken) {
        this.hasMore = true
      }
    } finally {
      this.isLoading = false
    }
    return result
  }

  async getNewMessageList(): Promise<NIMMessageInfo[]> {
    if (this.isLoading || !this.hasNew || !this.currentTopic) {
      return []
    }
    const anchorMsg = this.chatInfo?.msgList.getData((this.chatInfo?.msgList.totalCount() ?? 0) - 1)
    if (anchorMsg === undefined) {
      return []
    }
    this.isLoading = true
    let result: NIMMessageInfo[] = []
    try {
      const topicResult = await TopicRepo.getTopicMessageList({
        topic: this.currentTopic,
        anchorMessage: anchorMsg.message,
        limit: ChatConst.chatMessagePageSize,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC,
        sortOrder: V2NIMSortOrder.V2NIM_SORT_ORDER_ASC
      })
      this.hasNew = topicResult.hasMore
      if (this.chatInfo) {
        for (let index = 0; index < topicResult.replyList.length; index++) {
          const msgInfo = this.chatInfo.pushMessage(topicResult.replyList[index])
          this.clearRootReplyInfo(msgInfo)
          result.push(msgInfo)
        }
      }
      setTimeout(() => {
        this.clearRootReplyForCurrentTopic()
      }, 100)
      this.toHandleQueryMessage(result, topicResult.replyList)
    } catch (err) {
      const error = err as BusinessError
      Logger.error('ChatKitUI', 'ChatBotSubSessionViewModel getNewMessageList error', error.code, error.message)
      this.hasNew = this.networkBroken
    } finally {
      this.isLoading = false
    }
    return result
  }

  resendMessage(msgInfo: NIMMessageInfo) {
    let params: V2NIMSendMessageParams | undefined = undefined
    const pushList = msgInfo.message.pushConfig?.forcePushAccountIds
    if (pushList) {
      params = {
        pushConfig: {
          forcePush: true,
          forcePushAccountIds: pushList.length >= 0 ? pushList : undefined
        }
      }
    }
    if (msgInfo.isReplyMsg && msgInfo.replyMsg && msgInfo.replyMsg.message && this.currentTopic) {
      this.replyMessage(msgInfo.message, msgInfo.replyMsg.message, params)
    } else {
      this.sendMessage(msgInfo.message, params)
    }
  }

  setTopicCreatedListener(listener: (topic: V2NIMTopic) => void): void {
    this.topicCreatedListener = listener
  }

  setTopicRemovedListener(listener: () => void): void {
    this.topicRemovedListener = listener
  }

  markCurrentTopicRemoved(): void {
    if (this.currentTopicDeleted) {
      return
    }
    this.currentTopicDeleted = true
    this.topicRemovedListener?.()
  }

  async removeCurrentTopic(): Promise<boolean> {
    if (!this.currentTopic) {
      return false
    }
    const params: V2NIMRemoveTopicsParams = {
      topicList: [this.currentTopic]
    }
    try {
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.removeTopics topicId=${this.currentTopic.topicId}`)
      await TopicRepo.removeTopics(params)
      return true
    } catch (error) {
      const err = error as BusinessError
      Logger.error('ChatKitUI', 'ChatBotSubSessionViewModel removeCurrentTopic error', err.code, err.message)
      return false
    }
  }

  async renameCurrentTopic(title: string): Promise<boolean> {
    const trimmedTitle = title.trim()
    if (!this.currentTopic || trimmedTitle.length <= 0) {
      return false
    }
    const params: V2NIMUpdateTopicParams = {
      topic: this.currentTopic,
      topicName: trimmedTitle
    }
    try {
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_TAG} topicService.updateTopic topicId=${this.currentTopic.topicId}`)
      const updatedTopic = await TopicRepo.updateTopic(params)
      if (this.isSameTopic(updatedTopic)) {
        this.currentTopic = updatedTopic
      }
      return true
    } catch (error) {
      const err = error as BusinessError
      Logger.error('ChatKitUI', 'ChatBotSubSessionViewModel renameCurrentTopic error', err.code, err.message)
      return false
    }
  }

  toHandleSendMessageSuccess(message: V2NIMMessage): void {
    if (message.topicRefer !== undefined && this.currentTopic === undefined) {
      TopicRepo.getTopicByRefer(message.topicRefer).then((topic) => {
        if (topic) {
          this.currentTopic = topic
          this.isPlaceholderTopic = false
          this.topicCreatedListener?.(topic)
          this.updateAutoTopicName(topic, message)
        }
      }).catch((error: Error) => {
        Logger.error('ChatKitUI', 'ChatBotSubSessionViewModel toHandleSendMessageSuccess getTopicByRefer error', error.message)
      })
    }
  }

  toHandleReceiveMessage(messages: NIMMessageInfo[]): void {
    this.getUserInfo()
    this.toHandleReceiptMessage(messages)
  }

  toHandleQueryMessage(messages: NIMMessageInfo[], originMsg: V2NIMMessage[]): void {
    this.getUserInfo()
    this.toHandleReceiptMessage(messages)
  }

  private registerTopicListeners(): void {
    if (this.topicListenerRegistered) {
      return
    }
    TopicRepo.onTopicsRemoved(this.onTopicsRemovedListener)
    TopicRepo.onTopicUpdated(this.onTopicUpdatedListener)
    this.topicListenerRegistered = true
  }

  private unregisterTopicListeners(): void {
    if (!this.topicListenerRegistered) {
      return
    }
    TopicRepo.offTopicsRemoved(this.onTopicsRemovedListener)
    TopicRepo.offTopicUpdated(this.onTopicUpdatedListener)
    this.topicListenerRegistered = false
  }

  onDestroy(): void {
    this.unregisterTopicListeners()
    super.onDestroy()
  }
}
