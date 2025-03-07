/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ConversationRepo, TeamRepo } from '@nimkit/chatkit'
import {
  V2NIMConnectStatus,
  V2NIMConversation,
  V2NIMConversationType,
  V2NIMFriend,
  V2NIMFriendDeletionType,
  V2NIMLoginStatus,
  V2NIMTeam,
  V2NIMTeamType
} from '@nimsdk/base'
import { Constant } from '../loader/Constant'
import { AitServer, AitSession, AitSessionChangeEvent } from '../service/ait/AitService'

@ObservedV2
export class ConversationViewModel {
  static logTag = 'ConversationViewModel'
  //是否已经加载完成
  public isFinished: boolean = false
  //会话列表数据
  @Trace conversationList?: V2NIMConversation[]
  onUreadMessageChange?: (unreadCount?: number) => void = undefined
  // 网络连接状态
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  //记录偏移量，下次请求使用
  private offset: number = 0
  //每次请求拉取的上限
  private limit: number = Constant.PAGE_SIZE
  //被@的会话
  @Trace aitConversationList: Set<string> = new Set()

  //会话排序
  sortConversation(a: V2NIMConversation, b: V2NIMConversation): number {
    return b.sortOrder - a.sortOrder
  }

  initConversation() {
    //首先拉取一次
    if (ChatKitClient.haveSyncedConversation) {
      this.loadConversation(0)
    }
    //添加监听
    ChatKitClient.nim.conversationService?.on('onSyncFinished',
      () => {
        //同步完成拉一次
        ChatKitClient.logger?.debug(`${ConversationViewModel.logTag} onSyncFinished`)
        this.loadConversation(0)
      }
    )

    // 长连接状态变更
    ChatKitClient.nim.loginService?.on('onConnectStatus',
      (status: V2NIMConnectStatus) => {
        if (status !== V2NIMConnectStatus.V2NIM_CONNECT_STATUS_CONNECTED) {
          this.networkBroken = true
        }
      }
    )

    // 登录状态变更
    ChatKitClient.nim.loginService?.on('onLoginStatus',
      (status: V2NIMLoginStatus) => {
        if (status === V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED) {
          this.networkBroken = false
        }
      }
    )

    //好友信息变更修改
    ChatKitClient.nim.friendService?.on('onFriendInfoChanged', async (friend: V2NIMFriend) => {
      await this.updateConversationById(ChatKitClient.nim.conversationIdUtil.p2pConversationId(friend.accountId))
    })

    //好友删除，别名不存在需要更新
    ChatKitClient.nim.friendService?.on('onFriendDeleted',
      async (accountId: string, deletionType: V2NIMFriendDeletionType) => {
        await this.updateConversationById(ChatKitClient.nim.conversationIdUtil.p2pConversationId(accountId))
      })


    //群解散
    ChatKitClient.nim.teamService?.on("onTeamDismissed", (team: V2NIMTeam) => {
      this.deleteConversation(ChatKitClient.nim.conversationIdUtil.teamConversationId(team.teamId))
    })

    //退出群
    ChatKitClient.nim.teamService?.on("onTeamLeft", (team: V2NIMTeam) => {
      this.deleteConversation(ChatKitClient.nim.conversationIdUtil.teamConversationId(team.teamId))
    })

    //会话未读数变化
    ChatKitClient.nim.conversationService?.on("onTotalUnreadCountChanged", (unreadCount: number) => {
      if (this.onUreadMessageChange) {
        this.onUreadMessageChange(unreadCount)
      }
    })

    //会话创建
    ChatKitClient.nim.conversationService?.on("onConversationCreated", (conversation: V2NIMConversation) => {
      ChatKitClient.logger?.debug(`${ConversationViewModel.logTag} onConversationCreated type is ${conversation.type}`)
      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        this.addTeamConversation(conversation)
      } else {
        let existConversation: V2NIMConversation | undefined =
          this.conversationList?.find((m) => m.conversationId === conversation.conversationId)
        //如果已经存在，则不处理
        if (existConversation) {
          return
        }
        this.conversationList?.push(...[conversation])
        this.conversationList?.sort((a, b) => this.sortConversation(a, b))
      }
    })

    //会话删除
    ChatKitClient.nim.conversationService?.on("onConversationDeleted", (conversationIds: string[]) => {
      this.conversationList =
        this.conversationList?.filter(conversation => !conversationIds.includes(conversation.conversationId))
    })
    //会话更新
    ChatKitClient.nim.conversationService?.on("onConversationChanged", (updateList: V2NIMConversation[]) => {
      updateList.forEach(
        changedItem => {
          const index =
            this.conversationList?.findIndex(conversation => conversation.conversationId === changedItem.conversationId)
          if (index !== undefined && index > -1) {
            this.conversationList?.splice(index, 1)
          }
          if (changedItem.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
            setTimeout(() => {
              this.addTeamConversation(changedItem)
            }, 100)
          } else {
            this.conversationList?.push(...[changedItem])
          }
        }
      );

      this.conversationList?.sort((a, b) => this.sortConversation(a, b))
    })
    //监听@的回调
    getContext().eventHub.on(AitSessionChangeEvent, (session: AitSession) => {
      ChatKitClient.logger?.debug(ConversationViewModel.logTag,
        `AitSessionChangeEvent ConversationID = ${session.sessionId} been ait ${session.isAit}`)
      if (session.isAit) {
        this.aitConversationList.add(session.sessionId)
      } else if (this.aitConversationList.has(session.sessionId)) {
        this.aitConversationList.delete(session.sessionId)
      }

    })
    //获取数据库中所有的@数据
    AitServer.instance.getAllAitSession(ChatKitClient.getLoginUserId()).then((
      aitSessions: string[]
    ) => {
      aitSessions.forEach((session) => {
        this.aitConversationList.add(session)
      })
    })
  }

  //按照会话ID更新会话
  async updateConversationById(conversationId: string) {
    const newConversation = await ConversationRepo.getConversation(conversationId)
    ChatKitClient.logger?.debug(`${ConversationViewModel.logTag} updateConversationById ${newConversation?.conversationId} name = ${newConversation?.name}`)
    if (newConversation) {
      const index = this.conversationList?.findIndex(e => e.conversationId === newConversation.conversationId)
      if (index !== undefined && this.conversationList) {
        this.conversationList[index] = newConversation
      }
    }
  }

  //添加群会话
  async addTeamConversation(conversation: V2NIMConversation) {
    let teamId: string = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversation.conversationId)
    //添加之前判断是否合法team
    let team = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
    if (team?.isValidTeam) {
      let existConversation: V2NIMConversation | undefined =
        this.conversationList?.find((m) => m.conversationId === conversation.conversationId)
      //如果已经存在，则不处理
      if (existConversation) {
        return
      }
      this.conversationList?.push(...[conversation])
      this.conversationList?.sort((a, b) => this.sortConversation(a, b))
    } else {
      this.deleteConversation(conversation.conversationId)
    }
  }

  /**
   * 删除会话
   * @param conversationId
   */
  async deleteConversation(conversationId: string) {
    await ConversationRepo.deleteConversation(conversationId)
    //无论成功与否UI都删
    this.conversationList = this.conversationList?.filter((m) => m.conversationId !== conversationId)
  }

  /**
   * 请求回话列表
   * @param offset
   */
  async loadConversation(offset?: number) {
    try {
      if (!this.conversationList) {
        this.conversationList = []
      }
      console.debug(`Performance Test start  loadConversation`)
      if (offset === 0) {
        this.conversationList?.splice(0, this.conversationList.length);
      }
      const result = await ConversationRepo.getConversationList(offset ?? this.offset, this.limit)
      if (result != null) {
        if (offset === 0) {
          this.conversationList?.splice(0, this.conversationList.length);
        }
        this.offset = result.offset
        this.isFinished = result.finished
        let newConversation = result.conversationList
        if (this.conversationList.length > 0 && newConversation.length > 0) {
          this.conversationList =
            this.conversationList.filter(conversation => !newConversation.find((m) => m.conversationId ===
            conversation.conversationId))
        }
        this.conversationList?.push(...newConversation)
        this.conversationList?.sort((a, b) => this.sortConversation(a, b))
        console.debug(`Performance Test finish  loadConversation`)
      }
    } catch (e) {

    }

  }
}


