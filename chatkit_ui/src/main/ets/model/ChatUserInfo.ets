/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, NEFriendUserCache } from '@nimkit/chatkit';
import { V2NIMUser } from '@nimsdk/base';
import { ChatInfo } from './ChatInfo';

@ObservedV2
export class ChatUserInfo extends ChatInfo {
  @Trace currentUser: V2NIMUser | undefined = undefined;
  @Trace chatUser: V2NIMUser | undefined = undefined;

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

  getChatUserAvatarName(): string {
    let name = '';
    let accountId = this.targetId;
    if (NEFriendUserCache.getInstance().isFriend(accountId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (friendInfo !== undefined) {
        name = friendInfo.showName(false)
      }
    }
    if (this.chatUser !== undefined) {
      name = this.chatUser?.name ?? '';
    }
    if (name === '') {
      name = accountId;
    }

    if (name !== '') {
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
    if (name !== '') {
      name = name.substring(name.length - 2, name.length)
    }
    return name;
  }

  getChatUserShowName(): string {
    let name = '';
    if (NEFriendUserCache.getInstance().isFriend(this.targetId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(this.targetId)
      if (friendInfo !== undefined) {
        name = friendInfo.showName(true)
      }
    }
    if (name === '' && this.chatUser !== undefined) {
      name = this.chatUser?.name ?? '';
    }

    if (name === '') {
      name = this.targetId;
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

  getChatUserAvatarUrl(): string {
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