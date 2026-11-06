/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  AdaptiveLayoutMode,
  AdaptiveLayoutProfile,
  AdaptiveRegionRole,
  AdaptiveRegionSpec,
  AdaptiveWindowSnapshot,
  AdaptiveWidthBreakpoint
} from '../../../main/ets/model/AdaptiveLayoutModel'
import {
  resolveAdaptiveLayout,
  resolveAdaptiveProfile,
  resolveWidthBreakpoint
} from '../../../main/ets/utils/AdaptiveLayoutPolicy'
import { AdaptiveWindowStateStore } from '../../../main/ets/utils/AdaptiveWindowManager'

export default function AdaptiveLayoutPolicyTest() {
  describe('AdaptiveLayoutPolicy', () => {
    it('resolves official width breakpoint boundaries', 0, () => {
      expect(resolveWidthBreakpoint(0)).assertEqual(AdaptiveWidthBreakpoint.XS)
      expect(resolveWidthBreakpoint(319)).assertEqual(AdaptiveWidthBreakpoint.XS)
      expect(resolveWidthBreakpoint(320)).assertEqual(AdaptiveWidthBreakpoint.SM)
      expect(resolveWidthBreakpoint(599)).assertEqual(AdaptiveWidthBreakpoint.SM)
      expect(resolveWidthBreakpoint(600)).assertEqual(AdaptiveWidthBreakpoint.MD)
      expect(resolveWidthBreakpoint(839)).assertEqual(AdaptiveWidthBreakpoint.MD)
      expect(resolveWidthBreakpoint(840)).assertEqual(AdaptiveWidthBreakpoint.LG)
      expect(resolveWidthBreakpoint(1439)).assertEqual(AdaptiveWidthBreakpoint.LG)
      expect(resolveWidthBreakpoint(1440)).assertEqual(AdaptiveWidthBreakpoint.XL)
    })

    it('uses compact layout for narrow or tall windows', 0, () => {
      expect(resolveAdaptiveLayout(599, 400).mode).assertEqual(AdaptiveLayoutMode.COMPACT)
      expect(resolveAdaptiveLayout(840, 1008).mode).assertEqual(AdaptiveLayoutMode.COMPACT)
      expect(resolveAdaptiveLayout(0, 0).mode).assertEqual(AdaptiveLayoutMode.COMPACT)
    })

    it('uses medium and expanded layout for wide landscape windows', 0, () => {
      expect(resolveAdaptiveLayout(600, 600).mode).assertEqual(AdaptiveLayoutMode.MEDIUM)
      expect(resolveAdaptiveLayout(839, 600).mode).assertEqual(AdaptiveLayoutMode.MEDIUM)
      expect(resolveAdaptiveLayout(840, 600).mode).assertEqual(AdaptiveLayoutMode.EXPANDED)
    })

    it('redistributes width after a region reaches its maximum', 0, () => {
      const decision = resolveAdaptiveLayout(1440, 900)
      let totalWidth = 0
      for (const region of decision.visibleRegions) {
        totalWidth += region.widthVp
      }
      expect(Math.abs(totalWidth - 1440) < 0.01).assertTrue()
      expect(decision.widthFor(AdaptiveRegionRole.MASTER)).assertEqual(432)
    })

    it('keeps the expanded master and detail regions at one to two before clamping', 0, () => {
      const decision = resolveAdaptiveLayout(1120, 900)
      const masterWidth = decision.widthFor(AdaptiveRegionRole.MASTER)
      const detailWidth = decision.widthFor(AdaptiveRegionRole.DETAIL)
      expect(Math.abs(detailWidth / masterWidth - 2) < 0.01).assertTrue()
    })

    it('preserves the active detail while degrading a four region profile', 0, () => {
      const profile = new AdaptiveLayoutProfile('four-region', AdaptiveLayoutMode.EXPANDED, 600, 1.2, [
        new AdaptiveRegionSpec('navigation', AdaptiveRegionRole.PRIMARY_NAVIGATION, 80, 80, 0, 2),
        new AdaptiveRegionSpec('master', AdaptiveRegionRole.MASTER, 260, 420, 1, 3),
        new AdaptiveRegionSpec('detail', AdaptiveRegionRole.DETAIL, 360, 900, 2, 4),
        new AdaptiveRegionSpec('auxiliary', AdaptiveRegionRole.AUXILIARY, 240, 360, 1, 1)
      ])

      const decision = resolveAdaptiveProfile(profile, 700, AdaptiveRegionRole.DETAIL)
      let totalWidth = 0
      let hasDetail = false
      for (const region of decision.visibleRegions) {
        totalWidth += region.widthVp
        if (region.role === AdaptiveRegionRole.DETAIL) {
          hasDetail = true
        }
      }
      expect(decision.hiddenRegionIds.includes('auxiliary')).assertTrue()
      expect(hasDetail).assertTrue()
      expect(totalWidth <= 700).assertTrue()
    })

    it('publishes a changed window snapshot only once', 0, () => {
      const store = new AdaptiveWindowStateStore()
      let published = 0
      store.subscribe((_snapshot: AdaptiveWindowSnapshot) => {
        published++
      })
      store.updateSize(840, 600)
      store.updateSize(840, 600)
      store.updateSize(839, 600)
      expect(published).assertEqual(3)
      expect(store.getSnapshot().widthVp).assertEqual(839)
      expect(store.getSubscriberCount()).assertEqual(1)
    })

    it('supports idempotent subscribe and release', 0, () => {
      const store = new AdaptiveWindowStateStore()
      const listener = (_snapshot: AdaptiveWindowSnapshot) => {
      }
      store.subscribe(listener)
      store.subscribe(listener)
      expect(store.getSubscriberCount()).assertEqual(1)
      store.unsubscribe(listener)
      store.unsubscribe(listener)
      expect(store.getSubscriberCount()).assertEqual(0)
    })
  })
}
