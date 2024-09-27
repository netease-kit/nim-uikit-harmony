/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMCheckFriendResult,
  V2NIMFriend,
  V2NIMFriendAddApplication,
  V2NIMFriendAddApplicationQueryOption,
  V2NIMFriendAddApplicationResult,
  V2NIMFriendAddParams,
  V2NIMFriendAddRejection,
  V2NIMFriendDeleteParams,
  V2NIMFriendDeletionType,
  V2NIMFriendSearchOption,
  V2NIMFriendSetParams,
  V2NIMLoginStatus,
  V2NIMUser,
  V2NIMUserSearchOption,
  V2NIMUserUpdateParams
} from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';
import { NEUserWithFriend } from '../model/NEUserWithFriend';
import { NEFriendUserCache } from '../NEFriendUserCache';
import { EventHubUtil } from '../utils/EventHubUtil';

export class ContactRepo {
  static addListener() {
    ChatKitClient.nim.loginService.on("onLoginStatus", (status: V2NIMLoginStatus) => {
      switch (status) {
        case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGOUT:
          NEFriendUserCache.getInstance().removeAllFriendInfo()
          NEFriendUserCache.mineUserCache = undefined
          break;
        default:
          break;
      }
    })

    ChatKitClient.nim.userService?.on("onUserProfileChanged", async (users: V2NIMUser[]) => {
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

      NEFriendUserCache.getInstance().listener.emit('updateUserInfo', users)
    })

    ChatKitClient.nim.userService?.on("onBlockListAdded", async (user: V2NIMUser) => {
      NEFriendUserCache.getInstance().addBlockAccount(user.accountId)
      NEFriendUserCache.getInstance().listener.emit('addBlockAccount', user.accountId)
    })

    ChatKitClient.nim.userService?.on("onBlockListRemoved", (accountId: string) => {
      NEFriendUserCache.getInstance().removeBlockAccount(accountId)
      NEFriendUserCache.getInstance().listener.emit('removeBlockAccount', accountId)
    })

    ChatKitClient.nim.friendService?.on("onFriendAdded", (friend: V2NIMFriend) => {
      NEFriendUserCache.getInstance().updateFriendInfo({
        friend: friend
      })
      ContactRepo.removeUserFromBlockList(friend.accountId)
      NEFriendUserCache.getInstance().listener.emit('updateFriendInfo', friend)
    })

    ChatKitClient.nim.friendService?.on("onFriendDeleted",
      (accountId: string, deletionType: V2NIMFriendDeletionType) => {
        NEFriendUserCache.getInstance().removeFriendInfo(accountId)
      })

    ChatKitClient.nim.friendService?.on("onFriendAddApplication", (application: V2NIMFriendAddApplication) => {
    })

    ChatKitClient.nim.friendService?.on("onFriendAddRejected", (rejection: V2NIMFriendAddRejection) => {
    })

    ChatKitClient.nim.friendService?.on("onFriendInfoChanged", (friend: V2NIMFriend) => {
      NEFriendUserCache.getInstance().updateFriendInfo({
        friend: friend
      })
      NEFriendUserCache.getInstance().listener.emit('updateFriendInfo', friend)
    })
  }

  /**
   * 根据用户账号列表获取用户资料
   *
   * @param accountIds 用户 Id 列表。最大为 150 个
   */
  static async getUserList(accountIds: string[]): Promise<V2NIMUser[]> {
    return await ChatKitClient.nim.userService?.getUserList(accountIds) ?? []
  }

  /**
   * 根据用户账号列表获取用户资料-从云端获取
   *
   * 注: 其结果会更新本地数据, 建议在需要实时感知用户最新的信息的场景下使用
   *
   * @param accountIds 用户 Id 列表。最大为 150 个
   */
  static async getUserListFromCloud(accountIds: string[]): Promise<V2NIMUser[]> {
    const userList = await ChatKitClient.nim.userService?.getUserListFromCloud(accountIds) ?? []
    userList.forEach((user) => {
      const accountId = user.accountId
      if (accountId === ChatKitClient.getLoginUserId()) {
        NEFriendUserCache.mineUserCache = new NEUserWithFriend({
          user: user
        })
      }

      if (NEFriendUserCache.getInstance().isFriend(accountId)) {
        NEFriendUserCache.getInstance().updateFriendInfo({
          user: user
        })
      }
    })

    return userList
  }

  /**
   * 更新自己的用户资料。调用该 API 后，会触发 onUserProfileChanged 事件
   *
   * @param updateParams 更新参数
   */
  static async updateSelfUserProfile(updateParams: V2NIMUserUpdateParams): Promise<void> {
    await ChatKitClient.nim.userService?.updateSelfUserProfile(updateParams)
  }

  /**
   * 添加用户到黑名单中
   *
   * @param accountId 用户 Id
   */
  static async addUserToBlockList(accountId: string): Promise<void> {
    await ChatKitClient.nim.userService?.addUserToBlockList(accountId)
  }

  /**
   * 从黑名单中移除用户
   *
   * @param accountId 用户 Id
   */
  static async removeUserFromBlockList(accountId: string): Promise<void> {
    await ChatKitClient.nim.userService?.removeUserFromBlockList(accountId)
  }

  /**
   * 获取黑名单列表
   */
  static async getBlockList(): Promise<string[]> {
    return await ChatKitClient.nim.userService?.getBlockList() ?? []
  }

  /**
   * 根据关键词搜索用户信息
   *
   * @param option 搜索选项
   */
  static async searchUserByOption(option: V2NIMUserSearchOption): Promise<V2NIMUser[]> {
    return await ChatKitClient.nim.userService?.searchUserByOption(option) ?? []
  }


  /**
   * 添加/申请好友
   * @param accountId 好友 ID
   * @param params 申请相关参数
   */
  static async addFriend(accountId: string, params: V2NIMFriendAddParams): Promise<void> {
    await ChatKitClient.nim.friendService?.addFriend(accountId, params)
  }

  /**
   * 删除好友
   *
   * @param accountId 好友 ID
   * @param params 删除相关参数
   */
  static async deleteFriend(accountId: string, params: V2NIMFriendDeleteParams): Promise<void> {
    await ChatKitClient.nim.friendService?.deleteFriend(accountId, params)
  }

  /**
   * 接受好友申请
   *
   * @param accountId 好友 ID
   */
  static async acceptAddApplication(application: V2NIMFriendAddApplication): Promise<void> {
    await ChatKitClient.nim.friendService?.acceptAddApplication(application)
  }

  /**
   * 拒绝好友申请
   *
   * @param accountId 好友 ID
   * @param postscript 拒绝时的附言
   */
  static async rejectAddApplication(application: V2NIMFriendAddApplication, postscript?: string): Promise<void> {
    await ChatKitClient.nim.friendService?.rejectAddApplication(application, postscript)
  }

  /**
   * 设置好友信息
   *
   * @param accountId 好友 ID
   * @param params  设置好友信息参数
   */
  static async setFriendInfo(accountId: string, params: V2NIMFriendSetParams): Promise<void> {
    await ChatKitClient.nim.friendService?.setFriendInfo(accountId, params)
  }

  /**
   * 获取好友列表
   */
  static async getFriendList(): Promise<V2NIMFriend[]> {
    let friendList = await ChatKitClient.nim.friendService?.getFriendList() ?? []
    NEFriendUserCache.getInstance().initFriendCacheWithList(friendList)

    const blockList = await ContactRepo.getBlockList()
    NEFriendUserCache.getInstance().initBlockAccountSet(blockList)

    return friendList
  }

  /**
   * 根据账号 ID 获取好友信息
   *
   * @param accountIds 好友 ID 列表
   */
  static async getFriendByIds(accountIds: string[]): Promise<V2NIMFriend[]> {
    return await ChatKitClient.nim.friendService?.getFriendByIds(accountIds) ?? []
  }

  /**
   * 根据账号 ID 获取用户信息（包含好友信息）
   *
   * @param accountIds 用户 ID 列表
   */
  static async getUserWithFriendByIds(accountIds: string[]): Promise<NEUserWithFriend[]> {
    let userWithFriends: NEUserWithFriend[] = []
    const users = await ContactRepo.getUserListFromCloud(accountIds)
    const friends = await ContactRepo.getFriendByIds(accountIds)

    let friendsMap: Map<string, NEUserWithFriend> = new Map<string, NEUserWithFriend>()
    for (const friend of friends) {
      if (friend.accountId) {
        friendsMap.set(friend.accountId, new NEUserWithFriend({
          friend: friend
        }))
      }
    }

    for (const user of users) {
      const friend = friendsMap.get(user.accountId)?.friend
      let userWithFriend: NEUserWithFriend = new NEUserWithFriend({
        friend: friend,
        user: user
      })
      userWithFriends.push(userWithFriend)
    }
    return userWithFriends
  }

  /**
   * 根据账号 ID 检查好友状态
   * @param accountIds 好友 ID列表
   */
  static async checkFriend(accountIds: string[]): Promise<V2NIMCheckFriendResult | undefined> {
    return await ChatKitClient.nim.friendService?.checkFriend(accountIds)
  }

  /**
   * 获取申请添加好友列表通知
   */
  static async getAddApplicationList(option: V2NIMFriendAddApplicationQueryOption): Promise<V2NIMFriendAddApplicationResult | undefined> {
    return await ChatKitClient.nim.friendService?.getAddApplicationList(option)
  }

  /**
   * 设置好友申请已读
   */
  static async setAddApplicationRead(): Promise<void> {
    await ChatKitClient.nim.friendService?.setAddApplicationRead()
  }

  /**
   * 获取未读的好友申请数量
   */
  static async getAddApplicationUnreadCount(): Promise<number> {
    return await ChatKitClient.nim.friendService?.getAddApplicationUnreadCount() ?? 0
  }

  /**
   * 根据关键词搜索好友
   * @param option 搜索好友的条件
   */
  static async searchFriendByOption(option: V2NIMFriendSearchOption): Promise<V2NIMFriend[]> {
    return await ChatKitClient.nim.friendService?.searchFriendByOption(option) ?? []
  }
}