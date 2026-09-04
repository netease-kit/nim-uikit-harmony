/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { NEUserWithFriend, TeamMemberWithUser } from "@nimkit/chatkit"
import { V2NIMMessage, V2NIMUser } from "@nimsdk/base"
import { SearchFTSHistoryAbs } from "./SearchFTSHistoryAbs"

/**
 * 统一的全文搜索历史消息模型
 * 同时支持 P2P 和 Team 场景
 */
@ObservedV2
export class SearchFTSHistory implements SearchFTSHistoryAbs {
  @Trace keyword: string
  @Trace message: V2NIMMessage
  // P2P 场景使用
  @Trace userWithFriend?: NEUserWithFriend
  // Team 场景使用
  @Trace teamMember?: TeamMemberWithUser
  @Trace user?: V2NIMUser // 如果没有 teamMember，只能用 user 了

  constructor(
    keyword: string,
    message: V2NIMMessage,
    userWithFriend?: NEUserWithFriend,
    teamMember?: TeamMemberWithUser,
    user?: V2NIMUser
  ) {
    this.keyword = keyword
    this.message = message
    this.userWithFriend = userWithFriend
    this.teamMember = teamMember
    this.user = user
  }

  /**
   * 创建 P2P 场景的实例
   */
  static createForP2P(keyword: string, message: V2NIMMessage, userWithFriend?: NEUserWithFriend): SearchFTSHistory {
    return new SearchFTSHistory(keyword, message, userWithFriend, undefined, undefined)
  }

  /**
   * 创建 Team 场景的实例
   */
  static createForTeam(keyword: string, message: V2NIMMessage, teamMember?: TeamMemberWithUser,
    user?: V2NIMUser): SearchFTSHistory {
    return new SearchFTSHistory(keyword, message, undefined, teamMember, user)
  }

  public getAvatar(): string | undefined {
    // 优先使用 P2P 的 userWithFriend
    if (this.userWithFriend) {
      return this.userWithFriend.getAvatar()
    }
    // 其次使用 Team 的 teamMember
    if (this.teamMember) {
      return this.teamMember.getAvatar()
    }
    // 最后使用 user
    if (this.user) {
      return this.user.avatar
    }
    return undefined
  }

  public getAvatarName(): string {
    // 优先使用 P2P 的 userWithFriend
    if (this.userWithFriend) {
      return this.userWithFriend.getAvatarName()
    }
    // 其次使用 Team 的 teamMember
    if (this.teamMember) {
      return this.teamMember.getAvatarName()
    }
    // 最后使用 user
    if (this.user) {
      let avatarName = this.user.name || this.user.accountId
      return avatarName.length > 2 ? avatarName.substring(avatarName.length - 2, avatarName.length) : avatarName
    }
    return ''
  }

  public getAccId(): string {
    // 优先使用 P2P 的 userWithFriend
    if (this.userWithFriend) {
      return this.userWithFriend.getAccId()
    }
    // 其次使用 Team 的 teamMember
    if (this.teamMember) {
      return this.teamMember.getAccId()
    }
    // 最后使用 user
    if (this.user) {
      return this.user.accountId
    }
    return ''
  }

  public getNickname(): string {
    // 优先使用 P2P 的 userWithFriend
    if (this.userWithFriend) {
      return this.userWithFriend.showName()
    }
    // 其次使用 Team 的 teamMember
    if (this.teamMember) {
      return this.teamMember.getNickname()
    }
    // 最后使用 user
    if (this.user) {
      return this.user.name ?? this.user.accountId
    }
    return ''
  }
}
