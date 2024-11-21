/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatInfo } from './ChatInfo';
import { V2NIMFriend, V2NIMMessage, V2NIMTeamMessageReadReceipt, V2NIMUser } from '@nimsdk/base';
import { V2NIMTeam, V2NIMTeamMember } from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMTeamService';
import { NIMMessageInfo } from './NIMMessageInfo';
import { NEFriendUserCache } from '@nimkit/chatkit/src/main/ets/NEFriendUserCache';
import { ChatKitClient } from '@nimkit/chatkit';

@ObservedV2
export class ChatTeamInfo extends ChatInfo {
  @Trace team?: V2NIMTeam | undefined = undefined;
  @Trace teamMemberMap = new Map<string, V2NIMTeamMember>();
  @Trace teamUserMap = new Map<string, V2NIMUser>();
  // 用于动态监听好友信息变更时，更新会话页面好友数据
  @Trace teamUserFriendMap = new Map<string, V2NIMFriend>();
  teamMessageReadReceipt = new Map<string, V2NIMTeamMessageReadReceipt>();

  constructor(conversationId: string) {
    super(conversationId)
    this.conversationName = conversationId;
  }

  setConversationId(conversationId: string): void {
    super.setConversationId(conversationId)
    this.conversationName = conversationId;
  }

  setTeam(team: V2NIMTeam | undefined) {
    this.team = team;
    if (team !== undefined && team.name != '') {
      this.conversationName = team.name;
    }
  }

  setTeamMember(member: V2NIMTeamMember) {
    this.teamMemberMap.set(member.accountId, member);
  }

  setTeamReadReadReceipt(readReceipts: V2NIMTeamMessageReadReceipt[]) {
    readReceipts.forEach((readReceipt) => {
      this.teamMessageReadReceipt.set(readReceipt.messageClientId, readReceipt);
      let msg = this.getMessage(readReceipt.messageClientId);
      msg?.setReadCount(readReceipt.readCount, readReceipt.unreadCount)
    })
  }

  pushDataList(msgList: NIMMessageInfo[]) {
    msgList.forEach(element => {
      this.msgList.push(element);
    });
  }

  addTeamUser(userList: V2NIMUser[]) {
    userList.forEach((user) => {
      this.teamUserMap.set(user.accountId, user);
    });
  }

  addTeamFriend(friend: V2NIMFriend) {
    this.teamUserFriendMap.set(friend.accountId, friend);
  }

  addTeamMember(member: V2NIMTeamMember[]) {
    member.forEach((member) => {
      this.teamMemberMap.set(member.accountId, member);
    });
  }

  getTeamMember(accountId: string): V2NIMTeamMember | undefined {
    if (this.teamMemberMap.has(accountId)) {
      return this.teamMemberMap.get(accountId);
    }
    return undefined;
  }

  getChatUserAvatarUrl(param?: string | V2NIMMessage): string {
    let accountId: string = ""
    if ((param as V2NIMMessage).senderId) {
      accountId = (param as V2NIMMessage).senderId
    } else {
      accountId = param as string;
    }

    if (this.teamUserMap.has(accountId)) {
      return this.teamUserMap.get(accountId)?.avatar ?? '';
    }
    return '';
  }

  getCurrentUserAvatarUrl(): string {
    let accountId = ChatKitClient.getLoginUserId()
    if (this.teamUserMap.has(accountId)) {
      return this.teamUserMap.get(accountId)?.avatar ?? '';
    }
    return '';
  }

  getChatUserAvatarName(param?: string | V2NIMMessage): string {
    let accountId: string = ""
    if ((param as V2NIMMessage).senderId) {
      accountId = (param as V2NIMMessage).senderId
    } else {
      accountId = param as string;
    }

    let result = '';
    if (this.teamUserFriendMap.has(accountId)) {
      let friend = this.teamUserFriendMap.get(accountId)
      if (friend && friend.alias !== undefined) {
        result = friend.alias ?? ''
      }
    } else if (NEFriendUserCache.getInstance().isFriend(accountId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (friendInfo !== undefined) {
        result = friendInfo.shortName(true)
      }
    }

    if (result == null || result.trim() === '') {
      result = this.teamUserMap.get(accountId)?.name ?? '';
    }

    if (result == null || result.trim() === '') {
      result = accountId;
    }
    if (result !== '' && result.length > 2) {
      result = result.substring(result.length - 2, result.length)
    }
    return result
  }

  getCurrentUserAvatarName(): string {
    let accountId = ChatKitClient.getLoginUserId()
    let result = '';
    if (result == null || result.trim() === '') {
      result = this.teamUserMap.get(accountId)?.name ?? '';
    }

    if (result == null || result.trim() === '') {
      result = accountId;
    }
    if (result !== '' && result.length > 2) {
      result = result.substring(result.length - 2, result.length)
    }
    return result
  }

  getChatUserShowName(param?: string | V2NIMMessage, alias: boolean = true, teamNick: boolean = true): string {
    let accountId: string = ""
    if ((param as V2NIMMessage).senderId) {
      accountId = (param as V2NIMMessage).senderId
    } else {
      accountId = param as string;
    }

    let result = '';
    if (this.teamUserFriendMap.has(accountId)) {
      let friend = this.teamUserFriendMap.get(accountId)
      if (friend && friend.alias !== undefined) {
        result = friend.alias ?? ''
      }
    }
    let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
    //1,备注优先
    if (alias && (result == null || result.trim() === '') && friendInfo) {
      result = friendInfo.getAlias() ?? ''
    }
    //2，群昵称次之
    if (teamNick && (result == null || result.trim() === '') && this.teamMemberMap.has(accountId)) {
      result = this.teamMemberMap.get(accountId)?.teamNick ?? '';
    }
    //3，好友名称再次之
    if ((result == null || result.trim() === '') && NEFriendUserCache.getInstance().isFriend(accountId)) {
      if (friendInfo !== undefined) {
        result = friendInfo.showName(alias)
      }
    }
    if (result == null || result.trim() === '') {
      result = this.teamUserMap.get(accountId)?.name ?? '';
    }

    if (result == null || result.trim() === '') {
      result = accountId;
    }
    return result;
  }

  getCurrentUserShowName(): string {
    let result = '';
    let accountId = ChatKitClient.getLoginUserId()
    if (this.teamMemberMap.has(accountId)) {
      result = this.teamMemberMap.get(accountId)?.teamNick ?? '';
    }
    if (result == null || result.trim() === '') {
      result = this.teamUserMap.get(accountId)?.name ?? '';
    }

    if (result == null || result.trim() === '') {
      result = accountId;
    }
    return result;
  }

  /**
   * 获取用成员用户信息
   * @param accountId
   * @returns
   */
  getMemberUserById(accountId: string) {
    return this.teamUserMap.get(accountId)
  }

  /**
   * 获取当前成员的群管理员
   * @returns
   */
  getCurrentUserTeamMember() {
    let accId = ChatKitClient.getLoginUserId()
    return this.teamMemberMap.get(accId)
  }
}