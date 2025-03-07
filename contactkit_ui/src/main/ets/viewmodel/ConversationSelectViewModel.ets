/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ConversationRepo, IMKitConfigCenter, LocalConversationRepo } from '@nimkit/chatkit'
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel'
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

  constructor() {
  }

  /// 加载数据
  /// - Parameters:
  ///   - filters: 需要过滤的会话id列表
  async loadData(filters?: string[]) {
    try {
      await this.getContactList(filters)
      await this.getTeamList(filters)
      await this.getConversationList(filters)
    } catch (err) {
      console.error(err)
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
          // 过滤数据
          if (filters) {
            localConversations.filter(conversation => !filters.includes(conversation.conversationId))
          }

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
          // 过滤数据
          if (filters) {
            conversations.filter(conversation => !filters.includes(conversation.conversationId))
          }

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
      console.error(err)
    }
  }

  /// 获取好友列表
  /// - Parameters:
  ///   - filters: 需要过滤的好友id列表
  async getContactList(filters?: string[]) {
    try {
      const contactSections = await this.contactViewModel.getFriendList()

      if (contactSections) {
        for (const section of contactSections) {
          let contacts = section.contacts.contacts
          // 过滤数据
          if (filters) {
            contacts.filter(contact => !filters.includes(contact.user?.accountId ?? ""))
          }

          for (const contact of contacts) {
            let model = new ConversationSelectModel()
            model.conversationId = ChatKitClient.nim.conversationIdUtil.p2pConversationId(contact.user?.accountId)
            model.name = contact.showName()
            model.avatar = contact.user?.avatar
            this.contactList.push(model)
          }
        }
      }
    } catch (err) {
      console.error(err)
    }
  }

  /// 获取群聊列表
  /// - Parameters:
  ///   - filters: 需要过滤的群id列表
  async getTeamList(filters?: string[]) {
    try {
      await this.teamViewModel.getJoinedTeamList()
      let teams = this.teamViewModel.teamList
      // 过滤数据
      if (filters) {
        teams.filter(team => !filters.includes(team.teamId))
      }

      for (const team of teams) {
        let model = new ConversationSelectModel()
        model.conversationId = ChatKitClient.nim.conversationIdUtil.teamConversationId(team.teamId)
        model.name = team.name
        model.avatar = team.avatar
        model.memberCount = team.memberCount
        this.teamList.push(model)
      }
    } catch (err) {
      console.error(err)
    }
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