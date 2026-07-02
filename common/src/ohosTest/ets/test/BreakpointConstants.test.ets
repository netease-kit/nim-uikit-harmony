/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { BreakpointConstants } from '../../../main/ets/constants/BreakpointConstants';

export default function BreakpointConstantsTest() {
  describe('BreakpointConstants_names', () => {
    it('should_have_non_empty_names', 0, () => {
      expect(BreakpointConstants.BREAKPOINT_XS.length > 0).assertTrue();
      expect(BreakpointConstants.BREAKPOINT_SM.length > 0).assertTrue();
      expect(BreakpointConstants.BREAKPOINT_MD.length > 0).assertTrue();
      expect(BreakpointConstants.BREAKPOINT_LG.length > 0).assertTrue();
    });
  });

  describe('BreakpointConstants_scope', () => {
    it('should_have_monotonically_increasing_scope', 0, () => {
      let scope = BreakpointConstants.BREAKPOINT_SCOPE;
      expect(scope.length >= 4).assertTrue();
      for (let i = 1; i < scope.length; i++) {
        expect(scope[i] > scope[i - 1]).assertTrue();
      }
    });
  });

  describe('BreakpointConstants_grid', () => {
    it('should_have_non_empty_grid_arrays', 0, () => {
      expect(BreakpointConstants.GRID_ROW_COLUMNS.length > 0).assertTrue();
      expect(BreakpointConstants.GRID_COLUMN_SPANS.length > 0).assertTrue();
    });
  });
}
