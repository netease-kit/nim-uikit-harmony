/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import { ChatInfo } from './ChatInfo';
import { V2NIMFriend, V2NIMMessage, V2NIMTeamMessageReadReceipt, V2NIMUser } from '@nimsdk/base';
import { V2NIMTeam, V2NIMTeamMember } from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMTeamService';
import { NIMMessageInfo } from './NIMMessageInfo';
import { NEFriendUserCache } from '@nimkit/chatkit';
import { ChatKitClient, NEAIUserCache } from '@nimkit/chatkit';

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
      if (msg && readReceipt.readCount <= msg.readCount) {
        // 操作过了，不管，因为 onTeamMessageReceiptsHandler 给的数组里面是没有排序的，可能导致 readCount 还会下降
        return;
      }
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

  removeTeamFriend(accountId: string) {
    this.teamUserFriendMap.delete(accountId);
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
    let accountId: string = this.getAccountId(param)

    const aiUser = NEAIUserCache.getAIUser(accountId)
    if (aiUser) {
      return aiUser.avatar ?? ''
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
    return NEFriendUserCache.mineUserCache?.user?.avatar ?? '';
  }

  getChatUserAvatarName(param?: string | V2NIMMessage): string {
    let accountId: string = this.getAccountId(param)

    const aiUser = NEAIUserCache.getAIUser(accountId)
    if (aiUser) {
      let aiName = aiUser.name ?? aiUser.accountId
      return aiName.length > 2 ? aiName.substring(aiName.length - 2, aiName.length) : aiName
    }

    let result = '';
    if (this.teamUserFriendMap.has(accountId)) {
      let friend = this.teamUserFriendMap.get(accountId)
      if (friend?.userProfile?.name) {
        result = friend.userProfile.name
      }
    }
    if (result === '' && NEFriendUserCache.getInstance().isFriend(accountId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (friendInfo !== undefined) {
        result = friendInfo.getAvatarName()
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
    let accountId: string = this.getAccountId(param)

    const aiUser = NEAIUserCache.getAIUser(accountId)
    if (aiUser) {
      return aiUser.name ?? aiUser.accountId
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

  getConversationName(): string {
    let result: string = '';
    if (this.team !== undefined) {
      result = this.team?.name
    } else {
      result = this.targetId
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
