/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { AIRepo, ChatKitClient, ContactRepo, filterPinnedAIUsers, NEAIUserCache, UserEventRepo } from '@nimkit/chatkit'
import { V2NIMAIUser, V2NIMUser } from '@nimsdk/base'

@ObservedV2
export class ConversationAIViewModel {
  static logTag = 'ConversationAIViewModel'
  //是否已经加载完成
  public isFinished: boolean = false
  //会话列表数据
  @Trace aiUsers?: V2NIMAIUser[]
  @Trace aiUserAccountIds: string[] = []
  @Trace isFinishedSyncLoad?: boolean = false
  // 网络连接状态
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  private hasAddedAIUserListener: boolean = false
  private hasInitializedAIUsers: boolean = false
  private hasRequestedAIUserCloudLoad: boolean = false
  private isLoadingAIUsers: boolean = false
  private ignoreNextAIUserCompleteEvent: boolean = false
  private userProfileDisposer?: () => void

  private onAIUserChanged = async () => {
    if (this.ignoreNextAIUserCompleteEvent) {
      this.ignoreNextAIUserCompleteEvent = false
      return
    }
    this.refreshAIUsersFromCache()
  }

  private onUserProfileChanged = async (users: V2NIMUser[]) => {
    if (!this.hasInitializedAIUsers) {
      return
    }
    for (const user of users) {
      if (user.accountId === ChatKitClient.getLoginUserId()) {
        NEAIUserCache.setMineUser(user)
        this.refreshAIUsersFromCache()
        break
      }
    }
  }

  initAIUsers() {
    this.addAIUserListener()
    this.hasInitializedAIUsers = true
    if (this.hasRequestedAIUserCloudLoad) {
      return
    }
    this.hasRequestedAIUserCloudLoad = true
    this.loadAIUsers()
  }

  loadAIUsersOnDemand() {
    this.addAIUserListener()
    this.hasInitializedAIUsers = true
    if (this.hasRequestedAIUserCloudLoad) {
      return
    }
    this.hasRequestedAIUserCloudLoad = true
    this.loadAIUsers()
  }

  refreshAIUsersFromCache(): void {
    this.addAIUserListener()
    this.hasInitializedAIUsers = true
    if (!this.aiUsers) {
      this.aiUsers = []
    }
    const mineUser = NEAIUserCache.getMineUser()
    const allAIUsers = NEAIUserCache.getAIUserList()
    const aiUsers = filterPinnedAIUsers(allAIUsers, mineUser?.serverExtension)
    this.isFinished = true
    this.isFinishedSyncLoad = true
    this.updateAIUserAccountIds(allAIUsers)
    this.aiUsers?.splice(0, this.aiUsers.length, ...aiUsers)
  }

  private addAIUserListener() {
    if (this.hasAddedAIUserListener) {
      return
    }
    AIRepo.listener.on('onLoadAIUserComplete', this.onAIUserChanged)
    this.userProfileDisposer = UserEventRepo.onUserProfileChanged(this.onUserProfileChanged)
    this.hasAddedAIUserListener = true
  }

  onDestroy() {
    if (!this.hasAddedAIUserListener) {
      return
    }
    AIRepo.listener.off('onLoadAIUserComplete', this.onAIUserChanged)
    this.userProfileDisposer?.()
    this.userProfileDisposer = undefined
    this.hasAddedAIUserListener = false
    this.hasInitializedAIUsers = false
    this.hasRequestedAIUserCloudLoad = false
    this.isLoadingAIUsers = false
    this.ignoreNextAIUserCompleteEvent = false
    this.aiUserAccountIds.splice(0, this.aiUserAccountIds.length)
  }

  /**
   * 请求回话列表
   * @param offset
   */
  async loadAIUsers() {
    if (this.isLoadingAIUsers) {
      return
    }

    this.isLoadingAIUsers = true
    try {
      if (!this.aiUsers) {
        this.aiUsers = []
      }
      const result: V2NIMAIUser[] = await AIRepo.getAIUserList()
      if (result) {
        this.isFinished = true
        this.isFinishedSyncLoad = true
        const mineUsers: V2NIMUser[] = await ContactRepo.getUserListFromCloud([ChatKitClient.getLoginUserId()])
        const mineUser = mineUsers.length > 0 ? mineUsers[0] : NEAIUserCache.getMineUser()
        if (mineUser) {
          NEAIUserCache.setMineUser(mineUser)
        }
        const aiUsers = filterPinnedAIUsers(result, mineUser?.serverExtension)
        NEAIUserCache.clearAIUsers()
        result.forEach((aiUser: V2NIMAIUser): void => {
          NEAIUserCache.setAIUser(aiUser)
        })
        this.updateAIUserAccountIds(result)
        this.aiUsers?.splice(0, this.aiUsers.length, ...aiUsers)
        this.ignoreNextAIUserCompleteEvent = true
        AIRepo.listener.emit('onLoadAIUserComplete')
        // this.aiUsers?.sort((left, right) => this.sortConversation(a, b)) // no need to sort
      }
    } catch (e) {
      // ignore
    } finally {
      this.isLoadingAIUsers = false
    }
  }

  private updateAIUserAccountIds(aiUsers: V2NIMAIUser[]): void {
    const accountIds = aiUsers.map((aiUser: V2NIMAIUser): string => aiUser.accountId)
    this.aiUserAccountIds.splice(0, this.aiUserAccountIds.length, ...accountIds)
  }
}
