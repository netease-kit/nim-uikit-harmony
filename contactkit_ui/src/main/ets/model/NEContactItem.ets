/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@ObservedV2
export class NEContactItem {
  @Trace avatarIcon?: Resource;
  @Trace title?: ResourceStr;
  routerUrl?: string;
  @Trace unreadCount?: string
  backAction?: () => void;

  constructor(avatarIcon?: Resource,
    title?: ResourceStr,
    routerUrl?: string,
    unreadCount?: string,
    backAction?: () => void) {
    this.avatarIcon = avatarIcon
    this.title = title
    this.routerUrl = routerUrl
    this.unreadCount = unreadCount
    this.backAction = backAction
  }
}