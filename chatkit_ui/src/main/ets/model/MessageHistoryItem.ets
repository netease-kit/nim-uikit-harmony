/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

/**
 * AI 助聊消息历史项
 */
export class MessageHistoryItem {
  senderId: string
  text: string

  constructor(senderId: string, text: string) {
    this.senderId = senderId
    this.text = text
  }
}
