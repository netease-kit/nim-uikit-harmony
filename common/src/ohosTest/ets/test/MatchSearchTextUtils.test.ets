/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { resolveMatchSearchTextSegments } from '../../../main/ets/utils/MatchSearchTextUtils'

export default function matchSearchTextUtilsTest() {
  describe('MatchSearchTextUtils', () => {
    it('should_keep_existing_window_for_short_keyword', 0, () => {
      const result = resolveMatchSearchTextSegments('0123456789keywordABCDEFGHIJ', 'keyword', 16)

      expect(result.found).assertTrue()
      expect(result.startText).assertEqual('...789')
      expect(result.matchedText).assertEqual('keyword')
      expect(result.endText).assertEqual('ABCD...')
    })

    it('should_truncate_long_keyword_to_highlight_window', 0, () => {
      const result = resolveMatchSearchTextSegments(
        '前缀ABCDEFGHIJKLMNOPQRST后缀',
        'ABCDEFGHIJKLMNOPQRST',
        16
      )

      expect(result.found).assertTrue()
      expect(result.startText).assertEqual('...')
      expect(result.matchedText).assertEqual('ABCDEFGHIJKLMNOP')
      expect(result.matchedText.length).assertEqual(16)
      expect(result.endText).assertEqual('...')
    })

    it('should_preserve_original_case_for_long_keyword', 0, () => {
      const result = resolveMatchSearchTextSegments(
        'AbCdEfGhIjKlMnOpQrSt',
        'abcdefghijklmnopqrst',
        16
      )

      expect(result.matchedText).assertEqual('AbCdEfGhIjKlMnOp')
      expect(result.endText).assertEqual('...')
    })

    it('should_return_empty_segments_when_keyword_is_not_found', 0, () => {
      const result = resolveMatchSearchTextSegments('Alpha', 'Beta', 16)

      expect(result.found).assertFalse()
      expect(result.startText + result.matchedText + result.endText).assertEqual('')
    })
  })
}
