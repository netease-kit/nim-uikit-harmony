/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMFriend, V2NIMTeamMember, V2NIMTeamMemberRole, V2NIMUser } from '@nimsdk/base'

/**
 * 群成员，好友，用户信息的集合
 */
export class TeamMemberWithUser {
  //群成员信息
  teamMember: V2NIMTeamMember
  //好友信息
  friendInfo?: V2NIMFriend
  //用户信息
  userInfo?: V2NIMUser

  constructor(teamMember: V2NIMTeamMember,
    friendInfo?: V2NIMFriend, userInfo?: V2NIMUser) {
    this.teamMember = teamMember
    this.friendInfo = friendInfo
    this.userInfo = userInfo
  }

  /**
   * 获取头像
   * @returns
   */
  getAvatar(): string | undefined {
    return this.userInfo?.avatar
  }

  /**
   * 获取头像nick
   * @returns
   */
  getAvatarName(): string {
    let avatarName = ''
    if (this.friendInfo && this.friendInfo.alias &&
      this.friendInfo.alias.length > 0) {
      avatarName = this.friendInfo.alias
    } else if (this.userInfo && this.userInfo.name && this.userInfo.name.length > 0) {
      avatarName = this.userInfo.name
    } else {
      avatarName = this.teamMember.accountId
    }
    return avatarName.length > 2 ? avatarName.substring(avatarName.length - 2, avatarName.length) : avatarName
  }

  /**
   * 获取@的名称，不包含好友备注
   */
  getAitName(): string {
    //群昵称
    if (this.teamMember.teamNick &&
      this.teamMember.teamNick.length > 0) {
      return this.teamMember.teamNick
    }

    //用户名
    if (this.userInfo && this.userInfo.name && this.userInfo.name.length > 0) {
      return this.userInfo.name
    }
    //最后accId
    return this.teamMember.accountId
  }

  /**
   * 是否是群主
   * @returns
   */
  isOwner(): boolean {
    return this.teamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
  }

  /**
   * 是否是管理员
   * @returns
   */
  isManager(): boolean {
    return this.teamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
  }

  /**
   * 获取昵称
   * @returns
   */
  getNickname(): string {
    //优先好友备注
    if (this.friendInfo && this.friendInfo.alias &&
      this.friendInfo.alias.length > 0) {
      return this.friendInfo.alias
    }

    //其次群昵称
    if (this.teamMember.teamNick &&
      this.teamMember.teamNick.length > 0) {
      return this.teamMember.teamNick
    }

    //再次用户名
    if (this.userInfo && this.userInfo.name && this.userInfo.name.length > 0) {
      return this.userInfo.name
    }
    //最后accId
    return this.teamMember.accountId
  }

  /**
   * 获取群成员Id
   * @returns
   */
  getAccId(): string {
    return this.teamMember.accountId
  }
}

/**
 * 群成员请求返回结果
 */
export interface TeamMemberResult {
  //是否结束
  finished: boolean
  //下次请求token
  nextToken: string
  //成员列表
  memberList: TeamMemberWithUser[]
}