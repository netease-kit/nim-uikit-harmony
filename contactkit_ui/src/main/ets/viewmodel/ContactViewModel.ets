/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ContactRepo, NEFriendUserCache, NEUserWithFriend } from '@nimkit/chatkit'
import { GetUnreadCountStr, initalLetter } from '@nimkit/common'
import { V2NIMFriend, V2NIMUser } from '@nimsdk/base'
import { NEContactSection, NEContactSectionDataSource, SelectUserWithFriend } from '../model/NEContactSection'

const digitRegular = /[0-9]/
const azRegular = /[A-Z]/

@ObservedV2
export class ContactViewModel {
  @Trace friendList: NEUserWithFriend[] = []
  @Trace friendSection: NEContactSectionDataSource = new NEContactSectionDataSource()
  @Trace initalList: string[] = []
  updateUserInfoFun = async (users: V2NIMUser[]) => {
    await Promise.all(
      users.map(async (user) => {
        if (NEFriendUserCache.getInstance().isFriend(user.accountId)) {
          const oldUser = this.findContactModel(user.accountId)
          if (oldUser && (oldUser?.user?.name !== user.name || oldUser?.user?.avatar !== user.avatar)) {
            this.removeFromContact(user.accountId)
          }
          const userWithFriend = NEFriendUserCache.getInstance().getFriendById(user.accountId)
          if (userWithFriend) {
            await this.addToContact(userWithFriend)
          }
        }
      })
    )
  }
  updateFriendInfoFun = async (friend: V2NIMFriend) => {
    const oldUser = this.findContactModel(friend.accountId)
    if (oldUser && oldUser.friend?.alias !== friend.alias) {
      this.removeFromContact(friend.accountId)
    }
    const user = NEFriendUserCache.getInstance().getFriendById(friend.accountId)
    if (user) {
      this.addToContact(user)
    }
  }
  removeFriendInfoFun = async (accountId: string) => {
    this.removeFromContact(accountId)
  }
  addBlockAccountFun = async (accountId: string) => {
    this.removeFromContact(accountId)
  }
  removeBlockAccountFun = async (accountId: string) => {
    const user = NEFriendUserCache.getInstance().getFriendById(accountId)
    if (user) {
      this.addToContact(user)
    }
  }

  constructor() {
    ContactRepo.listener.on('updateUserInfo', this.updateUserInfoFun)
    ContactRepo.listener.on('updateFriendInfo', this.updateFriendInfoFun)
    ContactRepo.listener.on('removeFriendInfo', this.removeFriendInfoFun)
    ContactRepo.listener.on('addBlockAccount', this.addBlockAccountFun)
    ContactRepo.listener.on('removeBlockAccount', this.removeBlockAccountFun)
  }

  // 获取好友列表
  async getFriendList(filterList: string[] = []): Promise<NEContactSection[] | undefined> {
    try {
      let friendList: NEUserWithFriend[] = []
      if (NEFriendUserCache.getInstance().isEmpty()) {
        await ContactRepo.getFriendList()
      }

      friendList = NEFriendUserCache.getInstance().getFriendListNotInBlocklist()
      if (friendList) {
        this.friendList = friendList
        const contactList = await this.formatFriends(friendList, filterList)
        this.friendSection.pushList(contactList)
        return contactList
      }
    } catch (err) {
      console.error(err)
    }
    return undefined
  }

  // 格式化好友列表（按分组排序）
  async formatFriends(friendList: NEUserWithFriend[], filterList: string[]): Promise<NEContactSection[]> {
    let contactList: NEContactSection[] = []
    let initalDict: Map<string, SelectUserWithFriend[]> = new Map<string, SelectUserWithFriend[]>()
    let digitList: SelectUserWithFriend[] = []
    let specialCharList: SelectUserWithFriend[] = []

    await Promise.all(
      friendList.map(async (friend) => {
        if (friend.user?.accountId && !filterList.includes(friend.user?.accountId)) {
          let name = friend.showName()
          if (name) {
            const inital = await initalLetter(name)
            if (digitRegular.test(inital)) {
              digitList.push(new SelectUserWithFriend(friend))
            } else if (!azRegular.test(inital)) {
              specialCharList.push(new SelectUserWithFriend(friend))
            } else {
              if (initalDict.get(inital)) {
                initalDict.get(inital)?.push(new SelectUserWithFriend(friend))
              } else {
                initalDict.set(inital, [new SelectUserWithFriend(friend)])
              }
            }
          }
        }
      })
    )

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

    // 获取侧边字母导航栏
    this.initalList = contactList.map((value, index, arr) => {
      return value.initial
    })

    return contactList
  }

  // 添加好友到通讯录
  async addToContact(userWithFriend: NEUserWithFriend): Promise<void> {
    let name = userWithFriend.showName()
    let user = new SelectUserWithFriend(userWithFriend)
    if (name) {
      let inital = await initalLetter(name)
      if (digitRegular.test(inital)) {
        inital = '#'
      } else if (!azRegular.test(inital)) {
        inital = '#'
      }

      for (let title = 0; title < this.friendSection.contactSections.length; title++) {
        let contactSection = this.friendSection.contactSections[title]
        // 当前分组已存在
        if (contactSection.initial === inital) {
          // 判断是否已经存在
          for (const friend of contactSection.contacts.contacts) {
            if (friend.user?.accountId === userWithFriend.user?.accountId) {
              return
            }
          }

          // 已有分组中插入
          for (let index = 0; index < contactSection.contacts.contacts.length; index++) {
            if (name < contactSection.contacts.contacts[index].showName()) {
              contactSection.contacts.addData(index, user)
              return
            }
          }
          // 尾插
          contactSection.contacts.push(user)
          return
        }
      }

      // 无当前分组
      let contactSection = new NEContactSection(inital, [userWithFriend])
      if (inital !== '#') {
        for (let index = 0; index < this.friendSection.contactSections.length; index++) {
          // 保证字母分组在【#】之前
          if (this.friendSection.contactSections[index].initial === '#') {
            this.friendSection.addData(index, contactSection)
            return
          }
          if (inital < this.friendSection.contactSections[index].initial) {
            this.friendSection.addData(index, contactSection)
            return
          }
        }
      }
      // 尾插
      this.friendSection.push(contactSection)
    }
  }

  // 从通讯录中移除好友
  removeFromContact(accountId: string) {
    for (let title = 0; title < this.friendSection.contactSections.length; title++) {
      const contactSection = this.friendSection.contactSections[title]
      contactSection.contacts.delete(accountId)
      if (contactSection.contacts.contacts.length <= 0) {
        this.friendSection.delete(contactSection.initial)
      }
    }
  }

  // 查询好友并返回
  findContactModel(accountId: string): SelectUserWithFriend | undefined {
    if (NEFriendUserCache.getInstance().isFriend(accountId)) {
      for (const section of this.friendSection.contactSections) {
        let model = section?.contacts.contacts.find(contact => contact.user?.accountId === accountId)
        if (model) {
          return model
        }
      }
    }
    return undefined
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

  onDestroy() {
    ContactRepo.listener.off('updateUserInfo', this.updateUserInfoFun)
    ContactRepo.listener.off('updateFriendInfo', this.updateFriendInfoFun)
    ContactRepo.listener.off('removeFriendInfo', this.removeFriendInfoFun)
    ContactRepo.listener.off('addBlockAccount', this.addBlockAccountFun)
    ContactRepo.listener.off('removeBlockAccount', this.removeBlockAccountFun)
  }
}