/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEUserWithFriend, TeamMemberWithUser } from "@nimkit/chatkit"
import { V2NIMMessage, V2NIMUser } from "@nimsdk/base"
import { SearchFTSHistoryAbs } from "./SearchFTSHistoryAbs"

/**
 * 日期搜索消息模型
 * 同时支持 P2P 和 Team 会话
 */
@ObservedV2
export class SearchDateMessage implements SearchFTSHistoryAbs {
  message: V2NIMMessage
  // P2P 会话使用
  @Trace userWithFriend?: NEUserWithFriend
  // Team 会话使用
  @Trace teamMember?: TeamMemberWithUser
  @Trace user?: V2NIMUser // 如果没有 teamMember，只能用 user 了

  constructor(
    message: V2NIMMessage,
    userWithFriend?: NEUserWithFriend,
    teamMember?: TeamMemberWithUser,
    user?: V2NIMUser
  ) {
    this.message = message
    this.userWithFriend = userWithFriend
    this.teamMember = teamMember
    this.user = user
  }

  public getAvatar(): string | undefined {
    // P2P 会话优先使用 userWithFriend
    if (this.userWithFriend) {
      return this.userWithFriend.getAvatar()
    }
    // Team 会话优先使用 teamMember
    if (this.teamMember) {
      return this.teamMember.getAvatar()
    }
    // 兜底使用 user
    if (this.user) {
      return this.user.avatar
    }
    return undefined
  }

  public getAvatarName(): string {
    let avatarName = ''
    if (this.userWithFriend) {
      return this.userWithFriend.getAvatarName()
    }
    if (this.teamMember) {
      return this.teamMember.getAvatarName()
    }
    if (this.user) {
      avatarName = this.user.name || this.user.accountId
    }
    return avatarName.length > 2 ? avatarName.substring(avatarName.length - 2, avatarName.length) : avatarName
  }

  public getAccId(): string {
    if (this.userWithFriend) {
      return this.userWithFriend.getAccId()
    }
    if (this.teamMember) {
      return this.teamMember.getAccId()
    }
    if (this.user) {
      return this.user.accountId
    }
    return ''
  }

  public getNickname(): string {
    if (this.userWithFriend) {
      return this.userWithFriend.showName()
    }
    if (this.teamMember) {
      return this.teamMember.getNickname()
    }
    if (this.user) {
      return this.user.name ?? this.user.accountId
    }
    return ''
  }
}
