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
  ContactRepo,
  NEUserWithFriend,
  TeamMemberWithUser,
  TeamRepo
} from '@nimkit/chatkit'
import {
  V2NIMConversationType,
  V2NIMMessage,
  V2NIMMessageDeletedNotification,
  V2NIMMessageListOption,
  V2NIMMessageListResult,
  V2NIMMessageRevokeNotification,
  V2NIMQueryDirection,
  V2NIMTeamType,
  V2NIMUser
} from '@nimsdk/base'
import { HashMap } from '@kit.ArkTS'
import { SearchDateMessage } from '../model/SearchDateMessage'

/**
 * 日期搜索消息页面参数
 */
export interface ChatSearchDateMessageParams {
  conversationId: string
}

/**
 * 按日期分组的消息
 */
@ObservedV2
export class DateGroupedMessages {
  @Trace dateString: string // 如 "2024年1月15日"
  @Trace messages: SearchDateMessage[] = []

  constructor(dateString: string) {
    this.dateString = dateString
  }
}

/**
 * 日期搜索消息 ViewModel
 * 支持 P2P 和 Team 会话
 */
@ObservedV2
export class ChatSearchDateMessageViewModel {
  conversationId: string
  conversationType: V2NIMConversationType
  teamId: string = ''
  teamType: V2NIMTeamType = V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL

  // P2P 用户信息缓存
  userWithFriendList: NEUserWithFriend[] = []
  // Team 成员信息缓存
  teamMemberList: TeamMemberWithUser[] = []
  teamUserCache: HashMap<string, V2NIMUser> = new HashMap()

  // 搜索时间范围
  @Trace searchStartTime: number = 0 // 搜索开始时间戳（毫秒）
  @Trace searchEndTime: number = 0   // 搜索结束时间戳（毫秒）

  // 分页相关
  @Trace hasMore: boolean = false
  public pageToken: string | undefined = undefined

  // 按日期分组的消息列表
  @Trace groupedMessageList: DateGroupedMessages[] = []

  @Trace revokeAndeDeleteMission = false

  constructor(conversationId: string) {
    this.conversationId = conversationId
    this.conversationType = ChatKitClient.nim.conversationIdUtil.parseConversationType(conversationId)

    // 如果是群聊，解析 teamId
    if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
      this.teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    }

    // 注册消息删除监听
    ChatRepo.onDeleteMessage(this.onDeleteFun)
    // 注册消息撤回监听
    ChatRepo.onRevokeMessage(this.onRevokeFun)
  }

  /**
   * 设置搜索的日期范围
   * @param startTime 开始时间戳（毫秒）
   * @param endTime 结束时间戳（毫秒）
   */
  setDateRange(startTime: number, endTime: number) {
    this.searchStartTime = Math.max(1, startTime)
    this.searchEndTime = endTime
  }

  // 用于分页的锚点消息
  private anchorMessage: V2NIMMessage | undefined = undefined

  /**
   * 按日期搜索消息
   * 使用 getMessageListEx 接口，从目标时间往更大时间方向查询最近的消息
   * @param firstPage 是否是第一页
   */
  async searchMessagesByDate(firstPage: boolean): Promise<void> {
    if (firstPage) {
      this.clearMessages()
      this.anchorMessage = undefined
    } else if (!this.hasMore) {
      return
    }

    if (this.searchStartTime === 0) {
      return
    }

    try {
      // 使用 getMessageListEx 接口
      // direction: DESC 表示从 beginTime 往更大时间方向查询
      const option: V2NIMMessageListOption = {
        conversationId: this.conversationId,
        beginTime: this.searchStartTime,  // 选中日期的 00:00:00
        endTime: this.searchEndTime,       // 结束时间（当前时间或指定结束时间）
        limit: 1,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC, // 从 beginTime 往更大时间方向查询
        anchorMessage: this.anchorMessage,
        strictMode: false,
        onlyQueryLocal: false
      }

      const result: V2NIMMessageListResult = await ChatRepo.getMessageListEx(option)

      if (!result || !result.messages || result.messages.length === 0) {
        this.hasMore = false
        // 向后搜索无结果时，向前（DESC）搜索一条消息作为锚点
        if (firstPage) {
          await this.searchAnchorMessageDesc()
        }
        return
      }

      const messages: V2NIMMessage[] = result.messages
      this.hasMore = result.messages.length > 0

      // 保存最后一条消息作为下次分页的锚点
      if (messages.length > 0) {
        this.anchorMessage = messages[0] // 第 0 条最接近日期时间
      }

      // 根据会话类型获取用户信息
      const accountList = messages.map(msg => msg.senderId)
      if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        await this.getUserWithFriendByIds(accountList)
      } else if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        await this.getTeamMemberByIds(accountList)
      }

      // 构建消息模型并按日期分组
      for (const message of messages) {
        const dateKey = this.formatDateKey(message.createTime)
        let group = this.groupedMessageList.find(g => g.dateString === dateKey)
        if (!group) {
          group = new DateGroupedMessages(dateKey)
          this.groupedMessageList.push(group)
        }

        // 根据会话类型创建消息模型
        let searchDateMessage: SearchDateMessage
        if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
          const userWithFriend = this.userWithFriendList.find(u => u.getAccId() === message.senderId)
          searchDateMessage = new SearchDateMessage(message, userWithFriend, undefined, undefined)
        } else {
          const teamMember = this.teamMemberList.find(m => m.getAccId() === message.senderId)
          let user: V2NIMUser | undefined = undefined
          if (!teamMember) {
            user = await this.getTeamUser(message.senderId)
          }
          searchDateMessage = new SearchDateMessage(message, undefined, teamMember, user)
        }

        group.messages.push(searchDateMessage)
      }

      // 按日期排序（最新的在前）
      this.groupedMessageList.sort((a, b) => {
        const dateA = this.parseDateKey(a.dateString)
        const dateB = this.parseDateKey(b.dateString)
        return dateB - dateA
      })

    } catch (err) {
      Logger.error('ChatKitUI', 'searchMessagesByDate error:', err)
    }
  }

  /**
   * 获取好友 & 用户信息（P2P 会话使用）
   */
  async getUserWithFriendByIds(accountList: string[]) {
    if (!accountList || accountList.length === 0) {
      return
    }
    accountList = Array.from(new Set(accountList))
    const loadedAccountList = this.userWithFriendList.map(u => u.getAccId())
    const fetchAccountIds = accountList.filter(account => !loadedAccountList.includes(account))

    if (fetchAccountIds.length === 0) {
      return
    }

    try {
      const newList: NEUserWithFriend[] = await ContactRepo.getUserWithFriendByIds(fetchAccountIds)
      this.userWithFriendList.push(...newList)
    } catch (err) {
      Logger.error('ChatKitUI', 'getUserWithFriendByIds error:', err)
    }
  }

  /**
   * 获取群成员信息（Team 会话使用）
   */
  async getTeamMemberByIds(accountList: string[]) {
    if (!accountList || accountList.length === 0) {
      return
    }
    accountList = Array.from(new Set(accountList))
    const loadedAccountList = this.teamMemberList.map(member => member.teamMember.accountId)
    const fetchAccountIds = accountList.filter(account => !loadedAccountList.includes(account))

    if (fetchAccountIds.length === 0) {
      return
    }

    try {
      const teamMemberList = await TeamRepo.getTeamMembersByIds(this.teamId, this.teamType, fetchAccountIds)
      this.teamMemberList.push(...teamMemberList)
    } catch (err) {
      Logger.error('ChatKitUI', 'getTeamMemberByIds error:', err)
    }
  }

  /**
   * 获取用户信息（Team 会话兜底使用）
   */
  private async getTeamUser(accountId: string): Promise<V2NIMUser | undefined> {
    if (this.teamUserCache.hasKey(accountId)) {
      return this.teamUserCache.get(accountId)
    }

    try {
      const userList = await ContactRepo.getUserListFromCloud([accountId])
      if (userList.length > 0) {
        this.teamUserCache.set(accountId, userList[0])
        return userList[0]
      }
    } catch (err) {
      Logger.error('ChatKitUI', 'getTeamUser error:', err)
    }
    return undefined
  }

  clearMessages() {
    this.groupedMessageList = []
    this.pageToken = undefined
    this.hasMore = false
  }

  /**
   * 格式化日期为分组 key
   */
  private formatDateKey(timestamp: number): string {
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = date.getMonth() + 1
    const day = date.getDate()
    return `${year}年${month}月${day}日`
  }

  /**
   * 解析日期 key 为时间戳
   */
  private parseDateKey(dateKey: string): number {
    const match = dateKey.match(/(\d+)年(\d+)月(\d+)日/)
    if (match) {
      const year = parseInt(match[1])
      const month = parseInt(match[2]) - 1
      const day = parseInt(match[3])
      return new Date(year, month, day).getTime()
    }
    return 0
  }

  /**
   * 获取所有消息总数
   */
  getTotalMessageCount(): number {
    let count = 0
    for (const group of this.groupedMessageList) {
      count += group.messages.length
    }
    return count
  }

  // 删除消息回调
  private onDeleteFun = (deleteNotifications: V2NIMMessageDeletedNotification[]) => {
    for (const deleteNotification of deleteNotifications) {
      if (deleteNotification.messageRefer.conversationId === this.conversationId) {
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

  public resetRevokeAndeDeleteMission(): void {
    this.revokeAndeDeleteMission = false
  }

  /**
   * 向前（DESC 方向）搜索一条消息作为锚点
   * 当按日期搜索向后无结果时调用，用于定位到该日期最近的历史消息
   */
  private async searchAnchorMessageDesc(): Promise<void> {
    try {
      const option: V2NIMMessageListOption = {
        conversationId: this.conversationId,
        beginTime: 0,
        endTime: this.searchStartTime, // 从选中日期开始
        limit: 1,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC, // 向前查询
        anchorMessage: undefined,
        strictMode: false,
        onlyQueryLocal: false
      }

      const result: V2NIMMessageListResult = await ChatRepo.getMessageListEx(option)

      if (result?.messages?.length > 0) {
        const message = result.messages[0]
        // 设置锚点消息，用于后续在聊天页面定位
        this.anchorMessage = message

        // 获取用户信息
        const accountList = [message.senderId]
        if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
          await this.getUserWithFriendByIds(accountList)
        } else if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
          await this.getTeamMemberByIds(accountList)
        }

        // 构建消息模型并添加到 groupedMessageList
        const dateKey = this.formatDateKey(message.createTime)
        let group = this.groupedMessageList.find(g => g.dateString === dateKey)
        if (!group) {
          group = new DateGroupedMessages(dateKey)
          this.groupedMessageList.push(group)
        }

        let searchDateMessage: SearchDateMessage
        if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
          const userWithFriend = this.userWithFriendList.find(u => u.getAccId() === message.senderId)
          searchDateMessage = new SearchDateMessage(message, userWithFriend, undefined, undefined)
        } else {
          const teamMember = this.teamMemberList.find(m => m.getAccId() === message.senderId)
          let user: V2NIMUser | undefined = undefined
          if (!teamMember) {
            user = await this.getTeamUser(message.senderId)
          }
          searchDateMessage = new SearchDateMessage(message, undefined, teamMember, user)
        }

        group.messages.push(searchDateMessage)
      }
    } catch (err) {
      Logger.error('ChatKitUI', 'searchAnchorMessageDesc error:', err)
    }
  }

  /**
   * 获取锚点消息（用于外部页面定位）
   */
  public getAnchorMessage(): V2NIMMessage | undefined {
    return this.anchorMessage
  }
}
