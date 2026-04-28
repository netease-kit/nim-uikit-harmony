/**
 * LocalConversationModel
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−06-05
 *
 *
 * Copyright © 2025 Netease. All rights reserved.
 */

import { ChatKitClient, NEFriendUserCache } from '@nimkit/chatkit'
import {
  V2NIMConnectStatus,
  V2NIMFriend,
  V2NIMFriendDeletionType,
  V2NIMLoginStatus,
  V2NIMTeam,
  V2NIMUser
} from '@nimsdk/base'
import { ConversationItem, ConversationResult, ConversationStrategy } from '../strategy/ConversationStrategy'

const TAG = '[ConversationModel]'

export class ConversationModel {
  private readonly strategy: ConversationStrategy

  public onSyncStartedHandle: () => void = () => {
  }
  public onSyncFinishedHandle: () => void = () => {
  }
  public onSyncFailedHandle: () => void = () => {
  }
  public onNetBrokenHandle: (networkBroken: boolean) => void = (networkBroken: boolean) => {
  }
  public onFriendInfoChangedHandler: (accountId: string) => void = (accountId: string) => {
  }
  public onUserProfileChangedHandler: (users: V2NIMUser[]) => void = (users: V2NIMUser[]) => {
  }
  public onFriendDeletedHandler: (accountId: string, deletionType: V2NIMFriendDeletionType) => void
    = (accountId: string, deletionType: V2NIMFriendDeletionType) => {
  }
  public onTeamDismissedHandler: (team: V2NIMTeam) => void = (team: V2NIMTeam) => {
  }
  public onTeamLeftHandler: (team: V2NIMTeam) => void = (team: V2NIMTeam) => {
  }
  public onTotalUnreadCountChangedHandler: (unreadCount: number) => void = (unreadCount: number) => {
  }
  public onConversationCreatedHandler: (conversation: ConversationItem) => void
    = (conversation: ConversationItem) => {
  }
  public onConversationDeletedHandler: (conversationIds: string[]) => void = (conversationIds: string[]) => {
  }
  public onConversationChangedHandler: (updateList: ConversationItem[]) => void
    = (updateList: ConversationItem[]) => {
  }

  constructor(strategy: ConversationStrategy) {
    this.strategy = strategy
  }

  public async getConversationList(offset: number, limit: number): Promise<ConversationResult | null> {
    try {
      return await this.strategy.getConversationList(offset, limit)
    } catch (e) {
      ChatKitClient.logger?.error(TAG, 'getConversationList ', offset.toString(), limit.toString(), e)
      return null
    }
  }

  public async getConversation(conversationId: string): Promise<ConversationItem | undefined> {
    try {
      return await this.strategy.getConversation(conversationId)
    } catch (e) {
      ChatKitClient.logger?.error(TAG, 'getConversation', conversationId, e)
      return undefined
    }
  }

  public async deleteConversation(conversationId: string): Promise<void> {
    try {
      await this.strategy.deleteConversation(conversationId)
    } catch (e) {
      ChatKitClient.logger?.error(TAG, 'deleteConversation', conversationId, e)
    }
  }

  public async stickTopConversation(conversationId: string, stickTop: boolean): Promise<void> {
    try {
      await this.strategy.stickTopConversation(conversationId, stickTop)
    } catch (e) {
      ChatKitClient.logger?.error(TAG, 'stickTopConversation', conversationId, stickTop.toString(), e)
    }
  }

  public requiresNetworkForDelete(): boolean {
    return this.strategy.requiresNetworkForDelete()
  }

  public addEventListener() {
    this.strategy.onSyncStarted(this.onSyncStartedHandle)
    this.strategy.onSyncFinished(this.onSyncFinishedHandle)
    this.strategy.onSyncFailed(this.onSyncFailedHandle)
    ChatKitClient.nim.loginService?.on('onConnectStatus',
      (status: V2NIMConnectStatus) => {
        if (status !== V2NIMConnectStatus.V2NIM_CONNECT_STATUS_CONNECTED) {
          this.onNetBrokenHandle(true)
        }
      }
    )

    ChatKitClient.nim.loginService?.on('onLoginStatus',
      (status: V2NIMLoginStatus) => {
        if (status === V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED) {
          this.onNetBrokenHandle(false)
        }
      }
    )

    ChatKitClient.nim.friendService?.on('onFriendInfoChanged', async (friend: V2NIMFriend) => {
      this.onFriendInfoChangedHandler(friend.accountId)
    })

    ChatKitClient.nim.friendService?.on('onFriendDeleted', this.onFriendDeletedHandler)
    ChatKitClient.nim.teamService?.on('onTeamDismissed', this.onTeamDismissedHandler)
    ChatKitClient.nim.teamService?.on('onTeamLeft', this.onTeamLeftHandler)
    this.strategy.onTotalUnreadCountChanged(this.onTotalUnreadCountChangedHandler)
    this.strategy.onConversationCreated(this.onConversationCreatedHandler)
    this.strategy.onConversationDeleted(this.onConversationDeletedHandler)
    this.strategy.onConversationChanged(this.onConversationChangedHandler)
    ChatKitClient.nim.userService?.on('onUserProfileChanged', async (users: V2NIMUser[]) => {
      users.forEach((user) => {
        if (NEFriendUserCache.getInstance().isFriend(user.accountId)) {
          NEFriendUserCache.getInstance().updateFriendInfo({
            user: user
          })
        }
        if (NEFriendUserCache.isMe(user.accountId) && NEFriendUserCache.mineUserCache) {
          NEFriendUserCache.mineUserCache.user = user
        }
      })
      // 通知 ViewModel 更新对应的会话
      this.onUserProfileChangedHandler(users)
    })
  }

  public p2pConversationId(accountId: string) {
    return ChatKitClient.nim.conversationIdUtil.p2pConversationId(accountId)
  }

  public teamConversationId(teamId: string) {
    return ChatKitClient.nim.conversationIdUtil.teamConversationId(teamId)
  }

  public parseConversationTargetId(conversationId: string): string {
    return ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
  }
}
