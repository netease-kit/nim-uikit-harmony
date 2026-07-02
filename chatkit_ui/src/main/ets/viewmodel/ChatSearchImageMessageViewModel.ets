/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */
import { Logger } from '@nimkit/common';
import { ChatRepo, IMKitConfigCenter } from '@nimkit/chatkit'
import { ConversationSelectModel } from '@nimkit/chatkit'
import {
  V2NIMMessage,
  V2NIMMessageConfig,
  V2NIMMessageDeletedNotification,
  V2NIMMessageRevokeNotification,
  V2NIMMessageSearchExParams,
  V2NIMMessageSearchResult,
  V2NIMMessageType,
  V2NIMSendMessageParams
} from '@nimsdk/base'
import { sendMessageFailedTips } from '../common/MessageHelper'
import { buildSendMessageParams } from '../common/SendMessageParamsHelper'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { BusinessError } from '@kit.BasicServicesKit'

export interface ChatSearchImageMessageParams {
  conversationId: string
}

/**
 * 按日期分组的消息
 */
@ObservedV2
export class DateGroupedMessages {
  // 日期字符串，如 "10月3日"
  @Trace dateLabel: string = ''
  // 日期时间戳（当天0点的时间戳，用于排序）
  @Trace dateTimestamp: number = 0
  // 该日期下的消息列表
  @Trace messages: NIMMessageInfo[] = []

  constructor(dateLabel: string, dateTimestamp: number) {
    this.dateLabel = dateLabel
    this.dateTimestamp = dateTimestamp
  }

  // 生成唯一的 key，包含消息数量以确保 ForEach 能正确刷新
  getUniqueKey(): string {
    return `${this.dateLabel}_${this.messages.length}`
  }
}

const messageListLimit: number = 50

@ObservedV2
export class ChatSearchImageMessageViewModel {
  // 会话ID
  @Trace conversationId: string = ''
  // 下一次请求所需token
  @Trace pageToken: string | undefined
  // 是否正在加载
  @Trace isLoading: boolean = false
  // 是否有更多
  @Trace hasMore: boolean = true
  // 原始消息列表
  @Trace messageList: V2NIMMessage[] = []
  // 包装后的消息列表
  @Trace messageInfoList: NIMMessageInfo[] = []
  // 按日期分组的消息列表
  @Trace groupedMessageList: DateGroupedMessages[] = []
  // 消息删除或撤回标志
  @Trace revokeAndeDeleteMission = false

  init(conversationId: string) {
    this.conversationId = conversationId
    // 注册消息删除监听
    ChatRepo.onDeleteMessage(this.onDeleteFun)
    // 注册消息撤回监听
    ChatRepo.onRevokeMessage(this.onRevokeFun)
  }

  // 查询图片消息, 可通过 pageToken 加载更多
  async searchMessages() {
    if (this.isLoading) {
      return
    }
    this.isLoading = true

    try {
      let params: V2NIMMessageSearchExParams = {
        conversationId: this.conversationId,
        messageTypes: [V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE],
        limit: messageListLimit,
        pageToken: this.pageToken,
      }
      let searchResult: V2NIMMessageSearchResult | undefined = undefined
      if (IMKitConfigCenter.enableCloudSearch) {
        searchResult = await ChatRepo.searchCloudMessagesEx(params)
      } else {
        searchResult = await ChatRepo.searchLocalMessages(params)
      }

      if (!searchResult) {
        return
      }

      for (let index = searchResult.items.length - 1; index >= 0; index--) {
        let item = searchResult.items[index]
        if (item.conversationId === this.conversationId) {
          this.messageList.push(...item.messages)
        }
      }
      this.pageToken = searchResult.nextPageToken
      this.hasMore = searchResult.hasMore

      // 将消息转换为 NIMMessageInfo
      this.convertToMessageInfoList()
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatSearchImageMessageViewModel searchMessages error:', err)
      // throw err
    } finally {
      this.isLoading = false
    }
  }

  // 将 V2NIMMessage 转换为 NIMMessageInfo 并按日期分组
  private convertToMessageInfoList() {
    this.messageInfoList = []
    let lastMessageTime = 0
    for (let i = 0; i < this.messageList.length; i++) {
      const msg = this.messageList[i]
      const msgInfo = new NIMMessageInfo(msg)
      msgInfo.setLastMessageTime(lastMessageTime)
      lastMessageTime = msg.createTime
      this.messageInfoList.push(msgInfo)
    }

    // 按日期分组
    this.groupMessagesByDate()
  }

  // 按日期分组消息
  private groupMessagesByDate() {
    // 用于存储日期 -> 消息列表的映射
    const dateMap: Map<string, DateGroupedMessages> = new Map()

    for (const msgInfo of this.messageInfoList) {
      const createTime = msgInfo.message.createTime
      const dateKey = this.getDateKey(createTime)
      const dateLabel = this.formatDateLabel(createTime)
      const dateTimestamp = this.getDayStartTimestamp(createTime)

      if (!dateMap.has(dateKey)) {
        dateMap.set(dateKey, new DateGroupedMessages(dateLabel, dateTimestamp))
      }

      const group = dateMap.get(dateKey)!
      group.messages.push(msgInfo)
    }

    // 将 Map 转换为数组并按日期时间戳排序（时间早的在前，时间晚的在后）
    this.groupedMessageList = Array.from(dateMap.values())
      .sort((a, b) => a.dateTimestamp - b.dateTimestamp)

    // 每个分组内的消息也按 createTime 排序（时间早的在前）
    for (const group of this.groupedMessageList) {
      group.messages = group.messages.sort((a, b) => a.message.createTime - b.message.createTime)
    }
  }

  // 获取日期的唯一标识（年-月-日）
  private getDateKey(timestamp: number): string {
    const date = new Date(timestamp)
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`
  }

  // 获取当天0点的时间戳
  private getDayStartTimestamp(timestamp: number): number {
    const date = new Date(timestamp)
    date.setHours(0, 0, 0, 0)
    return date.getTime()
  }

  // 格式化日期标签
  private formatDateLabel(timestamp: number): string {
    const date = new Date(timestamp)
    const now = new Date()
    const year = date.getFullYear()
    const month = date.getMonth() + 1
    const day = date.getDate()

    // 如果是今年，不显示年份
    if (year === now.getFullYear()) {
      return `${month}月${day}日`
    } else {
      return `${year}年${month}月${day}日`
    }
  }

  // 消息发送之前调用，用于配置消息通用参数
  beforeSendMessage(params?: V2NIMSendMessageParams): V2NIMSendMessageParams | undefined {
    return buildSendMessageParams(params)
  }

  /**
   * 转发消息
   * @param msg 消息体
   * @param conversationId 转发到某个会话
   * @param params 消息参数
   * @param progress 消息发送进度
   */
  async sendForwardMessage(msg: V2NIMMessage, conversationId: string, params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void) {
    const mergedParams = this.beforeSendMessage(params)
    ChatRepo.sendMessage(msg, conversationId, mergedParams, progress).catch((err: BusinessError) => {
      Logger.error('ChatKitUI', "net ease send message error", err.code, err.message);
      sendMessageFailedTips(msg, err, conversationId)
    })
  }

  /**
   * 将多个消息转发到多个会话中，并将留言发送到多个会话中
   * @param messages 待转发的消息
   * @param conversationIds 带转发的会话
   * @param leaveText 留言
   */
  forwardMessage(messages: NIMMessageInfo[], conversationIds: ConversationSelectModel[],
    leaveText: string | undefined) {
    conversationIds.forEach((conversation) => {
      messages.forEach((message) => {
        const forwardMsg = ChatRepo.createForwardMessage(message.message)
        try {
          if (forwardMsg && conversation.conversationId) {
            this.sendForwardMessage(forwardMsg, conversation.conversationId)
          }
        } catch (err) {
          Logger.error('ChatKitUI', err)
        }
      })

      // 发送留言
      if (leaveText && leaveText.length > 0) {
        const leaveMsg = ChatRepo.createTextMessage(leaveText)
        if (leaveMsg && conversation.conversationId) {
          setTimeout(() => {
            ChatRepo.sendMessage(leaveMsg, conversation.conversationId!)
              .catch((err: BusinessError) => {
                Logger.error('ChatKitUI', "net ease send message error", err.code, err.message);
                sendMessageFailedTips(leaveMsg, err, conversation.conversationId!)
              })
          }, 200)
        }
      }
    })
  }

  // 重置搜索结果
  reset() {
    this.messageList = []
    this.messageInfoList = []
    this.groupedMessageList = []
    this.pageToken = undefined
    this.hasMore = true
    this.isLoading = false
  }

  // 删除消息回调
  private onDeleteFun = (deleteNotifications: V2NIMMessageDeletedNotification[]) => {
    for (const deleteNotification of deleteNotifications) {
      if (deleteNotification.messageRefer.conversationId === this.conversationId) {
        // 从原始消息列表中移除
        this.messageList = this.messageList.filter(
          item => item.messageClientId !== deleteNotification.messageRefer.messageClientId
        )
        // 从分组中移除
        for (const group of this.groupedMessageList) {
          group.messages = group.messages.filter(
            item => item.message.messageClientId !== deleteNotification.messageRefer.messageClientId
          )
        }
        // 移除空的分组
        this.groupedMessageList = this.groupedMessageList.filter(group => group.messages.length > 0)
      }
    }
    this.revokeAndeDeleteMission = true
  }

  // 撤回消息回调
  private onRevokeFun = (revokeNotifications: V2NIMMessageRevokeNotification[]) => {
    for (const revokeNotification of revokeNotifications) {
      if (revokeNotification.messageRefer.conversationId === this.conversationId) {
        // 从原始消息列表中移除
        this.messageList = this.messageList.filter(
          item => item.messageClientId !== revokeNotification.messageRefer.messageClientId
        )
        // 从分组中移除
        for (const group of this.groupedMessageList) {
          group.messages = group.messages.filter(
            item => item.message.messageClientId !== revokeNotification.messageRefer.messageClientId
          )
        }
        // 移除空的分组
        this.groupedMessageList = this.groupedMessageList.filter(group => group.messages.length > 0)
      }
    }
    this.revokeAndeDeleteMission = true
  }

  // 重置删除/撤回标志
  public resetRevokeAndeDeleteMission(): void {
    this.revokeAndeDeleteMission = false
  }
}
