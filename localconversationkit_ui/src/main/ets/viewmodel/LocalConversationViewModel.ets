/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, TeamRepo } from '@nimkit/chatkit'
import {
  V2NIMConversationType,
  V2NIMFriendDeletionType,
  V2NIMLocalConversation,
  V2NIMTeam,
  V2NIMTeamType
} from '@nimsdk/base'
import { Constant } from '../loader/Constant'
import { LocalConversationModel } from '../model/LocalConversationModel'
import { AitServer, AitSession, AitSessionChangeEvent } from '../service/ait/AitService'
import LocalConversationData from './LocalConversationData'

@ObservedV2
export class LocalConversationViewModel {
  // 同步完成
  @Trace isFinishedSyncLoad: boolean = false
  // 网络连接状态
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  //被@的会话
  @Trace aitConversationList: Set<string> = new Set()
  public onUreadMessageChange?: (unreadCount?: number) => void = undefined
  public data: LocalConversationData = new LocalConversationData()
  public isFinished: boolean = false
  //记录偏移量，下次请求使用
  private offset: number = 0
  //每次请求拉取的上限
  private limit: number = Constant.PAGE_SIZE
  private model: LocalConversationModel

  constructor() {
    this.model = new LocalConversationModel()
  }

  public initConversation() {
    //拉取缓存数据，快速显示
    this.loadConversation()
    //添加监听
    this.setupEventHandler()
    //获取数据库中所有的@数据
    this.loadAitSessions()
  }

  public async stickTopConversation(conversationId: string, stickTop: boolean) {
    await this.model.stickTopConversation(conversationId, stickTop)
  }

  /**
   * 删除会话
   * @param conversationId
   */
  public async deleteConversation(conversationId: string) {
    await this.model.deleteConversation(conversationId)
    //无论成功与否UI都删
    const index = this.data.conversationList?.findIndex((m) => m.conversationId == conversationId)
    if (index > -1) {
      this.data.removeData(index)
    }
  }

  //按照会话ID更新会话
  private async updateConversationById(conversationId: string) {
    const newConversation = await this.model.getConversation(conversationId)
    if (newConversation) {
      const index = this.data.conversationList.findIndex(
        c => c.conversationId === newConversation.conversationId
      )

      if (index > -1) {
        this.data.replaceData(index, newConversation)
      }
    }
  }

  //添加群会话
  private async addTeamConversation(conversation: V2NIMLocalConversation) {
    const teamId = this.model.parseConversationTargetId(conversation.conversationId)
    //添加之前判断是否合法team
    const team = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
    if (team?.isValidTeam && !this.data.conversationList.some(m => m.conversationId === conversation.conversationId)) {
      this.addConversation(conversation)
    } else {
      this.deleteConversation(conversation.conversationId)
    }
  }

  /**
   * 登陆后首次加载数据
   * @param offset
   */
  private async loadConversation() {
    const result = await this.model.getConversationList(this.offset, this.limit)
    if (result != null && result.conversationList.length > 0) {
      this.offset = result.offset
      this.isFinished = result.finished
      let newConversation = result.conversationList
      if (this.data.conversationList.length > 0 && newConversation.length > 0) {
        this.data.conversationList =
          this.data.conversationList.filter(conversation => !newConversation.find((m) => m.conversationId ===
          conversation.conversationId))
      }

      this.data.conversationList?.push(...newConversation)
      this.data.conversationList?.sort((a, b) => this.sortConversation(a, b))
      this.data.reloadData()
    }
  }
  /**
   * 同步完成后，重新加载数据
   * @param offset
   */
  private async reloadConversation() {
    this.offset = 0;
    const result = await this.model.getConversationList(this.offset, this.limit)
    if (result) {
      this.offset = result.offset
      this.isFinished = result.finished
      this.data.conversationList = result.conversationList
      this.data.conversationList?.sort((a, b) => this.sortConversation(a, b))
      this.data.reloadData()
    }
  }

  /**
   * 分页加载更多回话列表
   * @param offset
   */
  public async loadMoreConversation() {
    const result = await this.model.getConversationList(this.offset, this.limit)
    if (result && result.conversationList.length > 0) {
      this.offset = result.offset
      this.isFinished = result.finished
      let newConversation = result.conversationList
      if (this.data.conversationList.length > 0 && newConversation.length > 0) {
        this.data.conversationList =
          this.data.conversationList.filter(conversation => !newConversation.find((m) => m.conversationId ===
          conversation.conversationId))
      }

      this.data.conversationList?.push(...newConversation)
      this.data.conversationList?.sort((a, b) => this.sortConversation(a, b))
      this.data.reloadData()
    }
  }

  private addConversation(conversation: V2NIMLocalConversation) {

    let insertIndex = this.data.conversationList.length;
    for (let i = 0; i < this.data.conversationList.length; i++) {
      if (conversation.sortOrder >  this.data.conversationList[i].sortOrder) {
        insertIndex = i;
        break;
      }
    }

    this.data.addData(insertIndex, conversation)

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

  private setupEventHandler() {
    this.model.onSyncStartedHandle = async () => {
      await this.loadConversation()
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
    // 会话创建
    this.model.onConversationCreatedHandler = (conversation: V2NIMLocalConversation) => {

      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        this.addTeamConversation(conversation)
      } else if (!this.data.conversationList.some(m => m.conversationId === conversation.conversationId)) {
        this.addConversation(conversation)
      }
    }
    //会话删除
    this.model.onConversationDeletedHandler = (conversationIds: string[]) => {

      const indices
        = conversationIds.map(conversationId => this.data.conversationList.findIndex(conversation => conversation.conversationId
        === conversationId)
      );
      indices.map(index => this.data.removeData(index))
    }
    //会话更新
    this.model.onConversationChangedHandler = (updateList: V2NIMLocalConversation[]) => {

      updateList.forEach(changedItem => {
        const index = this.data.conversationList?.findIndex(conversation =>
        conversation.conversationId === changedItem.conversationId)

        if (index !== undefined && index > -1) {
          this.data.replaceData(index, changedItem)
        } else if (changedItem.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
          //setTimeout(() => {
          this.addTeamConversation(changedItem)
          //}, 100)
        } else {
          this.addConversation(changedItem)
        }
      }
      );
      // 更新后重新排序
      this.data.conversationList?.sort((a, b) => this.sortConversation(a, b))
      this.data.reloadData()
    }
    //监听@的回调
    getContext().eventHub.on(AitSessionChangeEvent, (session: AitSession) => {
      if (session.isAit) {
        this.aitConversationList.add(session.sessionId)
      } else if (this.aitConversationList.has(session.sessionId)) {
        this.aitConversationList.delete(session.sessionId)
      }
    })

    this.model.addEventListener()
  }

  //会话排序
  private sortConversation(a: V2NIMLocalConversation, b: V2NIMLocalConversation): number {
    return b.sortOrder - a.sortOrder
  }
}