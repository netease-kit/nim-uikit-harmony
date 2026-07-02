/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { DateConst } from '../../../main/ets/constants/DateConst';

export default function DateConstTest() {
  describe('DateConst_formats', () => {
    it('should_have_non_empty_format_strings', 0, () => {
      expect(DateConst.YMD.length > 0).assertTrue();
      expect(DateConst.HMS.length > 0).assertTrue();
      expect(DateConst.HM.length > 0).assertTrue();
      expect(DateConst.YMD_HLINE.length > 0).assertTrue();
      expect(DateConst.YMD_HLINE_HMS.length > 0).assertTrue();
      expect(DateConst.YMD_HLINE_HM.length > 0).assertTrue();
      expect(DateConst.YMD_BLINE.length > 0).assertTrue();
      expect(DateConst.YMD_BLINE_HMS.length > 0).assertTrue();
      expect(DateConst.YMD_BLINE_HM.length > 0).assertTrue();
    });
    it('should_have_distinct_format_strings', 0, () => {
      let formats = [
        DateConst.YMD, DateConst.HMS, DateConst.HM,
        DateConst.YMD_HLINE, DateConst.YMD_HLINE_HMS, DateConst.YMD_HLINE_HM,
        DateConst.YMD_BLINE, DateConst.YMD_BLINE_HMS, DateConst.YMD_BLINE_HM
      ];
      let seen = new Set<string>();
      for (let f of formats) {
        expect(seen.has(f)).assertFalse();
        seen.add(f);
      }
    });
  });
}
