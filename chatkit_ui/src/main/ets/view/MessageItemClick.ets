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
  // 头像长按
  onAvatarLongPress?: (msg: NIMMessageInfo | undefined) => void
  // 已撤回消息点击编辑
  onRevokeEditClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
  // 已读未读点击
  onReadReceiptClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
  // 多选选择事件
  onMultiSelect?: (select: boolean, msg: NIMMessageInfo | undefined) => void
  // 点击回复消息
  onReplyClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
  // 发送失败点击
  onSendFailClick?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
  // 长按译文区域
  onTranslatedAreaLongClick?: (event: GestureEvent, msg: NIMMessageInfo | undefined) => void
  // 文本选择范围变化
  onTextSelectionChange?: (msg: NIMMessageInfo | undefined, text: string, start: number, end: number,
    isTranslation: boolean) => void
  // AI 流式消息 - 停止输出
  onAIStreamStop?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
  // AI 流式消息 - 重新生成
  onAIStreamRefresh?: (event: ClickEvent, msg: NIMMessageInfo | undefined) => void
}
