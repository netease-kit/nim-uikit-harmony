/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatInfo } from './ChatInfo';
import { V2NIMUser } from '@nimsdk/base';
import { V2NIMTeam, V2NIMTeamMember } from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMTeamService'
import { NIMMessageInfo } from './NIMMessageInfo';
import { NEFriendUserCache } from '@nimkit/chatkit/src/main/ets/NEFriendUserCache';
import { ChatKitClient } from '@nimkit/chatkit';

@ObservedV2
export class ChatTeamInfo extends ChatInfo {
  @Trace team?: V2NIMTeam | undefined = undefined;
  @Trace teamMemberMap = new Map<string, V2NIMTeamMember>();
  @Trace teamUserMap = new Map<string, V2NIMUser>();

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
    console.log('net ease team info', this.team?.teamId);
    if (team !== undefined && team.name != '') {
      console.log('net ease team name', this.team?.name);
      this.conversationName = team.name;
    }
  }

  setTeamMember(member: V2NIMTeamMember) {
    this.teamMemberMap.set(member.accountId, member);
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

  getChatUserAvatarUrl(accountId: string): string {
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

  getChatUserAvatarName(accountId: string): string {
    let result = '';

    if (NEFriendUserCache.getInstance().isFriend(accountId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (friendInfo !== undefined) {
        result = friendInfo.shortName(false)
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

  getCurrentUserAvatarName(): string {
    let accountId = ChatKitClient.getLoginUserId()
    let result = '';
    if (result == null || result.trim() === '') {
      result = this.teamUserMap.get(accountId)?.name ?? '';
    }

    if (result == null || result.trim() === '') {
      result = accountId;
    }
    return result;
  }

  getChatUserShowName(accountId: string): string {
    let result = '';
    if (this.teamMemberMap.has(accountId)) {
      result = this.teamMemberMap.get(accountId)?.teamNick ?? '';
    }
    if ((result == null || result.trim() === '') && NEFriendUserCache.getInstance().isFriend(accountId)) {
      let friendInfo = NEFriendUserCache.getInstance().getFriendById(accountId)
      if (friendInfo !== undefined) {
        result = friendInfo.showName(true)
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
}