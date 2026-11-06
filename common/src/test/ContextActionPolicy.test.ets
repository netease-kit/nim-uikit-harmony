/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  resolveContextAction,
  shouldOpenContextAction,
  shouldDismissSelectionOnTouch,
  shouldCloseMouseSelectionOnCollapse,
  MOUSE_MENU_SETTLE_MS
} from '../main/ets/utils/ContextActionPolicy'

export default function ContextActionPolicyTest() {
  describe('ContextActionPolicy', () => {
    it('opens a context action only for a released right mouse button', 0, () => {
      expect(shouldOpenContextAction(MouseButton.Right, MouseAction.Release)).assertTrue()
      expect(shouldOpenContextAction(MouseButton.Right, MouseAction.Press)).assertFalse()
      expect(shouldOpenContextAction(MouseButton.Left, MouseAction.Release)).assertFalse()
      expect(shouldOpenContextAction(MouseButton.Middle, MouseAction.Release)).assertFalse()
    })

    it('stops propagation for nested context action targets', 0, () => {
      const nestedDecision = resolveContextAction(MouseButton.Right, MouseAction.Release, true)
      expect(nestedDecision.open).assertTrue()
      expect(nestedDecision.stopPropagation).assertTrue()

      const itemDecision = resolveContextAction(MouseButton.Right, MouseAction.Release)
      expect(itemDecision.open).assertTrue()
      expect(itemDecision.stopPropagation).assertFalse()
    })

    it('does not stop propagation for ignored mouse events', 0, () => {
      const decision = resolveContextAction(MouseButton.Left, MouseAction.Release, true)
      expect(decision.open).assertFalse()
      expect(decision.stopPropagation).assertFalse()
    })

    it('keeps an active text selection during message list touch down', 0, () => {
      expect(shouldDismissSelectionOnTouch(false)).assertTrue()
      expect(shouldDismissSelectionOnTouch(true)).assertFalse()
    })

    it('closes a mouse selection when the pointer is outside the menu', 0, () => {
      expect(shouldCloseMouseSelectionOnCollapse(true, true, false, 1000)).assertTrue()
    })

    it('keeps a mouse selection while the pointer stays in the menu', 0, () => {
      expect(shouldCloseMouseSelectionOnCollapse(true, true, true, 1000)).assertFalse()
    })

    it('keeps a mouse selection while no menu is visible', 0, () => {
      expect(shouldCloseMouseSelectionOnCollapse(true, false, false, 1000)).assertFalse()
    })

    it('ignores a non collapsed mouse range', 0, () => {
      expect(shouldCloseMouseSelectionOnCollapse(false, true, false, 1000)).assertFalse()
    })

    it('keeps the menu while the system is still adjusting the selection', 0, () => {
      expect(shouldCloseMouseSelectionOnCollapse(true, true, false, MOUSE_MENU_SETTLE_MS - 1)).assertFalse()
      expect(shouldCloseMouseSelectionOnCollapse(true, true, false, MOUSE_MENU_SETTLE_MS + 1)).assertTrue()
    })
  })
}
