/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEUserWithFriend } from '@nimkit/chatkit';
import { V2NIMFriendAddApplication, V2NIMFriendAddApplicationStatus } from '@nimsdk/base';

@ObservedV2
export class NEFriendAddApplication {
  /**
   * 申请添加好友的相关信息
   */
  friendAddApplication: V2NIMFriendAddApplication;
  /**
   * 用于显示的用户信息（包含好友信息）
   */
  @Trace displayUserWithFriend?: NEUserWithFriend;
  /**
   * 未读数
   */
  @Trace unreadCount: number = 0
  /**
   * 操作的状态
   */
  @Trace status: V2NIMFriendAddApplicationStatus =
    V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT;
  /**
   * 操作描述
   */
  description?: ResourceStr = $r('app.string.contact_validation_add_me');

  constructor(nimApplication: V2NIMFriendAddApplication) {
    this.friendAddApplication = nimApplication
    this.unreadCount = nimApplication.read === false ? 1 : 0
    this.status = nimApplication.status
  }

  // 设置申请者用户信息
  setApplicantUserWithFriend(userWithFriend?: NEUserWithFriend) {
    this.displayUserWithFriend = userWithFriend
  }

  // 是否是同一申请
  isEqualTo(nimApplication: V2NIMFriendAddApplication): boolean {
    if (this.friendAddApplication.applicantAccountId === nimApplication.applicantAccountId &&
      this.friendAddApplication.recipientAccountId === nimApplication.recipientAccountId) {
      return this.status === nimApplication.status
    }
    return false
  }
}