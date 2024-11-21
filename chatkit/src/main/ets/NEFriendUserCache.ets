/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient } from './ChatKitClient';
import { NEUserWithFriend } from './model/NEUserWithFriend';
import { V2NIMFriend, V2NIMUser } from '@nimsdk/base';
import { ContactRepo } from './repo/ContactRepo';

interface updateFriendInfoParams {
  user?: V2NIMUser;
  friend?: V2NIMFriend;
  friendUser?: NEUserWithFriend;
}

/// 好友信息缓存，只缓存好友
@ObservedV2
export class NEFriendUserCache {
  @Trace public static mineUserCache?: NEUserWithFriend
  // 黑名单账号集合
  public blockAccountList: string[] = []
  // 好友列表,包括黑名单中好友
  public friendCache: Map<string, NEUserWithFriend> = new Map<string, NEUserWithFriend>()

  private constructor() {
    ContactRepo.addListener()
    ContactRepo.getFriendList()
    ContactRepo.getUserListFromCloud([ChatKitClient.getLoginUserId()])
    ContactRepo.getBlockList()
  }

  public static getInstance() {
    if (!AppStorage.get<NEFriendUserCache>(NEFriendUserCache.name)) {
      let instance = new NEFriendUserCache()
      AppStorage.setOrCreate(NEFriendUserCache.name, instance);
    }
    return AppStorage.get<NEFriendUserCache>(NEFriendUserCache.name) as NEFriendUserCache;
  }

  /// 是否是自己
  public static isMe(accountId: string): Boolean {
    return NEFriendUserCache.mineUserCache?.user?.accountId === accountId
  }

  /// 好友缓存是否为空
  public isEmpty(): Boolean {
    if (this.friendCache == undefined || this.friendCache.size === 0) {
      return true
    }

    return false
  }

  /// 是否是好友
  public isFriend(accountId: string): Boolean {
    return this.friendCache.has(accountId) && !this.blockAccountList.includes(accountId)
  }

  /// 添加（更新）好友信息
  public updateFriendInfo(params: updateFriendInfoParams) {
    let accountId = ""
    if (params.user) {
      accountId = params.user.accountId
      let friendUser = this.friendCache.get(accountId)
      if (friendUser) {
        friendUser.user = params.user
      } else {
        this.friendCache.set(accountId, new NEUserWithFriend({
          user: params.user
        }))
      }
    }

    if (params.friend) {
      accountId = params.friend.accountId
      let friendUser = this.friendCache.get(accountId)
      if (friendUser) {
        friendUser.friend = params.friend
        friendUser.user = params.friend.userProfile
      } else {
        this.friendCache.set(accountId, new NEUserWithFriend({
          friend: params.friend
        }))
      }
    }

    if (params.friendUser && params.friendUser.user?.accountId) {
      accountId = params.friendUser.user.accountId
      this.friendCache.set(accountId, params.friendUser)
    }
  }

  /// 使用好友列表初始化缓存
  public initFriendCacheWithList(friends: V2NIMFriend[]) {
    friends.forEach((friend: V2NIMFriend) => {
      this.updateFriendInfo({
        friend: friend
      })
    })

    ContactRepo.listener.emit('initFriendCache')
  }

  /// 获取缓存的好友信息
  public getFriendById(accountId: string) {
    return this.friendCache.get(accountId)
  }

  /**
   * 通过用户ID列表获取用户信息
   * @param accIds
   * @returns
   */
  public getFriendsByIds(accIds: string[]) {
    let result: NEUserWithFriend[] = []
    accIds.forEach((accId) => {
      let user = this.friendCache.get(accId)
      if (user) {
        result.push(user)
      }
    })
    return result
  }

  /// 获取缓存的好友信息列表，包含黑名单中的好友
  public getFriendList() {
    return Array.from(this.friendCache.values())
  }

  /// 获取缓存的好友信息列表，不包含黑名单中的好友
  public getFriendListNotInBlocklist() {
    let friends: Map<string, NEUserWithFriend> = new Map<string, NEUserWithFriend>()
    this.friendCache.forEach((value, key) => {
      if (!this.blockAccountList.includes(key)) {
        friends.set(key, value)
      }
    })

    return Array.from(friends.values())
  }

  /// 获取缓存的黑名单列表
  public getBlocklist(): string[] {
    return this.blockAccountList
  }

  /// 删除好友信息缓存
  public removeFriendInfo(accountId: string) {
    this.friendCache.delete(accountId)
    ContactRepo.listener.emit('removeFriendInfo', accountId)
  }

  /// 删除所有好友信息缓存
  public removeAllFriendInfo() {
    this.friendCache.clear()
    this.blockAccountList = []
    ContactRepo.removeListener()
    AppStorage.delete(NEFriendUserCache.name)
  }

  /// 初始化黑名单
  public initBlockAccountSet(blockList: string[]) {
    this.blockAccountList = blockList
  }

  /// 是否是黑名单账号
  public isBlockAccount(accountId: string) {
    return this.blockAccountList.includes(accountId)
  }

  /// 更新黑名单
  public addBlockAccount(accountId: string) {
    if (!this.blockAccountList.includes(accountId)) {
      this.blockAccountList.push(accountId)
      ContactRepo.listener.emit('addBlockAccount', accountId)
    }
  }

  /// 移除黑名单账号
  public removeBlockAccount(accountId: string) {
    if (this.blockAccountList.includes(accountId)) {
      for (let index = 0; index < this.blockAccountList.length; index++) {
        if (this.blockAccountList[index] === accountId) {
          this.blockAccountList.splice(index, 1)
          ContactRepo.listener.emit('removeBlockAccount', accountId)
          break
        }
      }
    }
  }
}