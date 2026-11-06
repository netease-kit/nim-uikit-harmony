/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { clampPopupX, resolveChatBaseHeight, resolveChatViewport } from '../main/ets/common/ChatViewportPolicy'

export default function chatViewportPolicyTest() {
  describe('ChatViewportPolicy', () => {
    it('uses the detail container instead of the full window', 0, () => {
      const viewport = resolveChatViewport(560, 800, 300)
      expect(viewport.widthVp).assertEqual(560)
      expect(viewport.heightVp).assertEqual(800)
      expect(viewport.keyboardVp).assertEqual(300)
      expect(viewport.availableHeightVp).assertEqual(500)
    })

    it('keeps the full window height when the keyboard has already compressed the measured area', 0, () => {
      const baseHeight = resolveChatBaseHeight(800, 500)
      const viewport = resolveChatViewport(560, baseHeight, 300)
      expect(baseHeight).assertEqual(800)
      expect(viewport.availableHeightVp).assertEqual(500)
    })

    it('falls back to the measured area when no window height is available', 0, () => {
      expect(resolveChatBaseHeight(0, 620)).assertEqual(620)
      expect(resolveChatBaseHeight(-1, -1)).assertEqual(0)
    })

    it('clamps popup coordinates inside the detail container', 0, () => {
      expect(clampPopupX(-20, 160, 560, 12)).assertEqual(12)
      expect(clampPopupX(500, 160, 560, 12)).assertEqual(388)
      expect(clampPopupX(120, 160, 560, 12)).assertEqual(120)
    })

    it('degrades invalid dimensions without producing negative values', 0, () => {
      const viewport = resolveChatViewport(-1, 120, 300)
      expect(viewport.widthVp).assertEqual(0)
      expect(viewport.availableHeightVp).assertEqual(0)
      expect(clampPopupX(20, 200, 100, 12)).assertEqual(12)
    })
  })
}
