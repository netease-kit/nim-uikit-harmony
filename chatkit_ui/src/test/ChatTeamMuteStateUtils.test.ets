/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { createCollapsedChatInputLayout } from '../main/ets/utils/ChatTeamMuteStateUtils'

export default function chatTeamMuteStateUtilsTest() {
  describe('ChatTeamMuteStateUtils', () => {
    it('collapses the bottom panel and clears pending expansion when muted', 0, () => {
      const state = createCollapsedChatInputLayout(105)

      expect(state.expandHeight).assertEqual(0)
      expect(state.bottomHeight).assertEqual(105)
      expect(state.pendingExpandPanelAfterKeyboardHide).assertFalse()
      expect(state.hideInput).assertFalse()
      expect(state.shouldStopRecord).assertTrue()
    })

    it('preserves the provided collapsed input height', 0, () => {
      const state = createCollapsedChatInputLayout(137)

      expect(state.bottomHeight).assertEqual(137)
    })
  })
}
