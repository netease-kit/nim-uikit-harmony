/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium'
import { Constant, PageState } from '../../../main/ets/loader/Constant'

export default function constantTest() {
  describe('constantTest', () => {
    it('should_have_correct_page_size', 0, () => {
      expect(Constant.PAGE_SIZE).assertEqual(100)
    })

    it('should_have_correct_y_offset_coefficient', 0, () => {
      expect(Constant.Y_OFF_SET_COEFFICIENT).assertEqual(0.1)
    })

    it('should_have_correct_animation_duration', 0, () => {
      expect(Constant.ANIMATION_DURATION).assertEqual(2000)
    })

    it('should_have_correct_delay_time', 0, () => {
      expect(Constant.DELAY_TIME).assertEqual(1000)
    })

    it('should_have_correct_custom_layout_height', 0, () => {
      expect(Constant.CUSTOM_LAYOUT_HEIGHT).assertEqual(70)
    })

    it('should_have_correct_page_state_enum_values', 0, () => {
      expect(PageState.Loading).assertEqual(0)
      expect(PageState.Success).assertEqual(1)
      expect(PageState.Fail).assertEqual(2)
    })

    it('should_page_state_values_be_distinct', 0, () => {
      let states: number[] = [PageState.Loading, PageState.Success, PageState.Fail]
      let uniqueStates: Set<number> = new Set()
      states.forEach((value: number) => {
        uniqueStates.add(value)
      })
      expect(uniqueStates.size).assertEqual(3)
    })
  })
}
