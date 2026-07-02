/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { ConversationMode, CloudConversationStrategy } from '../../../main/ets/strategy/ConversationStrategy';

export default function ConversationStrategyTest() {
  describe('ConversationMode_values', () => {
    it('should_have_cloud_value', 0, () => {
      const v: string = ConversationMode.CLOUD;
      expect(v).assertEqual('cloud');
    });
    it('should_have_local_value', 0, () => {
      const v: string = ConversationMode.LOCAL;
      expect(v).assertEqual('local');
    });
    it('should_have_distinct_values', 0, () => {
      const c: string = ConversationMode.CLOUD;
      const l: string = ConversationMode.LOCAL;
      expect(c !== l).assertTrue();
    });
  });

  describe('CloudConversationStrategy', () => {
    it('should_have_cloud_mode', 0, () => {
      const strategy: CloudConversationStrategy = new CloudConversationStrategy();
      const mode: string = strategy.mode;
      expect(mode).assertEqual(ConversationMode.CLOUD);
    });
    it('should_reload_initial_conversation_after_sync_when_empty', 0, () => {
      const strategy: CloudConversationStrategy = new CloudConversationStrategy();
      expect(strategy.shouldReloadInitialConversationAfterSyncWhenEmpty()).assertTrue();
    });
  });
}
