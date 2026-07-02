/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { AIHelperItem } from './AIHelperItem'

/**
 * AI 助聊点击回调
 * 对齐 Android AIHelperView.AIHelperClickListener
 */
export interface AIHelperClickListener {
  /** 面板展示 */
  onShow: () => void
  /** 点击刷新 */
  onRefreshClick: () => void
  /** 点击重试 */
  onTryAgainClick: () => void
  /** 点击 item：直接发送 */
  onItemClick: (item: AIHelperItem) => void
  /** 点击编辑：填入输入框 */
  onItemEditClick: (item: AIHelperItem) => void
}
