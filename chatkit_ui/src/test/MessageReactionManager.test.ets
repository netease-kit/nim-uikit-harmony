/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { ChatKitConfig } from '../main/ets/ChatKitConfig'
import {
  MessageReactionEmoji,
  MessageReactionEmojiProvider
} from '../main/ets/model/MessageReactionEmoji'
import { MessageReactionManager } from '../main/ets/manager/MessageReactionManager'
import { isMessageReactionEnabled } from '../main/ets/utils/MessageReactionUtils'

class TestReactionProvider implements MessageReactionEmojiProvider {
  private emojis: MessageReactionEmoji[]

  constructor(emojis: MessageReactionEmoji[]) {
    this.emojis = emojis
  }

  getAllEmojis(): MessageReactionEmoji[] {
    return this.emojis
  }

  getEmoji(index: number): MessageReactionEmoji | undefined {
    return this.emojis.find((emoji: MessageReactionEmoji): boolean => emoji.index === index)
  }
}

class ThrowingReactionProvider implements MessageReactionEmojiProvider {
  getAllEmojis(): MessageReactionEmoji[] {
    throw new Error('getAllEmojis failed')
  }

  getEmoji(_index: number): MessageReactionEmoji | undefined {
    throw new Error('getEmoji failed')
  }
}

export default function messageReactionManagerTest() {
  describe('MessageReactionManager', () => {
    it('provides all default emojis', 0, () => {
      const emojis = MessageReactionManager.getAllEmojis()

      expect(emojis.length).assertEqual(112)
      expect(emojis[0].index).assertEqual(1)
      expect(emojis[111].index).assertEqual(112)
      expect(MessageReactionManager.getEmoji(85)?.index).assertEqual(85)
    })

    it('appends and overrides custom emojis by index', 0, () => {
      MessageReactionManager.addCustomEmoji(999, 'invalid', 'invalid')
      expect(MessageReactionManager.getEmoji(999)).assertUndefined()

      MessageReactionManager.addCustomEmoji(1001, 'custom-a', 'a')
      expect(MessageReactionManager.getAllEmojis().length).assertEqual(113)
      expect(MessageReactionManager.getAllEmojis()[112].index).assertEqual(1001)
      expect(MessageReactionManager.getEmoji(1001)?.icon).assertEqual('custom-a')

      MessageReactionManager.addCustomEmoji(1001, 'custom-b', 'b')
      expect(MessageReactionManager.getAllEmojis().length).assertEqual(113)
      expect(MessageReactionManager.getEmoji(1001)?.icon).assertEqual('custom-b')
      expect(MessageReactionManager.getEmoji(1001)?.description).assertEqual('b')
    })

    it('replaces the provider and appends new custom emojis afterwards', 0, () => {
      MessageReactionManager.setEmojiProvider(new TestReactionProvider([
        new MessageReactionEmoji(85, 'quick', 'quick'),
        new MessageReactionEmoji(2000, 'provider-custom', 'provider-custom')
      ]))

      expect(MessageReactionManager.getAllEmojis().length).assertEqual(2)
      expect(MessageReactionManager.getEmoji(1001)).assertUndefined()
      expect(MessageReactionManager.getEmoji(1)).assertUndefined()

      MessageReactionManager.addCustomEmoji(1002, 'custom-after-set', 'after-set')
      const emojis = MessageReactionManager.getAllEmojis()
      expect(emojis.length).assertEqual(3)
      expect(emojis[2].index).assertEqual(1002)
      expect(MessageReactionManager.getEmoji(1002)?.icon).assertEqual('custom-after-set')
    })

    it('keeps global enablement separate from conversation support', 0, () => {
      expect(ChatKitConfig.enableEmojiReaction).assertTrue()
      expect(isMessageReactionEnabled(true, true)).assertTrue()
      expect(isMessageReactionEnabled(true, false)).assertFalse()
      expect(isMessageReactionEnabled(false, true)).assertFalse()
      expect(isMessageReactionEnabled(false, false)).assertFalse()
    })

    it('isolates provider failures', 0, () => {
      MessageReactionManager.setEmojiProvider(new ThrowingReactionProvider())

      expect(MessageReactionManager.getEmoji(1)).assertUndefined()
      expect(MessageReactionManager.getAllEmojis().length).assertEqual(0)
    })
  })
}
