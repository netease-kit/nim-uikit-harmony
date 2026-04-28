/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, TeamRepo } from '@nimkit/chatkit'
import {
  V2NIMConversationType,
  V2NIMFriendDeletionType,
  V2NIMTeam,
  V2NIMTeamType,
  V2NIMUser
} from '@nimsdk/base'
import { Constant } from '../loader/Constant'
import { ConversationModel } from '../model/ConversationModel'
import { AitServer, AitSession, AitSessionChangeEvent } from '../service/ait/AitService'
import { ConversationItem, ConversationStrategy } from '../strategy/ConversationStrategy'
import ConversationData from './ConversationData'

@ObservedV2
export class ConversationViewModel {
  @Trace isFinishedSyncLoad: boolean = false
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  @Trace aitConversationList: Set<string> = new Set()
  public onUreadMessageChange?: (unreadCount?: number) => void = undefined
  public data: ConversationData<ConversationItem> = new ConversationData<ConversationItem>()
  public isFinished: boolean = false
  private offset: number = 0
  private limit: number = Constant.PAGE_SIZE
  private hasLoadedInitialConversation: boolean = false
  private isLoadingInitialConversation: boolean = false
  private model: ConversationModel

  constructor(strategy: ConversationStrategy) {
    this.model = new ConversationModel(strategy)
  }

  initConversation() {
    this.loadConversation()
    this.setupEventHandler()
    this.loadAitSessions()
  }

  public async stickTopConversation(conversationId: string, stickTop: boolean) {
    await this.model.stickTopConversation(conversationId, stickTop)
  }

  public async deleteConversation(conversationId: string) {
    await this.model.deleteConversation(conversationId)
    const index = this.data.conversationList?.findIndex((m) => m.conversationId == conversationId)
    if (index > -1) {
      this.data.removeData(index)
    }
  }

  public requiresNetworkForDelete(): boolean {
    return this.model.requiresNetworkForDelete()
  }

  public async loadMoreConversation() {
    const result = await this.model.getConversationList(this.offset, this.limit)
    if (result && result.conversationList.length > 0) {
      this.offset = result.offset
      this.isFinished = result.finished
      let newConversation = this.snapshotConversations(result.conversationList)
      if (this.data.conversationList.length > 0 && newConversation.length > 0) {
        this.data.conversationList =
          this.data.conversationList.filter(conversation => !newConversation.find((m) => m.conversationId ===
          conversation.conversationId))
      }

      newConversation.forEach((conversation) => {
        this.data.conversationList.push(conversation)
      })
      this.data.conversationList?.sort((a, b) => this.sortConversation(a, b))
      this.data.reloadData()
    }
  }

  private async updateConversationById(conversationId: string) {
    const newConversation = await this.model.getConversation(conversationId)
    if (newConversation) {
      const index = this.data.conversationList.findIndex(c => c.conversationId === newConversation.conversationId)
      if (index > -1) {
        this.upsertConversation(newConversation)
        this.data.reloadData()
      }
    }
  }

  private async addTeamConversation(conversation: ConversationItem) {
    const teamId = this.model.parseConversationTargetId(conversation.conversationId)
    const team = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
    if (team?.isValidTeam && !this.data.conversationList.some(m => m.conversationId === conversation.conversationId)) {
      this.addConversation(conversation)
    } else {
      this.deleteConversation(conversation.conversationId)
    }
  }

  private setupEventHandler() {
    this.model.onSyncStartedHandle = async () => {
      if (!this.hasLoadedInitialConversation) {
        await this.loadConversation()
      }
    }

    this.model.onSyncFinishedHandle = async () => {
      await this.reloadConversation()
      this.isFinishedSyncLoad = true
    }

    this.model.onSyncFailedHandle = async () => {
      await this.reloadConversation()
      this.isFinishedSyncLoad = true
    }

    this.model.onNetBrokenHandle = (networkBroken: boolean) => {
      this.networkBroken = networkBroken
    }
    //好友信息变更修改
    this.model.onFriendInfoChangedHandler = async (accountId: string) => {
      await this.updateConversationById(this.model.p2pConversationId(accountId))
    }
    //用户信息变更修改（昵称、头像等）
    this.model.onUserProfileChangedHandler = async (users: V2NIMUser[]) => {
      for (const user of users) {
        await this.updateConversationById(this.model.p2pConversationId(user.accountId))
      }
    }
    //好友删除，别名不存在需要更新
    this.model.onFriendDeletedHandler = async (accountId: string, deletionType: V2NIMFriendDeletionType) => {
      await this.updateConversationById(this.model.p2pConversationId(accountId))
    }

    // 群解散
    this.model.onTeamDismissedHandler = (team: V2NIMTeam) => {
      this.deleteConversation(this.model.teamConversationId(team.teamId))
    }
    // 退出群
    this.model.onTeamLeftHandler = (team: V2NIMTeam) => {
      this.deleteConversation(this.model.teamConversationId(team.teamId))
    }
    // 会话未读数变化
    this.model.onTotalUnreadCountChangedHandler = (unreadCount: number) => {
      if (this.onUreadMessageChange) {
        this.onUreadMessageChange(unreadCount)
      }
    }
    this.model.onConversationCreatedHandler = (conversation: ConversationItem) => {
      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        this.addTeamConversation(conversation)
      } else if (!this.data.conversationList.some(m => m.conversationId === conversation.conversationId)) {
        this.addConversation(conversation)
      }
    }
    this.model.onConversationDeletedHandler = (conversationIds: string[]) => {
      const indices
        = conversationIds.map(conversationId => this.data.conversationList.findIndex(conversation => conversation.conversationId
        === conversationId)
      );
      indices.map(index => this.data.removeData(index))
    }
    this.model.onConversationChangedHandler = (updateList: ConversationItem[]) => {
      let needReload = false
      updateList.forEach(changedItem => {
        const index = this.data.conversationList?.findIndex(conversation =>
        conversation.conversationId === changedItem.conversationId)

        if (index !== undefined && index > -1) {
          this.upsertConversation(changedItem)
          needReload = true
        } else if (changedItem.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
          this.addTeamConversation(changedItem)
        } else {
          this.upsertConversation(changedItem)
          needReload = true
        }
      }
      );
      if (needReload) {
        this.data.reloadData()
      }
    }
    getContext().eventHub.on(AitSessionChangeEvent, (session: AitSession) => {
      if (session.isAit) {
        this.aitConversationList.add(session.sessionId)
      } else if (this.aitConversationList.has(session.sessionId)) {
        this.aitConversationList.delete(session.sessionId)
      }
    })

    this.model.addEventListener()
  }

  private async loadConversation() {
    if (this.isLoadingInitialConversation) {
      return
    }

    this.isLoadingInitialConversation = true
    try {
      const result = await this.model.getConversationList(this.offset, this.limit)
      if (result != null) {
        this.hasLoadedInitialConversation = true
      }

      if (result != null && result.conversationList.length > 0) {
        this.offset = result.offset
        this.isFinished = result.finished
        let newConversation = this.snapshotConversations(result.conversationList)
        if (this.data.conversationList.length > 0 && newConversation.length > 0) {
          this.data.conversationList =
            this.data.conversationList.filter(conversation => !newConversation.find((m) => m.conversationId ===
            conversation.conversationId))
        }

        newConversation.forEach((conversation) => {
          this.data.conversationList.push(conversation)
        })
        this.data.conversationList?.sort((a, b) => this.sortConversation(a, b))
        this.data.reloadData()
      }
    } finally {
      this.isLoadingInitialConversation = false
    }
  }

  private async reloadConversation() {
    this.offset = 0;
    const result = await this.model.getConversationList(this.offset, this.limit)
    if (result) {
      const conversationList = this.snapshotConversations(result.conversationList)
      this.hasLoadedInitialConversation = true
      this.offset = result.offset
      this.isFinished = result.finished
      this.data.conversationList = conversationList
      this.data.conversationList?.sort((a, b) => this.sortConversation(a, b))
      this.data.reloadData()
      this.ensureP2PUserInfo(conversationList)
    }
  }

  private async ensureP2PUserInfo(conversations: ConversationItem[]) {
    const missingUserInfoAccountIds = conversations
      .filter((conversation) => {
        if (conversation.type !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
          return false
        }
        const targetId = this.model.parseConversationTargetId(conversation.conversationId)
        return !conversation.name || conversation.name === targetId
      })
      .map((conversation) => this.model.parseConversationTargetId(conversation.conversationId))

    if (missingUserInfoAccountIds.length > 0) {
      try {
        await ContactRepo.getUserListFromCloud(missingUserInfoAccountIds)
      } catch (e) {
        console.error(`ensureP2PUserInfo failed: ${e}`)
      }
    }
  }

  private addConversation(conversation: ConversationItem) {
    const snapshotConversation = this.snapshotConversation(conversation)
    const insertIndex = this.findConversationInsertIndex(snapshotConversation)
    this.data.addData(insertIndex, snapshotConversation)
  }

  private upsertConversation(conversation: ConversationItem) {
    const snapshotConversation = this.snapshotConversation(conversation)
    const existIndex = this.data.conversationList.findIndex(item => item.conversationId === snapshotConversation.conversationId)
    if (existIndex > -1) {
      this.data.conversationList.splice(existIndex, 1)
    }
    const insertIndex = this.findConversationInsertIndex(snapshotConversation)
    this.data.conversationList.splice(insertIndex, 0, snapshotConversation)
  }

  private findConversationInsertIndex(conversation: ConversationItem): number {
    let insertIndex = this.data.conversationList.length
    for (let i = 0; i < this.data.conversationList.length; i++) {
      if (conversation.sortOrder > this.data.conversationList[i].sortOrder) {
        insertIndex = i
        break
      }
    }
    return insertIndex
  }

  private loadAitSessions() {
    AitServer.instance.getAllAitSession(ChatKitClient.getLoginUserId()).then((
      aitSessions: string[]
    ) => {
      aitSessions.forEach((session) => {
        this.aitConversationList.add(session)
      })
    })
  }

  private sortConversation(a: ConversationItem, b: ConversationItem): number {
    return b.sortOrder - a.sortOrder
  }

  private snapshotConversations(conversations: ConversationItem[]): ConversationItem[] {
    return conversations.map(conversation => this.snapshotConversation(conversation))
  }

  private snapshotConversation(conversation: ConversationItem): ConversationItem {
    return JSON.parse(JSON.stringify(conversation)) as ConversationItem
  }
}
