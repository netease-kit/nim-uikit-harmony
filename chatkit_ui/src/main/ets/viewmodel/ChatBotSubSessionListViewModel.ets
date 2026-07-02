/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatKitClient, ChatRepo, ConversationRepo, IMKitConfigCenter, LocalConversationRepo, TopicRepo } from '@nimkit/chatkit';
import {
  V2NIMMessage,
  V2NIMMessageFileAttachment,
  V2NIMMessageSendingState,
  V2NIMMessageType,
  V2NIMQueryDirection,
  V2NIMRemoveTopicsParams,
  V2NIMSortOrder,
  V2NIMTopic,
  V2NIMTopicListOption,
  V2NIMTopicListResult,
  V2NIMTopicRefer,
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

  init(conversationId: string): void {
    this.conversationId = conversationId
    this.registerTopicListeners()
    this.clearConversationUnread()
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

  private async clearConversationUnread(): Promise<void> {
    if (!this.conversationId) {
      return
    }
    try {
      if (IMKitConfigCenter.enableLocalConversation) {
        await LocalConversationRepo.clearUnreadCountByIds([this.conversationId])
      } else {
        await ConversationRepo.clearUnreadCountByIds([this.conversationId])
      }
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatBotSubSessionListViewModel clearConversationUnread error: ' + JSON.stringify(err))
    }
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
      item.showUnreadDot = item.latestMessageTime > this.readTime
    })
  }

  private fetchLatestMessages(items: ChatBotSubSessionItem[]): void {
    items.forEach((item: ChatBotSubSessionItem) => {
      this.fetchLatestMessage(item)
    })
  }

  private async fetchLatestMessage(item: ChatBotSubSessionItem): Promise<void> {
    try {
      Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_TAG} topicService.getTopicMessageList latest topicId=${item.topic.topicId}`)
      const result = await TopicRepo.getTopicMessageList({
        topic: item.topic,
        limit: 1,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC,
        sortOrder: V2NIMSortOrder.V2NIM_SORT_ORDER_DESC
      })
      if (result.replyList.length <= 0) {
        return
      }
      const message: V2NIMMessage = result.replyList[0]
      item.summary = this.getMessageSummary(message)
      item.latestMessageTime = message.createTime
      item.timeText = DateUtils.formatTime(message.createTime)
      item.showUnreadDot = this.readTime > 0 && message.createTime > this.readTime
      this.applyFilter()
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatBotSubSessionListViewModel fetchLatestMessage error: ' + JSON.stringify(err))
    }
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
    item.showUnreadDot = message.senderId !== ChatKitClient.getLoginUserId() &&
      this.readTime > 0 &&
      message.createTime > this.readTime
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
    return resourceManager.getStringSync($r('app.string.chat_bot_sub_session_summary_message').id)
  }
}
