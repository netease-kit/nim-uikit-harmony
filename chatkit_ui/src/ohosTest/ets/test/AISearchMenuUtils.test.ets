/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  canShowAISearchForMessageType,
  getMultiLineAISearchText,
  getRenderedTextLength,
  getSelectedText,
  isSelectAllText,
  normalizeRenderedSelectionRange
} from '../../../main/ets/aisearchkit/AISearchMenuUtils'
import { V2NIMMessageType } from '@nimsdk/base'

export default function aiSearchMenuUtilsTest() {
  describe('AISearchMenuUtils', () => {
    it('should_identify_full_selection', 0, () => {
      expect(isSelectAllText(0, 4, 4)).assertTrue()
    })

    it('should_identify_reversed_full_selection', 0, () => {
      expect(isSelectAllText(4, 0, 4)).assertTrue()
    })

    it('should_identify_partial_selection', 0, () => {
      expect(isSelectAllText(1, 4, 5)).assertFalse()
    })

    it('should_return_selected_text_with_normalized_range', 0, () => {
      expect(getSelectedText('hello', 4, 1)).assertEqual('ell')
    })

    it('should_use_only_body_for_multiline_ai_search_text', 0, () => {
      expect(getMultiLineAISearchText('body')).assertEqual('body')
    })

    it('should_return_empty_for_missing_multiline_body', 0, () => {
      expect(getMultiLineAISearchText(undefined)).assertEqual('')
    })

    it('should_allow_text_message_for_ai_search_menu', 0, () => {
      expect(canShowAISearchForMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT, false)).assertTrue()
    })

    it('should_allow_multiline_message_for_ai_search_menu', 0, () => {
      expect(canShowAISearchForMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM, true)).assertTrue()
    })

    it('should_not_allow_image_message_for_ai_search_menu', 0, () => {
      expect(canShowAISearchForMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE, false)).assertFalse()
    })

    it('should_map_full_selection_with_custom_emoji_span_to_full_source_text', 0, () => {
      const text = '你好[大笑]世界'
      const units = [{ sourceStart: 2, sourceLength: 4, renderLength: 1 }]
      expect(getRenderedTextLength(text, units)).assertEqual(5)
      const range = normalizeRenderedSelectionRange(text, units, 0, 5)
      expect(range[0]).assertEqual(0)
      expect(range[1]).assertEqual(text.length)
    })

    it('should_map_partial_selection_after_custom_emoji_span_to_source_text', 0, () => {
      const text = '你好[大笑]世界'
      const units = [{ sourceStart: 2, sourceLength: 4, renderLength: 1 }]
      const range = normalizeRenderedSelectionRange(text, units, 3, 5)
      expect(getSelectedText(text, range[0], range[1])).assertEqual('世界')
    })

    it('should_map_partial_selection_before_custom_emoji_span_to_source_text', 0, () => {
      const text = '你好[大笑]世界'
      const units = [{ sourceStart: 2, sourceLength: 4, renderLength: 1 }]
      const range = normalizeRenderedSelectionRange(text, units, 0, 2)
      expect(getSelectedText(text, range[0], range[1])).assertEqual('你好')
    })

    it('should_map_selection_covering_custom_emoji_placeholder_to_source_emoji_tag', 0, () => {
      const text = '你好[大笑]世界'
      const units = [{ sourceStart: 2, sourceLength: 4, renderLength: 1 }]
      const range = normalizeRenderedSelectionRange(text, units, 2, 3)
      expect(getSelectedText(text, range[0], range[1])).assertEqual('[大笑]')
    })

    // buildSelectionLines / findSelectionIndexByPoint / getSelectionRects 已从源码移除
    // 相关测试用例已删除
  })
}
