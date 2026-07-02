/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { Logger } from '@nimkit/common';
import {
  ChatKitClient,
  ChatRepo,
  ContactRepo,
  IMKitConfigCenter,
  NEUserWithFriend,
  TeamMemberWithUser,
  TeamRepo
} from '@nimkit/chatkit'
import {
  V2NIMConversationType,
  V2NIMMessage,
  V2NIMMessageDeletedNotification,
  V2NIMMessageRevokeNotification,
  V2NIMMessageSearchExParams,
  V2NIMMessageSearchResult,
  V2NIMMessageType,
  V2NIMSearchDirection,
  V2NIMTeamMember,
  V2NIMTeamType,
  V2NIMUser
} from '@nimsdk/base'
import { HashMap } from '@kit.ArkTS'
import { SearchFTSHistory } from '../model/SearchFTSHistory'
import { assign } from '@nimsdk/base'

/**
 * 统一的全文搜索历史消息 ViewModel
 * 同时支持 P2P 和 Team 场景
 */
@ObservedV2
export class SearchFTSHistoryViewModel {
  conversationId: string
  conversationType: V2NIMConversationType

  // Team 相关
  teamId?: string
  teamType: V2NIMTeamType = V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL
  mineTeamMember?: V2NIMTeamMember
  teamMemberList: TeamMemberWithUser[] = []
  teamUserCache: HashMap<string, V2NIMUser> = new HashMap()

  // P2P 相关
  mineUserWithFriend?: NEUserWithFriend
  userWithFriendList: NEUserWithFriend[] = []

  @Trace historyList: SearchFTSHistory[] = []
  @Trace hasMore: boolean = false
  @Trace revokeAndeDeleteMission = false

  public pageToken: string | undefined = undefined

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
   * 全文检索
   * @param keyword 关键字
   * @param firstPage 是否是第一页，如果是则清空历史消息
   */
  async searchHistoryMessages(keyword: string, firstPage: boolean): Promise<void> {
    if (firstPage) {
      this.clearHistoryMessages()
    } else if (!this.hasMore || !this.pageToken) {
      return
    }

    try {
      const param: V2NIMMessageSearchExParams = {
        keywordList: [keyword],
        conversationId: this.conversationId,
        messageTypes: [
          V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT,
          V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE,
          V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO,
          V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE,
          V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM
        ],
        direction: V2NIMSearchDirection.V2NIM_SEARCH_DIRECTION_BACKWARD,
        limit: 100,
        pageToken: this.pageToken,
      }

      let searchResult: V2NIMMessageSearchResult | undefined = undefined
      if (IMKitConfigCenter.enableCloudSearch) {
        searchResult = await ChatRepo.searchCloudMessagesEx(param)
      } else {
        searchResult = await ChatRepo.searchLocalMessages(param)
      }
      if (!searchResult) {
        return
      }

      if (!searchResult) {
        return
      }

      let messages: V2NIMMessage[] = []
      for (const item of searchResult.items) {
        if (item.conversationId === this.conversationId) {
          messages = item.messages
          break
        }
      }

      this.pageToken = searchResult.nextPageToken
      this.hasMore = searchResult.hasMore

      const accountList = messages.map(msg => msg.senderId)

      // 根据会话类型获取用户信息
      if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        await this.getTeamMemberByIds(accountList)
      } else {
        await this.getUserWithFriendByIds(accountList)
      }

      // 构建历史消息列表
      for (const message of messages) {
        let model: SearchFTSHistory
        if (this.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
          const member = this.teamMemberList.find(m => m.getAccId() === message.senderId)
          let user: V2NIMUser | undefined = undefined
          if (!member) {
            user = await this.getTeamUser(message.senderId)
          }
          model = SearchFTSHistory.createForTeam(keyword, message, member, user)
        } else {
          const member = this.userWithFriendList.find(m => m.getAccId() === message.senderId)
          model = SearchFTSHistory.createForP2P(keyword, message, member)
        }
        this.historyList.push(model)
      }
    } catch (err) {
      Logger.error('ChatKitUI', err)
    }
  }

  clearHistoryMessages() {
    this.historyList = []
    this.resetSearchResult()
  }

  resetSearchResult() {
    this.pageToken = undefined
    this.hasMore = false
  }

  // ========== P2P 用户信息获取 ==========

  async getUserWithFriendByIds(accountList: string[]) {
    const loadedAccountList: string[] = this.userWithFriendList.map(u => u.getAccId())
    const fetchAccountIds: string[] = accountList.filter(account => !loadedAccountList.includes(account))
    try {
      const newList: NEUserWithFriend[] = await ContactRepo.getUserWithFriendByIds(fetchAccountIds)
      this.userWithFriendList.push(...newList)

      const mine: NEUserWithFriend | undefined = this.userWithFriendList.find((u) => {
        u.getAccId() === ChatKitClient.getLoginUserId()
      })
      if (mine) {
        this.mineUserWithFriend = mine
      } else {
        this.getMineUserWithFriend()
      }
    } catch (err) {
      Logger.error('ChatKitUI', err)
    }
  }

  getMineUserWithFriend() {
    ContactRepo.getUserWithFriendByIds([ChatKitClient.getLoginUserId()])
      .then((users) => {
        if (users.length > 0) {
          this.mineUserWithFriend = users[0]
        }
      })
  }

  // ========== Team 群成员信息获取 ==========

  async getTeamMemberByIds(accountList: string[]) {
    if (!accountList || accountList.length === 0 || !this.teamId) {
      return
    }

    accountList = Array.from(new Set(accountList))
    if (accountList.length === 0) {
      return
    }

    const loadedAccountList = this.teamMemberList.map(member => member.teamMember.accountId)
    const fetchAccountIds = accountList.filter(account => !loadedAccountList.includes(account))
    try {
      let teamMemberList = await TeamRepo.getTeamMembersByIds(this.teamId, this.teamType, fetchAccountIds)
      this.teamMemberList.push(...teamMemberList)

      let mine = teamMemberList.find(member => member.getAccId() === ChatKitClient.getLoginUserId())?.teamMember
      if (mine) {
        this.mineTeamMember = mine
      } else {
        this.getMineTeamMember()
      }
    } catch (err) {
      Logger.error('ChatKitUI', err)
    }
  }

  getMineTeamMember() {
    if (!this.teamId) {
      return
    }
    TeamRepo.getTeamMemberListByIds(this.teamId, this.teamType, [ChatKitClient.getLoginUserId()])
      .then((members) => {
        if (members.length > 0) {
          this.mineTeamMember = members[0]
        }
      })
  }

  private async getTeamUser(accountId: string): Promise<V2NIMUser | undefined> {
    if (this.teamUserCache.hasKey(accountId)) {
      return this.teamUserCache.get(accountId)
    } else {
      try {
        const userList = await ContactRepo.getUserListFromCloud([accountId])
        if (userList.length > 0) {
          this.teamUserCache.set(accountId, userList[0])
          return userList[0]
        } else {
          return undefined
        }
      } catch (err) {
        return undefined
      }
    }
  }

  // ========== 消息删除/撤回监听 ==========

  private onDeleteFun = (deleteNotifications: V2NIMMessageDeletedNotification[]) => {
    for (const deleteNotification of deleteNotifications) {
      if (deleteNotification.messageRefer.conversationId === this.conversationId) {
        this.historyList = this.historyList.filter((item) => {
          return item.message.messageClientId !== deleteNotification.messageRefer.messageClientId
        })
      }
    }
    this.revokeAndeDeleteMission = true
  }

  // 撤回消息回调
  private onRevokeFun = (revokeNotifications: V2NIMMessageRevokeNotification[]) => {
    for (const revokeNotification of revokeNotifications) {
      if (revokeNotification.messageRefer.conversationId === this.conversationId) {
        // 找到被撤回的消息，修改其 text 为已撤回
        let revokeIndex: number = -1
        for (let i = 0; i < this.historyList.length; i++) {
          if (this.historyList[i].message.messageClientId === revokeNotification.messageRefer.messageClientId) {
            revokeIndex = i
            break;
          }
        }
        if (revokeIndex < 0) {
          continue;
        }
        // 创建新的 message 对象副本，替换整个引用以触发 @Trace 响应式更新
        const oldMessage = this.historyList[revokeIndex].message
        const newMessage: V2NIMMessage = assign({}, oldMessage)
        newMessage.text = getContext().resourceManager.getStringByNameSync('chat_msg_undo_tips')
        // 替换整个 message 对象引用，触发 UI 更新
        setTimeout(() => {
          this.historyList[revokeIndex].message = newMessage
        }, 200)
      }
    }
    this.revokeAndeDeleteMission = true
  }

  public resetRevokeAndeDeleteMission(): void {
    this.revokeAndeDeleteMission = false
  }
}
