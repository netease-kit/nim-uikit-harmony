/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMFriend, V2NIMUser } from '@nimsdk/base';

interface UserWithFriendParams {
  friend?: V2NIMFriend;
  user?: V2NIMUser;
}

@ObservedV2
export class UserWithFriend {
  @Trace user?: V2NIMUser
  @Trace friend?: V2NIMFriend

  constructor(params: UserWithFriendParams) {
    this.friend = params.friend
    if (params.user) {
      this.user = params.user
    } else {
      this.user = params.friend?.userProfile
    }
  }

  /// 获取显示名称
  /// (备注) > 昵称 > accid
  /// - Parameter showAlias: 是否优先显示备注
  public showName(showAlias: boolean = true): string {
    if (showAlias && this.friend?.alias && this.friend.alias.length > 0) {
      return this.friend?.alias
    }

    if (this.user?.name && this.user.name.length > 0) {
      return this.user.name
    }

    return this.user?.accountId ?? ""
  }

  /// 获取简称 (尾部截取)
  /// - Parameter showAlias: 是否优先显示备注
  /// - Parameter count: 尾部截取长度
  public shortName(showAlias: boolean = true, count: number = 2): string {
    let name = this.showName(showAlias)
    if (name) {
      const start: number = (name.length - count) > 0 ? name.length - count : 0
      const end: number = name.length
      return name.substring(start, end)
    }
    return ""
  }

  /**
   * 获取好友备注
   * @returns
   */
  public getAlias() {
    return this.friend?.alias
  }
}