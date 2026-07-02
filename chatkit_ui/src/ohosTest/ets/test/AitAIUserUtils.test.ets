/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { AitManager } from '../../../main/ets/manager/ait/AitManager';
import {
  buildAitDisplayText,
  extractAitAccountIds,
  getAitNodes,
  isAIUnsupportedFormatTipText
} from '../../../main/ets/common/MessageHelper';
import {
  restoreAitTransferNodesFromMessageText,
  RichInputTransferNodeType
} from '../../../main/ets/common/InputTransferUtils';

export default function aitAIUserUtilsTest() {
  describe('aitAIUserUtilsTest', () => {
    it('should_return_first_ai_chat_user_from_ait_model', 0, () => {
      const manager = new AitManager()
      manager.addAitWithText('user_1', '@Tom ', 0)
      manager.addAitWithText('ai_1', '@AI One ', 5)
      manager.addAitWithText('ai_2', '@AI Two ', 13)

      const firstAI = manager.getFirstAIChatAccount(['ai_1', 'ai_2'])

      expect(firstAI).assertEqual('ai_1')
    })

    it('should_return_first_ai_user_from_all_ait_ai_accounts', 0, () => {
      const manager = new AitManager()
      manager.addAitWithText('ai_member', '@普通数字人 ', 0)
      manager.addAitWithText('ai_chat', '@个人助理 ', 7)

      const firstAI = manager.getFirstAccount(['ai_chat', 'ai_member'])

      expect(firstAI).assertEqual('ai_member')
    })

    it('should_extract_ait_account_ids_from_remote_extension', 0, () => {
      const extension =
        '{"yxAitMsg":{"user_1":{"text":"@Tom ","accountId":"user_1","segments":[{"start":0,"end":4,"broken":false}]},"ai_1":{"text":"@AI ","accountId":"ai_1","segments":[{"start":5,"end":8,"broken":false}]}}}'

      const accountIds = extractAitAccountIds(extension)

      expect(accountIds.length).assertEqual(2)
      expect(accountIds[0]).assertEqual('user_1')
      expect(accountIds[1]).assertEqual('ai_1')
    })

    it('should_ignore_ait_all_and_invalid_extension_when_extracting_ait_account_ids', 0, () => {
      const extension =
        '{"yxAitMsg":{"ait_all":{"text":"@所有人 ","accountId":"ait_all","segments":[{"start":0,"end":4,"broken":false}]},"user_1":{"text":"@Tom ","accountId":"user_1","segments":[{"start":5,"end":9,"broken":false}]}}}'

      const accountIds = extractAitAccountIds(extension)
      const invalidAccountIds = extractAitAccountIds('{invalid json}')

      expect(accountIds.length).assertEqual(1)
      expect(accountIds[0]).assertEqual('user_1')
      expect(invalidAccountIds.length).assertEqual(0)
    })

    it('should_keep_ai_ait_node_when_text_matches_segment', 0, () => {
      const extension =
        '{"yxAitMsg":{"personal_assistant":{"text":"@个人助理 ","accountId":"personal_assistant","segments":[{"start":0,"end":5,"broken":false}]}}}'

      const nodes = getAitNodes(0, '@个人助理 hi', extension)

      expect(nodes.length).assertEqual(2)
      expect(nodes[0].account).assertEqual('personal_assistant')
      expect(nodes[0].text).assertEqual('@个人助理 ')
      expect(nodes[1].text).assertEqual('hi')
    })

    it('should_keep_ai_ait_node_from_remote_extension_when_segment_end_is_longer', 0, () => {
      const extension =
        '{"yxAitMsg":{"personal_assistant":{"text":"@个人助理 ","accountId":"personal_assistant","segments":[{"start":0,"end":6,"broken":false}]}}}'

      const nodes = getAitNodes(0, '@个人助理 hi', extension)

      expect(nodes.length).assertEqual(2)
      expect(nodes[0].account).assertEqual('personal_assistant')
      expect(nodes[0].text).assertEqual('@个人助理 ')
      expect(nodes[1].text).assertEqual('hi')
    })

    it('should_not_create_ait_node_when_text_does_not_contain_segment', 0, () => {
      const extension =
        '{"yxAitMsg":{"personal_assistant":{"text":"@个人助理 ","accountId":"personal_assistant","segments":[{"start":0,"end":5,"broken":false}]}}}'

      const nodes = getAitNodes(0, 'hi', extension)

      expect(nodes.length).assertEqual(1)
      expect(nodes[0].text).assertEqual('hi')
    })

    it('should_not_parse_ait_node_when_ai_response_extension_is_ignored', 0, () => {
      const nodes = getAitNodes(0, '你好！很高兴能为你提供帮助', undefined)

      expect(nodes.length).assertEqual(1)
      expect(nodes[0].text).assertEqual('你好！很高兴能为你提供帮助')
    })

    it('should_not_create_ai_and_member_ait_nodes_when_text_does_not_contain_segment', 0, () => {
      const extension =
        '{"yxAitMsg":{"personal_assistant":{"text":"@个人助理 ","accountId":"personal_assistant","segments":[{"start":0,"end":5,"broken":false}]},"user_1":{"text":"@成员1 ","accountId":"user_1","segments":[{"start":6,"end":10,"broken":false}]}}}'

      const nodes = getAitNodes(0, 'hi', extension)

      expect(nodes.length).assertEqual(1)
      expect(nodes[0].text).assertEqual('hi')
    })

    it('should_build_display_text_for_trimmed_ai_ait_request', 0, () => {
      const extension =
        '{"yxAitMsg":{"personal_assistant":{"text":"@个人助理 ","accountId":"personal_assistant","segments":[{"start":0,"end":5,"broken":false}]}}}'

      const displayText = buildAitDisplayText('hi', extension)

      expect(displayText).assertEqual('@个人助理 hi')
    })

    it('should_not_duplicate_display_text_when_text_already_contains_ait_prefix', 0, () => {
      const extension =
        '{"yxAitMsg":{"user_1":{"text":"@成员1 ","accountId":"user_1","segments":[{"start":0,"end":4,"broken":false}]}}}'

      const displayText = buildAitDisplayText('@成员1 hi', extension)

      expect(displayText).assertEqual('@成员1 hi')
    })

    it('should_not_duplicate_display_text_when_extension_has_duplicate_ait_segments', 0, () => {
      const extension =
        '{"yxAitMsg":{"personal_assistant":{"text":"@个人助理 ","accountId":"personal_assistant","segments":[{"start":0,"end":5,"broken":false},{"start":0,"end":5,"broken":false}]}}}'

      const displayText = buildAitDisplayText('@个人助理 你是谁', extension)

      expect(displayText).assertEqual('@个人助理 你是谁')
    })

    it('should_not_duplicate_display_text_when_text_is_trimmed_ait_only', 0, () => {
      const extension =
        '{"yxAitMsg":{"personal_assistant":{"text":"@个人助理 ","accountId":"personal_assistant","segments":[{"start":0,"end":5,"broken":false}]}}}'

      const displayText = buildAitDisplayText('@个人助理', extension)

      expect(displayText).assertEqual('@个人助理')
    })

    it('should_identify_ai_unsupported_format_tip_text', 0, () => {
      expect(isAIUnsupportedFormatTipText('AI messages must be of text')).assertTrue()
      expect(isAIUnsupportedFormatTipText('请求大语言模型失败')).assertFalse()
    })

    it('should_restore_ait_transfer_nodes_from_revoke_text_and_extension', 0, () => {
      const extension =
        '{"yxAitMsg":{"personal_assistant":{"text":"@个人助理 ","accountId":"personal_assistant","segments":[{"start":0,"end":5,"broken":false}]}}}'

      const nodes = restoreAitTransferNodesFromMessageText('@个人助理 hi[惊讶]', extension)

      expect(nodes.length).assertEqual(3)
      expect(nodes[0].type).assertEqual(RichInputTransferNodeType.Ait)
      expect(nodes[0].accountId).assertEqual('personal_assistant')
      expect(nodes[0].text).assertEqual('@个人助理 ')
      expect(nodes[1].type).assertEqual(RichInputTransferNodeType.Text)
      expect(nodes[1].text).assertEqual('hi')
      expect(nodes[2].type).assertEqual(RichInputTransferNodeType.Emoji)
    })

  })
}
