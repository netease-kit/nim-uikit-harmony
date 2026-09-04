/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, NEAIUserCache, NEFriendUserCache } from '@nimkit/chatkit';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { V2NIMMessage, V2NIMP2PMessageReadReceipt, V2NIMUser } from '@nimsdk/base';
import { ChatInfo } from './ChatInfo';

@ObservedV2
export class ChatUserInfo extends ChatInfo {
  @Trace currentUser: V2NIMUser | undefined = undefined;
  @Trace chatUser: V2NIMUser | undefined = undefined;
  @Trace extraUserMap = new Map<string, V2NIMUser>();
  readReceipt: V2NIMP2PMessageReadReceipt | undefined = undefined;
  readReceiptMsg: NIMMessageInfo | undefined = undefined;

  constructor() {
    super('');
  }

  setConversationId(conversationId: string): void {
    super.setConversationId(conversationId)
    this.conversationName = this.getConversationName();
  }

  setCurrentUser(user: V2NIMUser | undefined) {
    this.currentUser = user;
  }

  setChatUser(user: V2NIMUser | undefined) {
    this.chatUser = user;
    this.conversationName = this.getConversationName();
  }

  addExtraUsers(userList: V2NIMUser[]) {
    userList.forEach((user) => {
      this.extraUserMap.set(user.accountId, user)
    })
  }

  updateExtraUser(user: V2NIMUser): boolean {
    if (!this.extraUserMap.has(user.accountId)) {
      return false
    }
    this.extraUserMap.set(user.accountId, user)
    return true
  }

  updateConversationName() {
    this.conversationName = this.getConversationName();
  }

  setMessageReadReceipt(readReceipt: V2NIMP2PMessageReadReceipt | undefined) {
    if (readReceipt == undefined || readReceipt.timestamp == undefined) {
      return
    }
    this.readReceipt = readReceipt
    let readCount = -1
    for (let index = this.msgList.totalCount() - 1; index >= 0; index--) {
      if (this.msgList.messageData[index].readCount > 0) {
        break
      } else if (readCount == -1 || readCount == 0) { // 没算过 or 还没到
        let hasRead = readReceipt?.timestamp >= this.msgList.messageData[index].getCreateTime()
        readCount = hasRead ? 1 : 0;
      }
      this.msgList.messageData[index].readCount = readCount
    }
  }

  updateMessageReadReceipt(message: NIMMessageInfo) {
    super.updateMessageReadReceipt(message)
    if (this.readReceipt == undefined) {
      return
    }
    let hasRead = this.readReceipt?.timestamp >= message.getCreateTime()
    message.readCount = hasRead ? 1 : 0;
  }

  getChatUserAvatarName(param?: string | V2NIMMessage): string {
    let accountId: string = this.getAccountId(param)

    if (accountId === ChatKitClient.getLoginUserId()) {
      return this.getCurrentUserAvatarName()
    }

    const aiUser = NEAIUserCache.getAIUser(accountId)
    if (aiUser) {
      let aiName = aiUser.name ?? aiUser.accountId
      return aiName.length > 2 ? aiName.substring(aiName.length - 2, aiName.length) : aiName
    }

    let name = '';
    let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
    if (friendInfo !== undefined) {
      name = friendInfo.getAvatarName()
    }
    if (name === '' && this.chatUser !== undefined && this.chatUser.accountId === accountId) {
      name = this.chatUser?.name ?? '';
    }
    if (name === '' && this.extraUserMap.has(accountId)) {
      name = this.extraUserMap.get(accountId)?.name ?? ''
    }
    if (name === '') {
      name = accountId;
    }

    if (name !== '' && name.length > 2) {
      name = name.substring(name.length - 2, name.length)
    }
    return name;
  }

  getCurrentUserAvatarName(): string {
    let name = '';
    let accountId = ChatKitClient.getLoginUserId();
    if (this.currentUser !== undefined) {
      name = this.currentUser?.name ?? '';
    }
    if (name === '' && NEFriendUserCache.mineUserCache?.user) {
      name = NEFriendUserCache.mineUserCache.user.name ?? ''
    }
    if (name === '') {
      name = accountId;
    }
    if (name !== '' && name.length > 2) {
      name = name.substring(name.length - 2, name.length)
    }
    return name;
  }

  getChatUserShowName(param?: string | V2NIMMessage, alias: boolean = true, teamNick: boolean = true): string {
    let accountId: string = this.getAccountId(param)

    if (accountId === ChatKitClient.getLoginUserId()) {
      return this.getCurrentUserShowName()
    }

    const aiUser = NEAIUserCache.getAIUser(accountId)
    if (aiUser) {
      return aiUser.name ?? aiUser.accountId
    }

    let name = '';
    let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
    if (friendInfo !== undefined) {
      name = friendInfo.showName(alias)
    }
    if (name === '' && this.chatUser !== undefined && this.chatUser.accountId === accountId) {
      name = this.chatUser?.name ?? '';
    }
    if (name === '' && this.extraUserMap.has(accountId)) {
      name = this.extraUserMap.get(accountId)?.name ?? ''
    }

    if (name === '') {
      name = accountId;
    }
    return name;
  }

  getCurrentUserShowName(): string {
    let name = '';
    if (name === '' && this.currentUser !== undefined) {
      name = this.currentUser?.name ?? '';
    }
    if (name === '' && NEFriendUserCache.mineUserCache?.user) {
      name = NEFriendUserCache.mineUserCache.user.name ?? ''
    }
    if (name === '') {
      name = ChatKitClient.getLoginUserId();
    }
    return name;
  }

  getChatUserAvatarUrl(param?: string | V2NIMMessage): string {
    let accountId: string = this.getAccountId(param)

    if (accountId === ChatKitClient.getLoginUserId()) {
      return this.getCurrentUserAvatarUrl()
    }

    const aiUser = NEAIUserCache.getAIUser(accountId)
    if (aiUser) {
      return aiUser.avatar ?? ''
    }

    let result: string = '';
    if (this.chatUser !== undefined && this.chatUser.accountId === accountId) {
      result = this.chatUser?.avatar ? this.chatUser?.avatar : '';
    }
    if ((result == null || result.trim() === '') && this.extraUserMap.has(accountId)) {
      result = this.extraUserMap.get(accountId)?.avatar ?? ''
    }
    if (result == null || result.trim() === '') {
      result = '';
    }

    return result;
  }

  getCurrentUserAvatarUrl(): string {
    let result: string = '';
    if (this.currentUser !== undefined) {
      result = this.currentUser?.avatar ? this.currentUser?.avatar : '';
    }
    if ((result == null || result.trim() === '') && NEFriendUserCache.mineUserCache?.user) {
      result = NEFriendUserCache.mineUserCache.user.avatar ?? ''
    }
    if (result == null || result.trim() === '') {
      result = '';
    }
    return result;
  }

  getConversationName(): string {
    let result: string = '';
    let friendInfo = NEFriendUserCache.getInstance().getFriendById(this.targetId)
    if (friendInfo !== undefined) {
      result = friendInfo.showName(true)
    } else if (NEAIUserCache.getAIUser(this.targetId)) {
      const aiUser = NEAIUserCache.getAIUser(this.targetId)
      result = aiUser?.name ?? aiUser?.accountId ?? this.targetId
    } else if (this.chatUser !== undefined) {
      result = this.chatUser?.name !== null ? this.chatUser?.name : this.chatUser?.accountId;
    }
    return result;
  }
}
