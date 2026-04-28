/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { afterAll, beforeAll, describe, expect, it } from '@ohos/hypium';
import { NEEmojiManager, NIMInputEmoticon } from '../main/ets/manager/NEEmojiManager';
import {
  collectRichInputTransferNodes,
  getRichInputTransferText,
  RichInputTransferNode,
  RichInputTransferNodeType,
  splitSingleLineTransferNodes
} from '../main/ets/common/InputTransferUtils';

export default function inputTransferUtilsTest() {
  describe('inputTransferUtilsTest', () => {
    const originalGetEmojiByName = NEEmojiManager.instance.getEmojiByName.bind(NEEmojiManager.instance)

    beforeAll(() => {
      NEEmojiManager.instance.getEmojiByName = (fileName: string): NIMInputEmoticon | undefined => {
        if (fileName === 'test.png') {
          return {
            type: 1,
            file: 'test.png',
            tag: '[测试表情]'
          } as NIMInputEmoticon
        }
        return originalGetEmojiByName(fileName)
      }
    })

    afterAll(() => {
      NEEmojiManager.instance.getEmojiByName = originalGetEmojiByName
    })

    it('should_collect_text_emoji_and_ait_nodes_from_editor_spans', 0, () => {
      const spans = [
        { value: 'hello ', spanPosition: { spanRange: [0, 6] } } as RichEditorTextSpanResult,
        { valueResourceStr: 'rawfile://emoji/test.png', spanPosition: { spanRange: [6, 7] } } as RichEditorImageSpanResult,
        { spanPosition: { spanRange: [7, 12] } } as RichEditorImageSpanResult
      ]
      const nodes = collectRichInputTransferNodes(spans, [{
        spanIndex: 7,
        accountId: 'user_1',
        value: '@Tom '
      }])

      expect(nodes.length).assertEqual(3)
      expect(nodes[0].type).assertEqual(RichInputTransferNodeType.Text)
      expect(nodes[0].text).assertEqual('hello ')
      expect(nodes[1].type).assertEqual(RichInputTransferNodeType.Emoji)
      expect(nodes[1].text).assertEqual('[测试表情]')
      expect(nodes[1].emojiFile).assertEqual('test.png')
      expect(nodes[2].type).assertEqual(RichInputTransferNodeType.Ait)
      expect(nodes[2].text).assertEqual('@Tom ')
      expect(nodes[2].accountId).assertEqual('user_1')
    })

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
  })
}
