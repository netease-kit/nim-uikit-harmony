/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  ConversationOpenIntent,
  ConversationOpenRegistry,
  ConversationOpenSource,
  ConversationRouteKey,
  ConversationRouteKind
} from '../main/ets/model/ConversationOpenIntent'
import {
  ConversationContextAction,
  resolveConversationContextActions,
  resolveConversationItemBackground
} from '../main/ets/view/ConversationViewItem'
import { resolveAIUserItemBackground } from '../main/ets/view/ConversationAIUserViewItem'

export default function ConversationOpenIntentTest() {
  describe('ConversationOpenIntent', () => {
    it('builds stable route keys', 0, () => {
      expect(new ConversationRouteKey(ConversationRouteKind.P2P, 'c1').toStableKey()).assertEqual('p2p|c1|')
      expect(new ConversationRouteKey(ConversationRouteKind.TEAM, 'c2').toStableKey()).assertEqual('team|c2|')
      expect(new ConversationRouteKey(ConversationRouteKind.BOT_SUB_SESSION, 'c3', 'topic-1').toStableKey())
        .assertEqual('botSubSession|c3|topic-1')
    })

    it('keeps escaped and literal route identifiers distinct', 0, () => {
      const literalSeparator = new ConversationRouteKey(ConversationRouteKind.P2P, 'a|b').toStableKey()
      const escapedText = new ConversationRouteKey(ConversationRouteKind.P2P, 'a%7Cb').toStableKey()
      expect(literalSeparator === escapedText).assertFalse()
    })

    it('rejects an empty conversation identifier', 0, () => {
      const intent = new ConversationOpenIntent(
        new ConversationRouteKey(ConversationRouteKind.P2P, ''),
        ConversationOpenSource.CONVERSATION_LIST
      )
      expect(intent.isValid()).assertFalse()
    })

    it('dispatches to an installed host handler and preserves fallback when absent', 0, () => {
      const registry = new ConversationOpenRegistry()
      const intent = new ConversationOpenIntent(
        new ConversationRouteKey(ConversationRouteKind.P2P, 'c1'),
        ConversationOpenSource.CONTACT
      )
      let handledKey = ''
      const handler = (value: ConversationOpenIntent): void => {
        handledKey = value.key.toStableKey()
      }
      expect(registry.open(intent)).assertFalse()
      registry.setHandler(handler)
      expect(registry.open(intent)).assertTrue()
      expect(handledKey).assertEqual('p2p|c1|')
      registry.clearHandler(handler)
      expect(registry.open(intent)).assertFalse()
    })

    it('uses the brand selection tint before the pinned conversation background', 0, () => {
      expect(resolveConversationItemBackground(true, false)).assertEqual('#E6F0FF')
      expect(resolveConversationItemBackground(true, true)).assertEqual('#E6F0FF')
      expect(resolveConversationItemBackground(false, true)).assertEqual('#ffF3F5F7')
      expect(resolveConversationItemBackground(false, false)).assertEqual('#ffffffff')
    })

    it('keeps pinned AI user entries on their base background', 0, () => {
      expect(resolveAIUserItemBackground()).assertEqual('#ffFFFFFF')
    })

    it('uses the current pinned state to build conversation context actions', 0, () => {
      const normalActions = resolveConversationContextActions(false, false)
      expect(normalActions.length).assertEqual(3)
      expect(normalActions[0]).assertEqual(ConversationContextAction.STICK_TOP)
      expect(normalActions[1]).assertEqual(ConversationContextAction.MUTE)
      expect(normalActions[2]).assertEqual(ConversationContextAction.DELETE)

      const pinnedActions = resolveConversationContextActions(true, true)
      expect(pinnedActions.length).assertEqual(3)
      expect(pinnedActions[0]).assertEqual(ConversationContextAction.UNSTICK_TOP)
      expect(pinnedActions[1]).assertEqual(ConversationContextAction.UNMUTE)
      expect(pinnedActions[2]).assertEqual(ConversationContextAction.DELETE)
    })

    it('highlights the conversation item on hover like the selected item', 0, () => {
      expect(resolveConversationItemBackground(false, false, true)).assertEqual('#E6F0FF')
      expect(resolveConversationItemBackground(false, true, true)).assertEqual('#E6F0FF')
      expect(resolveConversationItemBackground(false, true, false)).assertEqual('#ffF3F5F7')
      expect(resolveConversationItemBackground(false, false, false)).assertEqual('#ffffffff')
    })
  })
}
