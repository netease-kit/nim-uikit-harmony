/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ConversationRepo, TeamRepo } from '@nimkit/chatkit'
import { V2NIMConversation, V2NIMConversationType, V2NIMFriend, V2NIMTeam, V2NIMTeamType } from '@nimsdk/base'
import { Constant } from '../loader/Constant'

@ObservedV2
export class ConversationViewModel {
  //是否已经加载完成
  public isFinished: boolean = false
  //会话列表数据
  @Trace conversationList?: V2NIMConversation[]
  onUreadMessageChange?: (unreadCount?: number) => void = undefined
  //记录偏移量，下次请求使用
  private offset: number = 0
  //每次请求拉取的上限
  private limit: number = Constant.PAGE_SIZE

  //会话排序
  sortConversation(a: V2NIMConversation, b: V2NIMConversation): number {
    if (a.stickTop === b.stickTop) {
      if (a.lastMessage && b.lastMessage) {
        return b.lastMessage.messageRefer.createTime - a.lastMessage.messageRefer.createTime
      }
      return b.sortOrder - a.sortOrder
    }
    if (a.stickTop) {
      return -1
    } else {
      return 1
    }
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
        this.loadConversation(0)
      }
    )

    //好友信息变更修改
    ChatKitClient.nim.friendService?.on('onFriendInfoChanged', (friend: V2NIMFriend) => {
      this.updateConversationById(ChatKitClient.nim.conversationIdUtil.p2pConversationId(friend.accountId))
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
      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversation.conversationId)
        TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL).then((team) => {
          if (team?.isValidTeam) {
            this.conversationList?.push(...[conversation])
            this.conversationList?.sort((a, b) => this.sortConversation(a, b))
          } else {
            this.deleteConversation(conversation.conversationId)
          }
        })
      } else {
        this.conversationList?.push(...[conversation])
        this.conversationList?.sort((a, b) => this.sortConversation(a, b))
      }
    })

    //会话删除
    ChatKitClient.nim.conversationService?.on("onConversationDeleted", (conversationIds: string[]) => {
      this.conversationList =
        this.conversationList?.filter(conversation =>!conversationIds.includes(conversation.conversationId))
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
        }
      );
      this.conversationList?.push(...updateList)
      this.conversationList?.sort((a, b) => this.sortConversation(a, b))
    })
  }

  //按照会话ID更新会话
  updateConversationById(conversationId: string) {
    ConversationRepo.getConversation(conversationId).then((conversation) => {
      if (conversation) {
        const index = this.conversationList?.findIndex(e => e.conversationId === conversation.conversationId)
        if (index !== undefined && this.conversationList) {
          this.conversationList.splice(index, 1)
          this.conversationList[index] = conversation
        }
      }
    })
  }

  /**
   * 删除会话
   * @param conversationId
   */
  deleteConversation(conversationId: string) {
    ConversationRepo.deleteConversation(conversationId)
  }

  /**
   * 请求回话列表
   * @param offset
   */
  async loadConversation(offset?: number) {
    try {
      const result = await ConversationRepo.getConversationList(offset ?? this.offset, this.limit)
      if (result != null) {
        this.offset = result.offset
        this.isFinished = result.finished
        if (!this.conversationList) {
          this.conversationList = []
        }
        if (offset === 0) {
          this.conversationList?.splice(0, this.conversationList.length);
        }
        this.conversationList?.push(...result.conversationList)
        this.conversationList?.sort((a, b) => this.sortConversation(a, b))
      }
    } catch (e) {

    }

  }
}


