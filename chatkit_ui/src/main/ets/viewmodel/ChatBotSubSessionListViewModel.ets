/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  ChatKitClient,
  ChatRepo,
  ConversationEventRepo,
  ConversationIdUtilRepo,
  ConversationRepo,
  DisposableBag,
  IMKitConfigCenter,
  LoginEventRepo,
  LocalConversationRepo,
  CustomMessageUtils,
  mergedMessageCustomType,
  multiLineMessageCustomType,
  getMultiLinePreviewFromAttachment,
  TopicRepo
} from '@nimkit/chatkit';
import {
  V2NIMConnectStatus,
  V2NIMConversationType,
  V2NIMLoginStatus,
  V2NIMMessage,
  V2NIMMessageCallAttachment,
  V2NIMMessageFileAttachment,
  V2NIMMessageRefer,
  V2NIMMessageSendingState,
  V2NIMMessageType,
  V2NIMQueryDirection,
  V2NIMRemoveTopicsParams,
  V2NIMTopic,
  V2NIMTopicListOption,
  V2NIMTopicListResult,
  V2NIMTopicRefer,
  V2NIMThreadMessageListResult,
  V2NIMUpdateTopicParams
} from '@nimsdk/base';
import { DateUtils } from '../common/DateUtils';

const CHAT_BOT_TOPIC_LIST_TAG = '[ChatBotSubSessionList]'
const CHAT_BOT_TOPIC_SUMMARY_MAX_LENGTH = 30

@ObservedV2
export class ChatBotSubSessionItem {
  @Trace topic: V2NIMTopic
  @Trace title: string = ''
  @Trace summary: string = ''
  @Trace timeText: string = ''
  @Trace latestMessageTime: number = 0
  latestOtherMessageTime: number = 0
  @Trace showUnreadDot: boolean = false

  constructor(topic: V2NIMTopic) {
    this.topic = topic
    this.title = ChatBotSubSessionItem.getTopicTitle(topic)
  }

  static getTopicTitle(topic: V2NIMTopic): string {
    const topicName = topic.topicName ?? ''
    return topicName.length > 0 ?
      topicName :
      getContext().resourceManager.getStringSync($r('app.string.chat_bot_sub_session_untitled').id)
  }
}

@ObservedV2
export class ChatBotSubSessionListViewModel {
  @Trace items: ChatBotSubSessionItem[] = []
  @Trace keyword: string = ''
  @Trace loading: boolean = false
  @Trace error: boolean = false
  @Trace hasMore: boolean = false
  conversationId: string = ''
  private allItems: ChatBotSubSessionItem[] = []
  private nextToken?: string = undefined
  private readonly pageLimit: number = 30
  private listenerRegistered: boolean = false
  private didInitialLoad: boolean = false
  private reloadPromise?: Promise<void> = undefined
  private readTime: number = 0
  private networkBroken: boolean = ChatKitClient.connectBroken()
  private loginEventDisposers: DisposableBag = new DisposableBag()

  private onTopicAddedListener = (topic: V2NIMTopic): void => {
    if (topic.conversationId !== this.conversationId) {
      return
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.onTopicAdded topicId=${topic.topicId}`)
    this.upsertTopic(topic, true)
  }

  private onTopicsRemovedListener = (topics: V2NIMTopicRefer[]): void => {
    if (topics.length <= 0) {
      return
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.onTopicsRemoved count=${topics.length}`)
    const removedIds: number[] = topics.map((topic: V2NIMTopicRefer) => topic.topicId)
    this.allItems = this.allItems.filter((item: ChatBotSubSessionItem) => !removedIds.includes(item.topic.topicId))
    this.applyFilter()
  }

  private onTopicUpdatedListener = (topic: V2NIMTopic): void => {
    if (topic.conversationId !== this.conversationId) {
      return
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.onTopicUpdated topicId=${topic.topicId}`)
    this.upsertTopic(topic, false)
  }

  private onSendMessageListener = (message: V2NIMMessage): void => {
    if (message.sendingState !== V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED) {
      return
    }
    this.refreshTopicSummaryByMessage(message)
  }

  private onReceiveMessagesListener = (messages: V2NIMMessage[]): void => {
    messages.forEach((message: V2NIMMessage) => {
      this.refreshTopicSummaryByMessage(message)
    })
  }

  private onConversationReadTimeUpdated = (conversationId: string, readTime: number): void => {
    if (conversationId !== this.conversationId) {
      return
    }
    this.readTime = Math.max(this.readTime, readTime ?? 0)
    this.updateUnreadDots()
  }

  private onConnectStatusListener = (status: V2NIMConnectStatus): void => {
    if (status !== V2NIMConnectStatus.V2NIM_CONNECT_STATUS_CONNECTED) {
      this.networkBroken = true
    }
  }

  private onLoginStatusListener = async (status: V2NIMLoginStatus): Promise<void> => {
    if (!this.networkBroken || status !== V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED) {
      return
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} loginStatus changed to logined, reload topic list`)
    await this.reload()
    this.networkBroken = false
  }

  init(conversationId: string): void {
    this.conversationId = conversationId
    this.registerTopicListeners()
    this.refreshConversationReadTime()
    this.reload()
  }

  resume(): void {
    if (!this.conversationId) {
      return
    }
    this.registerTopicListeners()
    if (!this.didInitialLoad) {
      this.reload()
      return
    }
    this.refreshConversationReadTime()
    this.refreshSummaries()
  }

  private registerTopicListeners(): void {
    if (this.listenerRegistered) {
      return
    }
    TopicRepo.onTopicAdded(this.onTopicAddedListener)
    TopicRepo.onTopicsRemoved(this.onTopicsRemovedListener)
    TopicRepo.onTopicUpdated(this.onTopicUpdatedListener)
    ChatRepo.onSendMessage(this.onSendMessageListener)
    ChatRepo.onReceiverMessage(this.onReceiveMessagesListener)
    this.loginEventDisposers.dispose()
    this.loginEventDisposers.addAll([
      LoginEventRepo.onConnectStatus(this.onConnectStatusListener),
      LoginEventRepo.onLoginStatus(this.onLoginStatusListener)
    ])
    if (IMKitConfigCenter.enableLocalConversation) {
      ConversationEventRepo.onLocalConversationReadTimeUpdated(this.onConversationReadTimeUpdated)
    } else {
      ConversationEventRepo.onCloudConversationReadTimeUpdated(this.onConversationReadTimeUpdated)
    }
    this.listenerRegistered = true
  }

  destroy(): void {
    if (!this.listenerRegistered) {
      return
    }
    TopicRepo.offTopicAdded(this.onTopicAddedListener)
    TopicRepo.offTopicsRemoved(this.onTopicsRemovedListener)
    TopicRepo.offTopicUpdated(this.onTopicUpdatedListener)
    ChatRepo.offSendMessage(this.onSendMessageListener)
    ChatRepo.offReceiverMessage(this.onReceiveMessagesListener)
    this.loginEventDisposers.dispose()
    if (IMKitConfigCenter.enableLocalConversation) {
      ConversationEventRepo.offLocalConversationReadTimeUpdated(this.onConversationReadTimeUpdated)
    } else {
      ConversationEventRepo.offCloudConversationReadTimeUpdated(this.onConversationReadTimeUpdated)
    }
    this.listenerRegistered = false
  }

  async reload(): Promise<void> {
    if (!this.conversationId) {
      return
    }
    if (this.reloadPromise) {
      return this.reloadPromise
    }
    this.reloadPromise = this.doReload()
    try {
      await this.reloadPromise
    } finally {
      this.reloadPromise = undefined
    }
  }

  private async doReload(): Promise<void> {
    this.loading = true
    this.error = false
    this.nextToken = undefined
    try {
      const option: V2NIMTopicListOption = {
        conversationId: this.conversationId,
        limit: this.pageLimit,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC
      }
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.getTopicListByOption conversationId=${this.conversationId}`)
      const result: V2NIMTopicListResult = await TopicRepo.getTopicListByOption(option)
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.getTopicListByOption success count=${result.topicList.length} hasMore=${result.hasMore}`)
      this.hasMore = result.hasMore
      this.nextToken = result.nextToken
      this.allItems = result.topicList.map((topic: V2NIMTopic) => new ChatBotSubSessionItem(topic))
      this.didInitialLoad = true
      this.applyFilter()
      this.fetchLatestMessages(this.allItems)
    } catch (err) {
      this.error = true
      Logger.error('ChatKitUI', 'ChatBotSubSessionListViewModel reload error: ' + JSON.stringify(err))
    } finally {
      this.loading = false
    }
  }

  async renameTopic(topic: V2NIMTopic, title: string): Promise<void> {
    const trimmedTitle = title.trim()
    if (trimmedTitle.length <= 0) {
      return
    }
    const params: V2NIMUpdateTopicParams = {
      topic: topic,
      topicName: trimmedTitle
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.updateTopic topicId=${topic.topicId}`)
    const updatedTopic = await TopicRepo.updateTopic(params)
    this.upsertTopic(updatedTopic, false)
  }

  async removeTopic(topic: V2NIMTopic): Promise<void> {
    const params: V2NIMRemoveTopicsParams = {
      topicList: [topic]
    }
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.removeTopics topicId=${topic.topicId}`)
    await TopicRepo.removeTopics(params)
    this.allItems = this.allItems.filter((item: ChatBotSubSessionItem) => item.topic.topicId !== topic.topicId)
    this.items = this.items.filter((item: ChatBotSubSessionItem) => item.topic.topicId !== topic.topicId)
  }

  updateTopicFromChat(topic: V2NIMTopic, refreshSummary: boolean = true): void {
    if (topic.conversationId !== this.conversationId) {
      return
    }
    this.upsertTopic(topic, false, refreshSummary)
  }

  removeTopicFromChat(topic: V2NIMTopic): void {
    if (topic.conversationId !== this.conversationId) {
      return
    }
    this.allItems = this.allItems.filter((item: ChatBotSubSessionItem) =>
      item.topic.topicId !== topic.topicId || item.topic.createTime !== topic.createTime)
    this.applyFilter()
  }

  async loadMore(): Promise<void> {
    if (!this.conversationId || !this.hasMore || this.loading || this.keyword.length > 0) {
      return
    }
    this.loading = true
    try {
      const option: V2NIMTopicListOption = {
        conversationId: this.conversationId,
        nextToken: this.nextToken,
        limit: this.pageLimit,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC
      }
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.getTopicListByOption loadMore nextToken=${this.nextToken ?? ''}`)
      const result: V2NIMTopicListResult = await TopicRepo.getTopicListByOption(option)
      this.hasMore = result.hasMore
      this.nextToken = result.nextToken
      const appendedItems = result.topicList.map((topic: V2NIMTopic) => new ChatBotSubSessionItem(topic))
      this.allItems = this.allItems.concat(appendedItems)
      this.applyFilter()
      this.fetchLatestMessages(appendedItems)
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatBotSubSessionListViewModel loadMore error: ' + JSON.stringify(err))
    } finally {
      this.loading = false
    }
  }

  private upsertTopic(topic: V2NIMTopic, insertTop: boolean, refreshSummary: boolean = true): void {
    const index = this.allItems.findIndex((item: ChatBotSubSessionItem) => item.topic.topicId === topic.topicId)
    const item = new ChatBotSubSessionItem(topic)
    if (index >= 0) {
      item.summary = this.allItems[index].summary
      item.timeText = this.allItems[index].timeText
      item.latestMessageTime = this.allItems[index].latestMessageTime
      item.latestOtherMessageTime = this.allItems[index].latestOtherMessageTime
      item.showUnreadDot = this.allItems[index].showUnreadDot
      this.allItems.splice(index, 1)
      if (insertTop) {
        this.allItems.unshift(item)
      } else {
        this.allItems.splice(index, 0, item)
      }
    } else if (insertTop) {
      this.allItems.unshift(item)
    } else {
      this.allItems.push(item)
    }
    this.applyFilter()
    if (refreshSummary) {
      this.fetchLatestMessages([item])
    }
  }

  search(keyword: string): void {
    this.keyword = keyword.trim().toLowerCase()
    this.applyFilter()
  }

  refreshSummaries(): void {
    this.fetchLatestMessages(this.allItems)
  }

  private applyFilter(): void {
    this.sortAllItems()
    if (this.keyword.length <= 0) {
      this.items = this.allItems.slice()
      return
    }
    this.items = this.allItems.filter((item: ChatBotSubSessionItem) => item.title.toLowerCase().includes(this.keyword))
  }

  private sortAllItems(): void {
    this.allItems.sort((left: ChatBotSubSessionItem, right: ChatBotSubSessionItem) => {
      return this.getSortTime(right) - this.getSortTime(left)
    })
  }

  private getSortTime(item: ChatBotSubSessionItem): number {
    return Math.max(item.topic.updateTime ?? 0, item.latestMessageTime)
  }

  private async refreshConversationReadTime(): Promise<void> {
    if (!this.conversationId) {
      return
    }
    try {
      const readTime = IMKitConfigCenter.enableLocalConversation
        ? await LocalConversationRepo.getConversationReadTime(this.conversationId)
        : await ConversationRepo.getConversationReadTime(this.conversationId)
      this.readTime = readTime ?? 0
      this.updateUnreadDots()
    } catch (err) {
      this.readTime = 0
      this.updateUnreadDots()
      Logger.error('ChatKitUI', 'ChatBotSubSessionListViewModel refreshConversationReadTime error: ' + JSON.stringify(err))
    }
  }

  private updateUnreadDots(): void {
    this.allItems.forEach((item: ChatBotSubSessionItem) => {
      item.showUnreadDot = this.readTime > 0 && item.latestOtherMessageTime > this.readTime
    })
  }

  private fetchLatestMessages(items: ChatBotSubSessionItem[]): void {
    items.forEach((item: ChatBotSubSessionItem) => {
      this.fetchLatestMessage(item)
    })
  }

  private canLoadLocalThreadMessages(topic: V2NIMTopic): boolean {
    return ChatKitClient.getLoginUserId().length > 0 &&
      ConversationIdUtilRepo.parseConversationTargetId(topic.conversationId).length > 0 &&
      topic.messageClientId.length > 0 &&
      topic.messageServerId.length > 0 &&
      topic.messageTime > 0
  }

  private createLocalThreadRootMessageRefer(topic: V2NIMTopic): V2NIMMessageRefer {
    const conversationType: V2NIMConversationType =
      ConversationIdUtilRepo.parseConversationType(topic.conversationId)
    return {
      senderId: ChatKitClient.getLoginUserId(),
      receiverId: ConversationIdUtilRepo.parseConversationTargetId(topic.conversationId),
      messageClientId: topic.messageClientId,
      messageServerId: topic.messageServerId,
      createTime: topic.messageTime,
      conversationType,
      conversationId: topic.conversationId
    }
  }

  private getLatestTopicSummaryMessage(result: V2NIMThreadMessageListResult): V2NIMMessage | undefined {
    if (result.replyList.length > 0) {
      return result.replyList[result.replyList.length - 1]
    }
    return result.message.messageType !== undefined ? result.message : undefined
  }

  private getLatestIncomingTopicMessage(result: V2NIMThreadMessageListResult): V2NIMMessage | undefined {
    for (let index = result.replyList.length - 1; index >= 0; index--) {
      const replyMessage = result.replyList[index]
      if (!this.isSelfMessage(replyMessage)) {
        return replyMessage
      }
    }
    const rootMessage = result.message.messageType !== undefined ? result.message : undefined
    if (rootMessage && !this.isSelfMessage(rootMessage)) {
      return rootMessage
    }
    return undefined
  }

  private isSelfMessage(message: V2NIMMessage): boolean {
    return message.senderId === ChatKitClient.getLoginUserId()
  }

  private async fetchLatestMessage(item: ChatBotSubSessionItem): Promise<void> {
    try {
      if (!this.canLoadLocalThreadMessages(item.topic)) {
        return
      }
      const messageRefer = this.createLocalThreadRootMessageRefer(item.topic)
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} messageService.getLocalThreadMessageList latest topicId=${item.topic.topicId}`)
      const result = await ChatRepo.getLocalThreadMessageList(messageRefer)
      const message = this.getLatestTopicSummaryMessage(result)
      if (!message) {
        this.clearTopicSummary(item)
        this.applyFilter()
        return
      }
      const latestIncomingMessage = this.getLatestIncomingTopicMessage(result)
      item.summary = this.getMessageSummary(message)
      item.latestMessageTime = message.createTime
      item.latestOtherMessageTime = latestIncomingMessage?.createTime ?? 0
      item.timeText = DateUtils.formatTime(message.createTime)
      item.showUnreadDot = this.readTime > 0 && item.latestOtherMessageTime > this.readTime
      this.applyFilter()
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatBotSubSessionListViewModel fetchLatestMessage error: ' + JSON.stringify(err))
    }
  }

  private clearTopicSummary(item: ChatBotSubSessionItem): void {
    item.summary = ''
    item.latestMessageTime = 0
    item.latestOtherMessageTime = 0
    item.timeText = ''
    item.showUnreadDot = false
  }

  private refreshTopicSummaryByMessage(message: V2NIMMessage): void {
    const topicRefer = message.topicRefer
    if (!topicRefer || topicRefer.conversationId !== this.conversationId) {
      return
    }
    const index = this.allItems.findIndex((item: ChatBotSubSessionItem) =>
      item.topic.topicId === topicRefer.topicId && item.topic.createTime === topicRefer.createTime)
    if (index < 0) {
      return
    }
    const item = this.allItems[index]
    item.summary = this.getMessageSummary(message)
    item.latestMessageTime = message.createTime
    item.timeText = DateUtils.formatTime(message.createTime)
    if (!this.isSelfMessage(message)) {
      item.latestOtherMessageTime = message.createTime
    }
    // Keep unread dots based on the latest incoming reply instead of self replies.
    item.showUnreadDot = this.readTime > 0 && item.latestOtherMessageTime > this.readTime
    this.applyFilter()
  }

  private getMessageSummary(message: V2NIMMessage): string {
    const resourceManager = getContext().resourceManager
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      const text = message.text ?? ''
      if (text.length <= 0) {
        return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_no_message').id)
      }
      return text.length > CHAT_BOT_TOPIC_SUMMARY_MAX_LENGTH ? text.substring(0, CHAT_BOT_TOPIC_SUMMARY_MAX_LENGTH) : text
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_image').id)
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_audio').id)
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
      return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_video').id)
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
      const fileName = (message.attachment as V2NIMMessageFileAttachment | undefined)?.name ?? ''
      if (fileName.length <= 0) {
        return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_file').id)
      }
      return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_file_with_name').id, fileName)
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
      return resourceManager.getStringSync($r('app.string.locationMessageType').id)
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION) {
      return resourceManager.getStringSync($r('app.string.notificationMessageType').id)
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TIPS) {
      return resourceManager.getStringSync($r('app.string.tipMessageType').id)
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_ROBOT) {
      return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_robot').id)
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL ||
      message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AVCHAT) {
      if (message.attachment) {
        const callAttachment = message.attachment as V2NIMMessageCallAttachment
        if (callAttachment.type == 1) {
          return resourceManager.getStringSync($r('app.string.msg_type_rtc_audio').id)
        }
        return resourceManager.getStringSync($r('app.string.msg_type_rtc_video').id)
      }
      return '[' + resourceManager.getStringSync($r('app.string.chat_send_call').id) + ']'
    }
    if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM && message.attachment) {
      const customType = CustomMessageUtils.typeOfCustomMessage(message.attachment)
      if (customType === mergedMessageCustomType) {
        return resourceManager.getStringSync($r('app.string.chat_merge_history').id)
      }
      if (customType === multiLineMessageCustomType) {
        const multiLinePreview = this.normalizePreviewText(getMultiLinePreviewFromAttachment(message.attachment))
        if (multiLinePreview.length > 0) {
          return multiLinePreview.length > CHAT_BOT_TOPIC_SUMMARY_MAX_LENGTH ?
            multiLinePreview.substring(0, CHAT_BOT_TOPIC_SUMMARY_MAX_LENGTH) : multiLinePreview
        }
      }
    }
    return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_message').id)
  }

  private normalizePreviewText(text: string): string {
    return text.replace(/\r\n/g, ' ').replace(/[\r\n]/g, ' ').replace(/\s+/g, ' ').trim()
  }
}
