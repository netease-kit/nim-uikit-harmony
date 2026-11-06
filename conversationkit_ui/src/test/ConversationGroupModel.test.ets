/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { V2NIMConversationType } from '@nimsdk/base'
import {
  CONVERSATION_GROUP_DEFAULT_AIT_KEY,
  CONVERSATION_GROUP_DEFAULT_UNREAD_KEY
} from '@nimkit/chatkit'
import { filterConversationsByDefaultGroup } from '../main/ets/model/ConversationGroupModel'
import { ConversationItem } from '../main/ets/strategy/ConversationStrategy'

function createConversation(conversationId: string, unreadCount: number, mute: boolean = false): ConversationItem {
  return {
    conversationId: conversationId,
    type: V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P,
    stickTop: false,
    serverExtension: '',
    unreadCount: unreadCount,
    mute: mute,
    sortOrder: 1,
    createTime: 1,
    updateTime: 1
  } as ConversationItem
}

export default function ConversationGroupModelTest() {
  describe('ConversationGroupModel', () => {
    it('keeps the opened conversation in the unread group after its unread count is cleared', 0, () => {
      const conversations: ConversationItem[] = [
        createConversation('c1', 0),
        createConversation('c2', 2)
      ]
      const filtered = filterConversationsByDefaultGroup(conversations,
        CONVERSATION_GROUP_DEFAULT_UNREAD_KEY, new Set(), 'c1')
      expect(filtered.length).assertEqual(2)
      expect(filtered[0].conversationId).assertEqual('c1')
    })

    it('keeps the opened conversation in the ait group after its ait badge is cleared', 0, () => {
      const conversations: ConversationItem[] = [
        createConversation('c1', 0),
        createConversation('c2', 1)
      ]
      const filtered = filterConversationsByDefaultGroup(conversations,
        CONVERSATION_GROUP_DEFAULT_AIT_KEY, new Set(), 'c1')
      expect(filtered.length).assertEqual(1)
      expect(filtered[0].conversationId).assertEqual('c1')
    })

    it('drops the opened conversation once it is no longer pinned', 0, () => {
      const conversations: ConversationItem[] = [createConversation('c1', 0)]
      const filtered = filterConversationsByDefaultGroup(conversations,
        CONVERSATION_GROUP_DEFAULT_UNREAD_KEY, new Set())
      expect(filtered.length).assertEqual(0)
    })

    it('does not pin conversations that are not opened', 0, () => {
      const conversations: ConversationItem[] = [
        createConversation('c1', 0),
        createConversation('c2', 0)
      ]
      const filtered = filterConversationsByDefaultGroup(conversations,
        CONVERSATION_GROUP_DEFAULT_UNREAD_KEY, new Set(), 'c9')
      expect(filtered.length).assertEqual(0)
    })
  })
}
