/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { Logger } from '@nimkit/common'
import {
  MessageReactionEmoji,
  MessageReactionEmojiProvider
} from '../model/MessageReactionEmoji'
import {
  QUICK_REACTION_INDEXES,
  REACTION_EMOJI_COUNT,
  reactionIndexToEmojiFile
} from '../utils/MessageReactionUtils'

const CUSTOM_REACTION_INDEX_START: number = 1000

class DefaultMessageReactionEmojiProvider implements MessageReactionEmojiProvider {
  private emojis: MessageReactionEmoji[] = []
  private emojiMap: Map<number, MessageReactionEmoji> = new Map<number, MessageReactionEmoji>()

  constructor() {
    for (let index = 1; index <= REACTION_EMOJI_COUNT; index++) {
      const emojiFile = reactionIndexToEmojiFile(index)
      if (emojiFile !== undefined) {
        const emoji = new MessageReactionEmoji(index, $rawfile(emojiFile), `emoji_${index}`)
        this.emojis.push(emoji)
        this.emojiMap.set(index, emoji)
      }
    }
  }

  getAllEmojis(): MessageReactionEmoji[] {
    return this.emojis
  }

  getEmoji(index: number): MessageReactionEmoji | undefined {
    return this.emojiMap.get(index)
  }
}

export class MessageReactionManager {
  private static provider: MessageReactionEmojiProvider = new DefaultMessageReactionEmojiProvider()
  private static customEmojis: Map<number, MessageReactionEmoji> = new Map<number, MessageReactionEmoji>()
  private static quickReactionIndexes: number[] = QUICK_REACTION_INDEXES.slice()

  static addCustomEmoji(index: number, icon: ResourceStr, description: string = ''): void {
    if (index < CUSTOM_REACTION_INDEX_START) {
      Logger.error('ChatKitUI', `[MessageReaction] custom emoji index must be >= ${CUSTOM_REACTION_INDEX_START}: ${index}`)
      return
    }
    MessageReactionManager.customEmojis.set(index, new MessageReactionEmoji(index, icon, description))
  }

  static setEmojiProvider(provider: MessageReactionEmojiProvider): void {
    MessageReactionManager.provider = provider
    MessageReactionManager.customEmojis.clear()
  }

  /** 设置快捷 Reaction 索引顺序，过滤非正整数和重复项。 */
  static setQuickReactionIndexes(indexes: number[]): void {
    const result: number[] = []
    const seen: Set<number> = new Set<number>()
    indexes.forEach((index: number): void => {
      if (!Number.isInteger(index) || index <= 0 || seen.has(index)) {
        return
      }
      seen.add(index)
      result.push(index)
    })
    MessageReactionManager.quickReactionIndexes = result
  }

  static getQuickReactionIndexes(showExpandButton: boolean = false): number[] {
    const indexes = MessageReactionManager.quickReactionIndexes
    return (showExpandButton ? indexes.slice(0, 6) : indexes).slice()
  }

  static getEmoji(index: number): MessageReactionEmoji | undefined {
    const customEmoji = MessageReactionManager.customEmojis.get(index)
    if (customEmoji !== undefined) {
      return customEmoji
    }
    try {
      return MessageReactionManager.provider.getEmoji(index)
    } catch (error) {
      Logger.error('ChatKitUI', `[MessageReaction] get emoji failed: ${error}`)
      return undefined
    }
  }

  static getAllEmojis(): MessageReactionEmoji[] {
    const result: MessageReactionEmoji[] = []
    const emojiPositions: Map<number, number> = new Map<number, number>()
    try {
      MessageReactionManager.provider.getAllEmojis().forEach((emoji: MessageReactionEmoji): void => {
        if (MessageReactionManager.customEmojis.has(emoji.index)) {
          return
        }
        const position = emojiPositions.get(emoji.index)
        if (position === undefined) {
          emojiPositions.set(emoji.index, result.length)
          result.push(emoji)
        } else {
          result[position] = emoji
        }
      })
    } catch (error) {
      Logger.error('ChatKitUI', `[MessageReaction] get all emojis failed: ${error}`)
    }
    MessageReactionManager.customEmojis.forEach((emoji: MessageReactionEmoji): void => {
      result.push(emoji)
    })
    return result
  }
}
