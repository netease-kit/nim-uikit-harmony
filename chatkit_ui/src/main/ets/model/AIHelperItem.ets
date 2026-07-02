/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

/**
 * AI 助聊数据项
 * 对齐 Android AIHelperView.AIHelperItem
 */
export class AIHelperItem {
  /** 回复内容 */
  content: string
  /** 标签文本（如"关心""幽默"） */
  tag: string
  /** 标签背景色 */
  tagBgColor: ResourceColor = '#FFE0E6'
  /** 标签文字色 */
  tagTextColor: ResourceColor = '#E75257'

  constructor(content: string, tag: string) {
    this.content = content
    this.tag = tag
  }
}
