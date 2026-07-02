/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { buildMessageJumpPlan } from '../../../main/ets/utils/ChatJumpUtils';

export default function chatJumpUtilsTest() {
  describe('ChatJumpUtils_buildMessageJumpPlan', () => {
    it('should_scroll_when_target_message_is_already_loaded', 0, () => {
      const result = buildMessageJumpPlan('msg_2', ['msg_1', 'msg_2', 'msg_3'])

      expect(result.scrollIndex).assertEqual(1)
      expect(result.shouldLoadAnchor).assertFalse()
    })

    it('should_fallback_to_anchor_when_target_message_is_not_loaded', 0, () => {
      const result = buildMessageJumpPlan('msg_4', ['msg_1', 'msg_2', 'msg_3'])

      expect(result.scrollIndex).assertEqual(-1)
      expect(result.shouldLoadAnchor).assertTrue()
    })

    it('should_ignore_empty_target_message', 0, () => {
      const result = buildMessageJumpPlan('', ['msg_1'])

      expect(result.scrollIndex).assertEqual(-1)
      expect(result.shouldLoadAnchor).assertFalse()
    })
  })
}
