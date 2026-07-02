/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  collectRichInputTransferNodes,
  getRichInputTransferText,
  RichInputTransferNode,
  RichInputTransferNodeType,
  restoreMultiLineContent,
  splitSingleLineTransferNodes
} from '../../../main/ets/common/InputTransferUtils';

export default function inputTransferUtilsTest() {
  describe('inputTransferUtilsTest', () => {
    it('should_insert_ait_nodes_by_span_index_when_builder_span_is_missing_from_editor_spans', 0, () => {
      const spans = [
        { value: '他刚才', spanPosition: { spanRange: [0, 3] } } as RichEditorTextSpanResult,
        { value: 'knjn', spanPosition: { spanRange: [16, 20] } } as RichEditorTextSpanResult
      ]
      const nodes = collectRichInputTransferNodes(spans, [{
        spanIndex: 3,
        accountId: 'user_922554',
        value: '@user922554 '
      }])

      expect(nodes.length).assertEqual(3)
      expect(nodes[0].text).assertEqual('他刚才')
      expect(nodes[1].type).assertEqual(RichInputTransferNodeType.Ait)
      expect(nodes[1].text).assertEqual('@user922554 ')
      expect(nodes[2].text).assertEqual('knjn')
      expect(getRichInputTransferText(nodes)).assertEqual('他刚才@user922554 knjn')
    })

    it('should_keep_all_rich_nodes_in_body_when_singleline_has_no_newline', 0, () => {
      const nodes: RichInputTransferNode[] = [
        { type: RichInputTransferNodeType.Text, text: 'hello ' },
        { type: RichInputTransferNodeType.Emoji, text: '[测试表情]', emojiFile: 'test.png' },
        { type: RichInputTransferNodeType.Ait, text: '@Tom ', accountId: 'user_1' }
      ]

      const payload = splitSingleLineTransferNodes(nodes)

      expect(payload.title).assertEqual('')
      expect(payload.bodyText).assertEqual('hello [测试表情]@Tom ')
      expect(payload.bodyNodes.length).assertEqual(3)
      expect(getRichInputTransferText(payload.bodyNodes)).assertEqual('hello [测试表情]@Tom ')
    })

    it('should_move_content_after_first_newline_into_multiline_body', 0, () => {
      const nodes: RichInputTransferNode[] = [
        { type: RichInputTransferNodeType.Text, text: '标题\n正文' },
        { type: RichInputTransferNodeType.Emoji, text: '[测试表情]', emojiFile: 'test.png' },
        { type: RichInputTransferNodeType.Ait, text: '@Tom ', accountId: 'user_1' }
      ]

      const payload = splitSingleLineTransferNodes(nodes)

      expect(payload.title).assertEqual('标题')
      expect(payload.bodyText).assertEqual('正文[测试表情]@Tom ')
      expect(payload.bodyNodes.length).assertEqual(3)
      expect(payload.bodyNodes[0].text).assertEqual('正文')
      expect(payload.bodyNodes[1].type).assertEqual(RichInputTransferNodeType.Emoji)
      expect(payload.bodyNodes[2].type).assertEqual(RichInputTransferNodeType.Ait)
    })

    it('should_restore_multiline_body_nodes_for_revoke_reedit_team_ait_message', 0, () => {
      const bodyNodes: RichInputTransferNode[] = [
        { type: RichInputTransferNodeType.Text, text: '正文 ' },
        { type: RichInputTransferNodeType.Ait, text: '@Tom ', accountId: 'user_1' },
        { type: RichInputTransferNodeType.Text, text: '尾巴' }
      ]

      const restored = restoreMultiLineContent('标题', '正文 @Tom 尾巴', bodyNodes)

      expect(restored.title).assertEqual('标题')
      expect(restored.body).assertEqual('正文 @Tom 尾巴')
      expect(restored.bodyNodes.length).assertEqual(3)
      expect(restored.bodyNodes[1].type).assertEqual(RichInputTransferNodeType.Ait)
      expect(restored.bodyNodes[1].accountId).assertEqual('user_1')
      expect(getRichInputTransferText(restored.bodyNodes)).assertEqual('正文 @Tom 尾巴')
    })

    // collectRichInputTransferNodes - image span with resourcePath
    // When emoji is not found in cache (which is empty in tests),
    // the function should skip gracefully without crashing.
    it('should_skip_image_span_when_emoji_not_found_in_cache', 0, () => {
      const spans = [
        { value: 'Hello', spanPosition: { spanRange: [0, 5] } } as RichEditorTextSpanResult,
        { valueResourceStr: 'emoji/unknown_emoji.png', spanPosition: { spanRange: [5, 6] } } as RichEditorImageSpanResult,
        { value: 'World', spanPosition: { spanRange: [6, 11] } } as RichEditorTextSpanResult
      ]
      const nodes = collectRichInputTransferNodes(spans, [])

      expect(nodes.length).assertEqual(2)
      expect(nodes[0].text).assertEqual('Hello')
      expect(nodes[1].text).assertEqual('World')
      expect(getRichInputTransferText(nodes)).assertEqual('HelloWorld')
    })

    // collectRichInputTransferNodes - image span without resourcePath
    // Falls through to builder span matching by spanOffset.
    it('should_match_builder_span_when_image_span_has_no_resource_path', 0, () => {
      const spans = [
        { value: 'Hello', spanPosition: { spanRange: [0, 5] } } as RichEditorTextSpanResult,
        { spanPosition: { spanRange: [5, 6] } } as RichEditorImageSpanResult,
        { value: 'World', spanPosition: { spanRange: [6, 11] } } as RichEditorTextSpanResult
      ]
      const nodes = collectRichInputTransferNodes(spans, [
        { spanIndex: 5, accountId: 'user_1', value: '@user1 ' }
      ])

      expect(nodes.length).assertEqual(3)
      expect(nodes[0].text).assertEqual('Hello')
      expect(nodes[1].type).assertEqual(RichInputTransferNodeType.Ait)
      expect(nodes[1].text).assertEqual('@user1 ')
      expect(nodes[1].accountId).assertEqual('user_1')
      expect(nodes[2].text).assertEqual('World')
      expect(getRichInputTransferText(nodes)).assertEqual('Hello@user1 World')
    })

    it('should_not_consume_next_builder_span_when_span_range_does_not_match', 0, () => {
      const spans = [
        { value: 'Hello', spanPosition: { spanRange: [0, 5] } } as RichEditorTextSpanResult,
        { spanPosition: { spanRange: [8, 9] } } as RichEditorImageSpanResult,
        { value: 'World', spanPosition: { spanRange: [9, 14] } } as RichEditorTextSpanResult
      ]
      const nodes = collectRichInputTransferNodes(spans, [
        { spanIndex: 5, accountId: 'user_1', value: '@user1 ' }
      ])

      expect(nodes.length).assertEqual(3)
      expect(nodes[0].text).assertEqual('Hello')
      expect(nodes[1].type).assertEqual(RichInputTransferNodeType.Ait)
      expect(nodes[1].text).assertEqual('@user1 ')
      expect(nodes[2].text).assertEqual('World')
      expect(getRichInputTransferText(nodes)).assertEqual('Hello@user1 World')
    })

    // collectRichInputTransferNodes - remaining unmatched builder spans
    // Builder spans that don't match any editor span get appended and sorted by offset.
    it('should_append_unmatched_builder_spans_at_end_sorted_by_offset', 0, () => {
      const spans = [
        { value: 'Hello', spanPosition: { spanRange: [0, 5] } } as RichEditorTextSpanResult,
        { spanPosition: { spanRange: [5, 6] } } as RichEditorImageSpanResult,
        { value: 'World', spanPosition: { spanRange: [10, 15] } } as RichEditorTextSpanResult
      ]
      const nodes = collectRichInputTransferNodes(spans, [
        { spanIndex: 5, accountId: 'user_1', value: '@user1 ' },
        { spanIndex: 8, accountId: 'user_2', value: '@user2 ' }
      ])

      // First builder span (spanIndex=5) matches the image span at offset 5.
      // Second builder span (spanIndex=8) has no matching editor span, appended at end.
      // Sorted by offset: text(0), ait(5), ait(8), text(10)
      expect(nodes.length).assertEqual(4)
      expect(nodes[0].text).assertEqual('Hello')
      expect(nodes[1].type).assertEqual(RichInputTransferNodeType.Ait)
      expect(nodes[1].text).assertEqual('@user1 ')
      expect(nodes[1].accountId).assertEqual('user_1')
      expect(nodes[2].type).assertEqual(RichInputTransferNodeType.Ait)
      expect(nodes[2].text).assertEqual('@user2 ')
      expect(nodes[2].accountId).assertEqual('user_2')
      expect(nodes[3].text).assertEqual('World')
      expect(getRichInputTransferText(nodes)).assertEqual('Hello@user1 @user2 World')
    })

    // splitSingleLineTransferNodes - non-text node before newline
    // Emoji and Ait nodes before the first newline contribute their text to title.
    it('should_add_non_text_node_text_to_title_before_newline', 0, () => {
      const nodes: RichInputTransferNode[] = [
        { type: RichInputTransferNodeType.Emoji, text: '[笑脸]', emojiFile: 'smile.png' },
        { type: RichInputTransferNodeType.Ait, text: '@Tom ', accountId: 'user_1' },
        { type: RichInputTransferNodeType.Text, text: '标题\n正文内容' }
      ]

      const payload = splitSingleLineTransferNodes(nodes)

      expect(payload.title).assertEqual('[笑脸]@Tom 标题')
      expect(payload.bodyText).assertEqual('正文内容')
      expect(payload.bodyNodes.length).assertEqual(1)
      expect(payload.bodyNodes[0].type).assertEqual(RichInputTransferNodeType.Text)
      expect(payload.bodyNodes[0].text).assertEqual('正文内容')
    })

    // splitSingleLineTransferNodes - newline at end of text
    // When newline is at the end of a text node, body after newline is empty.
    it('should_not_add_body_text_node_when_newline_is_at_end_of_text', 0, () => {
      const nodes: RichInputTransferNode[] = [
        { type: RichInputTransferNodeType.Text, text: '标题\n' },
        { type: RichInputTransferNodeType.Emoji, text: '[笑脸]', emojiFile: 'smile.png' }
      ]

      const payload = splitSingleLineTransferNodes(nodes)

      expect(payload.title).assertEqual('标题')
      expect(payload.bodyText).assertEqual('[笑脸]')
      expect(payload.bodyNodes.length).assertEqual(1)
      expect(payload.bodyNodes[0].type).assertEqual(RichInputTransferNodeType.Emoji)
      expect(payload.bodyNodes[0].text).assertEqual('[笑脸]')
    })

    // restoreMultiLineContent - empty body and empty bodyNodes
    // When both body and bodyNodes are empty, returns empty bodyNodes array.
    it('should_return_empty_body_nodes_when_body_and_body_nodes_are_empty', 0, () => {
      const restored = restoreMultiLineContent('标题', '', [])

      expect(restored.title).assertEqual('标题')
      expect(restored.body).assertEqual('')
      expect(restored.bodyNodes.length).assertEqual(0)
    })

    // restoreMultiLineContent - bodyNodes undefined, body non-empty
    // When bodyNodes is undefined but body has text, creates a default text node.
    it('should_create_default_text_node_when_body_nodes_undefined_and_body_non_empty', 0, () => {
      const restored = restoreMultiLineContent('标题', '这是一段正文', undefined)

      expect(restored.title).assertEqual('标题')
      expect(restored.body).assertEqual('这是一段正文')
      expect(restored.bodyNodes.length).assertEqual(1)
      expect(restored.bodyNodes[0].type).assertEqual(RichInputTransferNodeType.Text)
      expect(restored.bodyNodes[0].text).assertEqual('这是一段正文')
    })
  })
}
