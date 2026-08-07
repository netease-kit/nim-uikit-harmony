/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatKitClient, ConversationRepo, IMKitConfigCenter, LocalConversationRepo, UserAIBotManager } from '@nimkit/chatkit'
import { ConversationSelectModel } from '@nimkit/chatkit'
import { V2NIMConversationType, V2NIMGetUserAIBotListResult, V2NIMUserAIBot } from '@nimsdk/base'
import { ContactViewModel } from './ContactViewModel'
import { MyTeamsViewModel } from './MyTeamsViewModel'


@ObservedV2
export class ConversationSelectViewModel {
  contactViewModel: ContactViewModel = new ContactViewModel()
  teamViewModel: MyTeamsViewModel = new MyTeamsViewModel()
  conversationLimit: number = 100 // 最近会话最大数量
  @Trace conversationList: ConversationSelectModel[] = [] // 最近会话缓存
  @Trace contactList: ConversationSelectModel[] = [] // 好友缓存
  @Trace teamList: ConversationSelectModel[] = [] // 群组缓存
  private userAIBotAccids: Set<string> = new Set<string>()

  constructor() {
  }

  /// 加载数据
  /// - Parameters:
  ///   - filters: 需要过滤的会话id列表
  async loadData(filters?: string[]) {
    try {
      await this.loadUserAIBotAccids()
      await this.getContactList(filters)
      await this.getTeamList(filters)
      await this.getConversationList(filters)
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  /// 获取会话列表
  /// - Parameters:
  ///   - filters: 需要过滤的会话id列表
  async getConversationList(filters?: string[]) {
    try {
      if (IMKitConfigCenter.enableLocalConversation) {
        const conversationLocalResult = await LocalConversationRepo.getConversationList(0, this.conversationLimit)
        let localConversations = conversationLocalResult?.conversationList
        if (localConversations) {
          localConversations =
            localConversations.filter(conversation => !this.shouldFilterConversation(conversation.conversationId,
              filters))

          for (const conversation of localConversations) {
            // 校验好友是否已存在
            let contactModel = this.findContact(conversation.conversationId)
            if (contactModel) {
              this.conversationList.push(contactModel)
              continue
            }

            // 校验群聊是否已存在
            let teamModel = this.findTeam(conversation.conversationId)
            if (teamModel) {
              this.conversationList.push(teamModel)
              continue
            }

            let model = new ConversationSelectModel()
            model.conversationId = conversation.conversationId
            model.name = conversation.name
            model.avatar = conversation.avatar
            this.conversationList.push(model)
          }
        }
      } else {
        const conversationResult = await ConversationRepo.getConversationList(0, this.conversationLimit)
        let conversations = conversationResult?.conversationList
        if (conversations) {
          conversations =
            conversations.filter(conversation => !this.shouldFilterConversation(conversation.conversationId, filters))

          for (const conversation of conversations) {
            // 校验好友是否已存在
            let contactModel = this.findContact(conversation.conversationId)
            if (contactModel) {
              this.conversationList.push(contactModel)
              continue
            }

            // 校验群聊是否已存在
            let teamModel = this.findTeam(conversation.conversationId)
            if (teamModel) {
              this.conversationList.push(teamModel)
              continue
            }

            let model = new ConversationSelectModel()
            model.conversationId = conversation.conversationId
            model.name = conversation.name
            model.avatar = conversation.avatar
            this.conversationList.push(model)
          }
        }
      }
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  /// 获取好友列表
  /// - Parameters:
  ///   - filters: 需要过滤的好友id列表
  async getContactList(filters?: string[]) {
    try {
      const contactSections = await this.contactViewModel.getFriendList(this.mergeFiltersWithUserAIBots(filters))

      if (contactSections) {
        const removedAccountIds: string[] = []
        for (const section of contactSections) {
          let contacts = section.contacts.contacts

          for (const contact of contacts) {
            const accountId = contact.user?.accountId
            if (this.shouldFilterAccount(accountId, filters)) {
              if (accountId && !removedAccountIds.includes(accountId)) {
                removedAccountIds.push(accountId)
              }
              continue
            }
            let model = new ConversationSelectModel()
            model.conversationId = ChatKitClient.nim.conversationIdUtil.p2pConversationId(contact.user?.accountId)
            model.name = contact.showName()
            model.avatar = contact.user?.avatar
            this.contactList.push(model)
          }
        }
        removedAccountIds.forEach((accountId: string) => {
          this.contactViewModel.removeFromContact(accountId)
        })
      }
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  /// 获取群聊列表
  /// - Parameters:
  ///   - filters: 需要过滤的群id列表
  async getTeamList(filters?: string[]) {
    try {
      await this.teamViewModel.getJoinedTeamList()
      let teams = this.teamViewModel.teamList
      teams = teams.filter(team => !this.isFilteredId(team.teamId, filters))

      for (const team of teams) {
        let model = new ConversationSelectModel()
        model.conversationId = ChatKitClient.nim.conversationIdUtil.teamConversationId(team.teamId)
        model.name = team.name
        model.avatar = team.avatar
        model.memberCount = team.memberCount
        this.teamList.push(model)
      }
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  private async loadUserAIBotAccids(): Promise<void> {
    this.userAIBotAccids.clear()
    try {
      let pageToken: string | undefined = undefined
      let hasMore = true

      while (hasMore) {
        const result: V2NIMGetUserAIBotListResult | undefined = await UserAIBotManager.getUserAIBotList(
          pageToken ? { pageToken: pageToken, limit: 100 } : { limit: 100 }
        )
        if (result?.bots) {
          for (const bot of result.bots) {
            this.addUserAIBotAccid(bot)
          }
        }
        hasMore = result?.hasMore ?? false
        pageToken = result?.nextToken
        if (hasMore && !pageToken) {
          hasMore = false
        }
      }
    } catch (err) {
      Logger.error('ContactKit', 'ConversationSelectViewModel loadUserAIBotAccids error: ' + JSON.stringify(err))
    }
  }

  private addUserAIBotAccid(bot?: V2NIMUserAIBot): void {
    if (!bot?.accid) {
      return
    }
    this.userAIBotAccids.add(bot.accid)
  }

  private isFilteredId(id?: string, filters?: string[]): boolean {
    return !!id && !!filters && filters.includes(id)
  }

  private isUserAIBotAccount(accountId?: string): boolean {
    if (!accountId) {
      return false
    }
    return this.userAIBotAccids.has(accountId) ||
      UserAIBotManager.hasCachedUserAIBot(accountId) ||
      UserAIBotManager.isDeletedUserAIBot(accountId)
  }

  private shouldFilterAccount(accountId?: string, filters?: string[]): boolean {
    return this.isFilteredId(accountId, filters) || this.isUserAIBotAccount(accountId)
  }

  private shouldFilterConversation(conversationId?: string, filters?: string[]): boolean {
    if (!conversationId) {
      return true
    }
    if (this.isFilteredId(conversationId, filters)) {
      return true
    }
    const conversationType = ChatKitClient.nim.conversationIdUtil.parseConversationType(conversationId)
    if (conversationType !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      return false
    }
    const targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    return this.isUserAIBotAccount(targetId)
  }

  private mergeFiltersWithUserAIBots(filters?: string[]): string[] {
    const result: string[] = []
    filters?.forEach((filter: string) => {
      if (filter && !result.includes(filter)) {
        result.push(filter)
      }
    })
    this.userAIBotAccids.forEach((accid: string) => {
      if (accid && !result.includes(accid)) {
        result.push(accid)
      }
    })
    return result
  }

  /// 在好友缓存中查找该会话
  /// - Parameter conversationId: 会话id
  /// - Returns: 存在则返回该回话，不存在返回 nil
  findContact(conversationId: string): ConversationSelectModel | undefined {
    return this.contactList.find(contactModel => contactModel.conversationId === conversationId)
  }

  /// 在群聊缓存中查找该会话
  /// - Parameter conversationId: 会话id
  /// - Returns: 存在则返回该回话，不存在返回 nil
  findTeam(conversationId: string): ConversationSelectModel | undefined {
    return this.teamList.find(teamModel => teamModel.conversationId === conversationId)
  }

  onDestroy() {
    this.contactViewModel.onDestroy()
    this.teamViewModel.onDestroy()
  }
}
