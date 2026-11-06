/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  ConversationOpenIntent,
  ConversationOpenSource,
  ConversationRouteKey,
  ConversationRouteKind
} from '../../../main/ets/model/ConversationOpenIntent'

export default function ConversationOpenIntentTest() {
  describe('ConversationOpenIntent', () => {
    it('builds stable keys for p2p team and bot sub sessions', 0, () => {
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
  })
}
