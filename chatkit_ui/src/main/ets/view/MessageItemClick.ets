/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { NIMMessageInfo } from '../model/NIMMessageInfo';

export interface MessageItemClick {
  // 消息点击
  onItemClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
  // 消息长按
  onItemLongClick?: (event: GestureEvent, msg: NIMMessageInfo | undefined) => void
  // 头像点击
  onAvatarClick?: (msg: NIMMessageInfo | undefined) => void
  // 已撤回消息点击编辑
  onRevokeEditClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
  // 已读未读点击
  onReadReceiptClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
}
