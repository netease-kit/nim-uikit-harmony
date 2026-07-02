/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { ConversationMode } from '../../../main/ets/strategy/ConversationStrategy';
import { mergedMessageNickKey, mergedMessageAvatarKey, multiForwardFileName } from '../../../main/ets/constant/Constant';

export default function ChatkitConstantTest() {
  describe('ConversationMode', () => {
    it('should_have_cloud_and_local_values', 0, () => {
      expect(ConversationMode.CLOUD).assertEqual('cloud');
      expect(ConversationMode.LOCAL).assertEqual('local');
    });
    it('should_have_distinct_values', 0, () => {
      const cloudVal: string = ConversationMode.CLOUD;
      const localVal: string = ConversationMode.LOCAL;
      expect(cloudVal !== localVal).assertTrue();
    });
  });

  describe('Constant_exports', () => {
    it('should_have_non_empty_mergedMessageNickKey', 0, () => {
      expect(mergedMessageNickKey.length > 0).assertTrue();
    });
    it('should_have_non_empty_mergedMessageAvatarKey', 0, () => {
      expect(mergedMessageAvatarKey.length > 0).assertTrue();
    });
    it('should_have_non_empty_multiForwardFileName', 0, () => {
      expect(multiForwardFileName.length > 0).assertTrue();
    });
  });
}
