/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

export class MessageReactionEmoji {
  index: number
  icon: ResourceStr
  description: string

  constructor(index: number, icon: ResourceStr, description: string = '') {
    this.index = index
    this.icon = icon
    this.description = description
  }
}

export interface MessageReactionEmojiProvider {
  getAllEmojis(): MessageReactionEmoji[]
  getEmoji(index: number): MessageReactionEmoji | undefined
}
