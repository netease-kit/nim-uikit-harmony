/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, NEFriendUserCache } from '@nimkit/chatkit';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { V2NIMFriend, V2NIMMessage, V2NIMP2PMessageReadReceipt, V2NIMUser } from '@nimsdk/base';
import { ChatInfo } from './ChatInfo';

@ObservedV2
export class ChatUserInfo extends ChatInfo {
  @Trace currentUser: V2NIMUser | undefined = undefined;
  @Trace chatUser: V2NIMUser | undefined = undefined;
  @Trace chatFriend: V2NIMFriend | undefined = undefined;
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

  setChatFriend(friend: V2NIMFriend | undefined) {
    this.chatFriend = friend;
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
    for (let index = super.msgList.totalCount() - 1; index >= 0; index--) {
      if (super.msgList.messageData[index].readCount > 0) {
        break
      } else if (readCount == -1) {
        let hasRead = readReceipt?.timestamp >= super.msgList.messageData[index].getCreateTime()
        readCount = hasRead ? 1 : 0;
      }
      super.msgList.messageData[index].readCount = readCount
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
    let accountId: string = ""
    if ((param as V2NIMMessage).senderId) {
      accountId = (param as V2NIMMessage).senderId
    } else {
      accountId = param as string;
    }

    if (accountId === ChatKitClient.getLoginUserId()) {
      return this.getCurrentUserAvatarName()
    }

    let name = '';
    if (this.chatFriend) {
      name = this.chatFriend?.alias ?? '';
    }
    if (name === '' && NEFriendUserCache.getInstance().isFriend(accountId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (friendInfo !== undefined) {
        name = friendInfo.showName()
      }
    }
    if (name === '' && this.chatUser !== undefined) {
      name = this.chatUser?.name ?? '';
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
    if (name === '') {
      name = accountId;
    }
    if (name !== '' && name.length > 2) {
      name = name.substring(name.length - 2, name.length)
    }
    return name;
  }

  getChatUserShowName(param?: string | V2NIMMessage, alias: boolean = true, teamNick: boolean = true): string {
    let accountId: string = ""
    if ((param as V2NIMMessage).senderId) {
      accountId = (param as V2NIMMessage).senderId
    } else {
      accountId = param as string;
    }

    if (accountId === ChatKitClient.getLoginUserId()) {
      return this.getCurrentUserShowName()
    }

    let name = '';
    if (NEFriendUserCache.getInstance().isFriend(accountId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (friendInfo !== undefined) {
        name = friendInfo.showName(alias)
      }
    }
    if (name === '' && this.chatUser !== undefined) {
      name = this.chatUser?.name ?? '';
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
    if (name === '') {
      name = ChatKitClient.getLoginUserId();
    }
    return name;
  }

  getChatUserAvatarUrl(param?: string | V2NIMMessage): string {
    let accountId: string = ""
    if ((param as V2NIMMessage).senderId) {
      accountId = (param as V2NIMMessage).senderId
    } else {
      accountId = param as string;
    }

    if (accountId === ChatKitClient.getLoginUserId()) {
      return this.getCurrentUserAvatarUrl()
    }

    let result: string = '';
    if (this.chatUser !== undefined) {
      result = this.chatUser?.avatar ? this.chatUser?.avatar : '';
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
    if (result == null || result.trim() === '') {
      result = '';
    }
    return result;
  }

  getConversationName(): string {
    let result: string = '';
    if (NEFriendUserCache.getInstance().isFriend(this.targetId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(this.targetId)
      if (friendInfo !== undefined) {
        result = friendInfo.showName(true)
      }
    } else if (this.chatUser !== undefined) {
      result = this.chatUser?.name !== null ? this.chatUser?.name : this.chatUser?.accountId;
    }
    return result;
  }
}