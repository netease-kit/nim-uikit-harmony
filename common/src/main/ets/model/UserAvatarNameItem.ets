/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import { AvatarItem } from '../view/CommonAvatar';

/**
 * 头像和昵称显示的数据类型
 */
export interface UserAvatarNameItem {
  //头像
  avatar: AvatarItem,

  //用户名
  name: string
}