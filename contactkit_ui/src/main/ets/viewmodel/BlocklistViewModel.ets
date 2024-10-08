/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ContactRepo, NEFriendUserCache, NEUserWithFriend } from '@nimkit/chatkit'
import { EventHubUtil } from '@nimkit/chatkit/src/main/ets/utils/EventHubUtil'
import { V2NIMFriend, V2NIMUser } from '@nimsdk/base'

@ObservedV2
export class BlocklistViewModel {
  @Trace blockList: NEUserWithFriend[] = []
  listener = new EventHubUtil()

  constructor() {
    NEFriendUserCache.getInstance().listener.on('updateUserInfo', async (users: V2NIMUser[]) => {
      for (const user of users) {
        if (NEFriendUserCache.getInstance().isBlockAccount(user.accountId)) {
          for (let blockUser of this.blockList) {
            if (user.accountId === blockUser.user?.accountId) {
              blockUser.user = user
            }
          }
        }
      }
    })

    NEFriendUserCache.getInstance().listener.on('updateFriendInfo', async (friend: V2NIMFriend) => {
      for (let blockUser of this.blockList) {
        if (friend.accountId === blockUser.user?.accountId) {
          blockUser.friend = friend
          break
        }
      }
    })

    NEFriendUserCache.getInstance().listener.on('addBlockAccount', async (accountId: string) => {
      const userWithFriend = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (userWithFriend) {
        this.blockList.push(userWithFriend)
      }
    })

    NEFriendUserCache.getInstance().listener.on('removeBlockAccount', async (accountId: string) => {
      for (let index = 0; index < this.blockList.length; index++) {
        if (this.blockList[index].user?.accountId === accountId) {
          this.blockList.splice(index, 1)
        }
      }
    })
  }

  /**
   * 获取黑名单列表
   */
  async getBlockList() {
    try {
      const blockList = NEFriendUserCache.getInstance().getBlocklist()
      const userWithFriends = await ContactRepo.getUserWithFriendByIds(blockList)
      this.blockList = userWithFriends
    } catch (err) {
      console.log(err)
    }
  }

  /**
   * 从黑名单中移除用户
   *
   * @param accountId 用户 Id
   */
  async removeUserFromBlockList(accountId: string) {
    try {
      await ContactRepo.removeUserFromBlockList(accountId)

      for (let index = 0, length = this.blockList.length; index < length; index++) {
        if (this.blockList[index].user?.accountId === accountId) {
          this.blockList.splice(index, 1)
        }
      }
    } catch (err) {
      console.log(err)
    }
  }

  /**
   * 添加用户到黑名单中
   *
   * @param accountId 用户 Id
   */
  async addUserToBlockList(users: NEUserWithFriend[]) {
    try {
      for (const user of users) {
        if (user.user?.accountId) {
          await ContactRepo.addUserToBlockList(user.user.accountId)
        }
      }
      this.blockList.concat(users)
    } catch (err) {
      console.log(err)
    }
  }
}