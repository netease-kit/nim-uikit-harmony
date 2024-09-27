/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ContactRepo, NEFriendUserCache, NEUserWithFriend } from '@nimkit/chatkit'
import { GetUnreadCountStr, initalLetter } from '@nimkit/common'
import { V2NIMFriend, V2NIMUser } from '@nimsdk/base'
import { NEContactSection, SelectUserWithFriend } from '../model/NEContactSection'

const digitRegular = /[0-9]/
const azRegular = /[A-Z]/

@ObservedV2
export class ContactViewModel {
  @Trace friendList: NEUserWithFriend[] = []
  @Trace friendSection: NEContactSection[] = []

  constructor() {
    NEFriendUserCache.getInstance().listener.on('updateUserInfo', async (users: V2NIMUser[]) => {
      users.forEach((user) => {
        this.removeFromContact(user.accountId)
        const userWithFriend = NEFriendUserCache.getInstance().getFriendById(user.accountId)
        if (userWithFriend) {
          this.addToContact(userWithFriend)
        }
      })
    })

    NEFriendUserCache.getInstance().listener.on('updateFriendInfo', async (friend: V2NIMFriend) => {
      this.removeFromContact(friend.accountId)
      const user = NEFriendUserCache.getInstance().getFriendById(friend.accountId)
      if (user) {
        this.addToContact(user)
      }
    })

    NEFriendUserCache.getInstance().listener.on('removeFriendInfo', async (accountId: string) => {
      this.removeFromContact(accountId)
    })

    NEFriendUserCache.getInstance().listener.on('addBlockAccount', async (accountId: string) => {
      this.removeFromContact(accountId)
    })

    NEFriendUserCache.getInstance().listener.on('removeBlockAccount', async (accountId: string) => {
      const user = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (user) {
        this.addToContact(user)
      }
    })
  }

  // 获取好友列表
  async getFriendList(filterList: string[] = []) {
    try {
      let friendList: NEUserWithFriend[] = []
      if (NEFriendUserCache.getInstance().isEmpty()) {
        await ContactRepo.getFriendList()
      }

      friendList = NEFriendUserCache.getInstance().getFriendListNotInBlocklist()
      if (friendList) {
        this.friendList = friendList
        this.formatFriends(friendList, filterList)
      }
    } catch (err) {
      console.log(err)
    }
  }

  // 格式化好友列表（按分组排序）
  formatFriends(friendList: NEUserWithFriend[], filterList: string[]) {
    let contactList: NEContactSection[] = []
    let initalDict: Map<string, NEUserWithFriend[]> = new Map<string, NEUserWithFriend[]>()
    let digitList: NEUserWithFriend[] = []
    let specialCharList: NEUserWithFriend[] = []

    for (const friend of friendList) {
      if (friend.user?.accountId && filterList.includes(friend.user?.accountId)) {
        continue
      }

      let name = friend.showName()
      if (name) {
        const inital = initalLetter(name)
        if (digitRegular.test(inital)) {
          digitList.push(friend)
        } else if (!azRegular.test(inital)) {
          specialCharList.push(friend)
        } else {
          if (initalDict.get(inital)) {
            initalDict.get(inital)?.push(friend)
          } else {
            initalDict.set(inital, [friend])
          }
        }
      }
    }

    const nameSortFunc = (s1: NEUserWithFriend, s2: NEUserWithFriend) => {
      if ((s1.showName()) < (s2.showName())) {
        return -1
      }
      if ((s1.showName()) > (s2.showName())) {
        return 1
      }
      return 0
    }

    digitList.sort(nameSortFunc)
    specialCharList.sort(nameSortFunc)
    for (const key of initalDict.keys()) {
      let value = initalDict.get(key)
      if (value) {
        value.sort(nameSortFunc)
        contactList.push(new NEContactSection(key, value))
      }
    }

    const initalSortFunc = (s1: NEContactSection, s2: NEContactSection) => {
      if (s1.initial < s2.initial) {
        return -1
      }
      if (s1.initial > s2.initial) {
        return 1
      }
      return 0
    }

    contactList.sort(initalSortFunc)
    const specialList = digitList.concat(specialCharList)
    if (specialList.length > 0) {
      contactList.push(new NEContactSection("#", specialList))
    }
    this.friendSection = contactList
  }

  // 添加好友到通讯录
  addToContact(userWithFriend: NEUserWithFriend) {
    let name = userWithFriend.showName()
    let user = new SelectUserWithFriend(userWithFriend)
    if (name) {
      let inital = initalLetter(name)
      if (digitRegular.test(inital)) {
        inital = '#'
      } else if (!azRegular.test(inital)) {
        inital = '#'
      }

      for (let title = 0; title < this.friendSection.length; title++) {
        // 当前分组已存在
        if (this.friendSection[title].initial === inital) {
          // 判断是否已经存在
          for (const friend of this.friendSection[title].contacts.contacts) {
            if (friend.user?.accountId === userWithFriend.user?.accountId) {
              return
            }
          }

          // 已有分组中插入
          for (let index = 0; index < this.friendSection[title].contacts.contacts.length; index++) {
            if (name < this.friendSection[title].contacts.contacts[index].showName()) {
              this.friendSection[title].contacts.addData(index, user)
              return
            }
          }
          // 尾插
          this.friendSection[title].contacts.push(user)
          return
        }
      }

      // 无当前分组
      let contactSection = new NEContactSection(inital, [userWithFriend])
      for (let index = 0; index < this.friendSection.length; index++) {
        // 保证字母分组在【#】之前
        if (this.friendSection[index].initial === '#') {
          this.friendSection.splice(index, 0, contactSection)
          return
        }
        if (inital < this.friendSection[index].initial) {
          this.friendSection.splice(index, 0, contactSection)
          return
        }
      }
      // 尾插
      this.friendSection.push(contactSection)
    }
  }

  // 从通讯录中移除好友
  removeFromContact(accountId: string) {
    for (let title = 0; title < this.friendSection.length; title++) {
      this.friendSection[title].contacts.delete(accountId)
      if (this.friendSection[title].contacts.contacts.length <= 0) {
        this.friendSection.splice(title, 1)
      }
    }
  }

  // 获取侧边字母导航栏
  getInitalList(): string[] {
    return this.friendSection.map((value, index, arr) => {
      return value.initial
    })
  }

  // 获取好友申请未读数
  async getUnreadApplication() {
    try {
      const count = await ContactRepo.getAddApplicationUnreadCount()
      if (count > 0) {
        return GetUnreadCountStr(count)
      }
      return undefined
    } catch (err) {
      console.log(err)
      return undefined
    }
  }
}