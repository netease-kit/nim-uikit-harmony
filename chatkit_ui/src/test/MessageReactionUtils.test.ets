/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  NIMEStrAnyObj,
  V2NIMErrorCode,
  V2NIMMessage,
  V2NIMMessageQuickComment,
  V2NIMMessageQuickCommentType,
  V2NIMMessageSendingState,
  V2NIMMessageType
} from '@nimsdk/base'
import {
  applyQuickCommentNotification,
  buildAllReactionIndexes,
  buildQuickCommentBatches,
  buildReactionSummaries,
  buildReactionSummaryRenderKey,
  calculateReactionLayoutWidth,
  calculateReactionNaturalWidth,
  canShowMessageReaction,
  computeReactionMenuY,
  formatReactionCount,
  getSendMessageComboFlexShrink,
  isReactionMediaMessageType,
  isQuickCommentLimitErrorCode,
  quickCommentResultToMap,
  QUICK_REACTION_INDEXES,
  QUICK_REACTION_WITH_ARROW_INDEXES,
  ReactionSummary,
  reactionIndexToEmojiFile,
  shouldRightAlignSendMessageContent,
  shouldEnableReactionForSelection
} from '../main/ets/utils/MessageReactionUtils'

function makeComment(index: number, operatorId: string, createTime: number): V2NIMMessageQuickComment {
  return {
    index: index,
    operatorId: operatorId,
    createTime: createTime,
    serverExtension: '',
    messageRefer: {
      messageClientId: 'message-1',
      messageServerId: 'server-1',
      conversationId: 'conversation-1',
      conversationType: 1,
      senderId: 'sender-1',
      receiverId: 'receiver-1',
      createTime: 100
    }
  } as V2NIMMessageQuickComment
}

function makeMessage(type: V2NIMMessageType, state: V2NIMMessageSendingState): V2NIMMessage {
  return {
    messageType: type,
    sendingState: state
  } as V2NIMMessage
}

function makeServerFailedMessage(): V2NIMMessage {
  return {
    messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT,
    sendingState: V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED,
    messageStatus: {
      errorCode: 500
    }
  } as V2NIMMessage
}

export default function messageReactionUtilsTest() {
  describe('MessageReactionUtils', () => {
    it('should_map_one_based_index_to_reaction_emoji_file', 0, () => {
      expect(reactionIndexToEmojiFile(1)).assertEqual('reaction_emoji/001.png')
      expect(reactionIndexToEmojiFile(2)).assertEqual('reaction_emoji/002.png')
      expect(reactionIndexToEmojiFile(3)).assertEqual('reaction_emoji/003.png')
      expect(reactionIndexToEmojiFile(19)).assertEqual('reaction_emoji/019.png')
      expect(reactionIndexToEmojiFile(20)).assertEqual('reaction_emoji/020.png')
      expect(reactionIndexToEmojiFile(21)).assertEqual('reaction_emoji/021.png')
      expect(reactionIndexToEmojiFile(65)).assertEqual('reaction_emoji/065.png')
      expect(reactionIndexToEmojiFile(66)).assertEqual('reaction_emoji/066.png')
      expect(reactionIndexToEmojiFile(112)).assertEqual('reaction_emoji/112.png')
      expect(reactionIndexToEmojiFile(0)).assertUndefined()
      expect(reactionIndexToEmojiFile(113)).assertUndefined()
    })

    it('should_keep_product_add_picker_reaction_order', 0, () => {
      expect(QUICK_REACTION_INDEXES.join(',')).assertEqual('3,5,1,21,65,19,20')
    })

    it('should_keep_product_long_press_reaction_order', 0, () => {
      expect(QUICK_REACTION_WITH_ARROW_INDEXES.join(',')).assertEqual('3,5,1,21,65,19')
    })

    it('should_format_reaction_count_like_android', 0, () => {
      expect(formatReactionCount(999)).assertEqual('999')
      expect(formatReactionCount(1000)).assertEqual('1k')
      expect(formatReactionCount(999999)).assertEqual('999k')
      expect(formatReactionCount(1000000)).assertEqual('1m')
    })

    it('should_split_quick_comment_queries_into_android_sized_batches', 0, () => {
      const messages: V2NIMMessage[] = []
      for (let index = 0; index < 45; index++) {
        messages.push({ messageClientId: `message-${index}` } as V2NIMMessage)
      }
      const batches: V2NIMMessage[][] = buildQuickCommentBatches(messages)
      expect(batches.length).assertEqual(3)
      expect(batches[0].length).assertEqual(20)
      expect(batches[1].length).assertEqual(20)
      expect(batches[2].length).assertEqual(5)
      expect(batches[2][0].messageClientId).assertEqual('message-40')
    })

    it('should_convert_sdk_quick_comment_result_in_uikit_layer', 0, () => {
      const result: NIMEStrAnyObj = {
        'message-1': [makeComment(1, 'user-a', 100)]
      }
      const commentMap: Map<string, V2NIMMessageQuickComment[]> = quickCommentResultToMap(result)
      const comments: V2NIMMessageQuickComment[] = commentMap.get('message-1') ?? []
      expect(commentMap.size).assertEqual(1)
      expect(comments.length).assertEqual(1)
      expect(comments[0].operatorId).assertEqual('user-a')
    })

    it('should_build_all_reaction_indexes_without_delete_item', 0, () => {
      const indexes: number[] = buildAllReactionIndexes()
      expect(indexes.length).assertEqual(112)
      expect(indexes[0]).assertEqual(1)
      expect(indexes[111]).assertEqual(112)
      for (let index = 0; index < indexes.length; index++) {
        expect(indexes[index]).assertEqual(index + 1)
      }
    })

    it('should_group_by_index_deduplicate_operator_and_mark_self', 0, () => {
      const summaries: ReactionSummary[] = buildReactionSummaries([
        makeComment(2, 'user-b', 300),
        makeComment(1, 'self', 200),
        makeComment(1, 'user-a', 100),
        makeComment(1, 'user-a', 150)
      ], 'self')

      expect(summaries.length).assertEqual(2)
      expect(summaries[0].index).assertEqual(1)
      expect(summaries[0].count).assertEqual(2)
      expect(summaries[0].hasSelf).assertTrue()
      expect(summaries[0].firstCreateTime).assertEqual(100)
      expect(summaries[1].index).assertEqual(2)
      expect(summaries[1].hasSelf).assertFalse()
    })

    it('should_change_reaction_render_key_when_count_or_self_state_changes', 0, () => {
      const countOne = new ReactionSummary(65, 1, false, 100)
      const countTwo = new ReactionSummary(65, 2, false, 100)
      const selected = new ReactionSummary(65, 2, true, 100)

      expect(buildReactionSummaryRenderKey(countOne) === buildReactionSummaryRenderKey(countTwo)).assertFalse()
      expect(buildReactionSummaryRenderKey(countTwo) === buildReactionSummaryRenderKey(selected)).assertFalse()
      expect(buildReactionSummaryRenderKey(countTwo)).assertEqual(buildReactionSummaryRenderKey(
        new ReactionSummary(65, 2, false, 100)))
    })

    it('should_sort_same_time_by_index_and_preserve_custom_index', 0, () => {
      const summaries: ReactionSummary[] = buildReactionSummaries([
        makeComment(3, 'user-c', 100),
        makeComment(2, 'user-b', 100),
        makeComment(1001, 'custom', 1)
      ], 'self')

      expect(summaries.length).assertEqual(3)
      expect(summaries[0].index).assertEqual(1001)
      expect(summaries[1].index).assertEqual(2)
      expect(summaries[2].index).assertEqual(3)
    })

    it('should_apply_add_idempotently_and_remove_exact_operator_index', 0, () => {
      const first = makeComment(1, 'user-a', 100)
      const updated = makeComment(1, 'user-a', 200)
      const other = makeComment(1, 'user-b', 150)
      const afterAdd: V2NIMMessageQuickComment[] = applyQuickCommentNotification([first, other], {
        operationType: V2NIMMessageQuickCommentType.V2NIM_QUICK_COMMENT_STATE_ADD,
        quickComment: updated
      })
      expect(afterAdd.length).assertEqual(2)
      expect(afterAdd[1].createTime).assertEqual(200)

      const afterRemove: V2NIMMessageQuickComment[] = applyQuickCommentNotification(afterAdd, {
        operationType: V2NIMMessageQuickCommentType.V2NIM_QUICK_COMMENT_STATE_REMOVE,
        quickComment: updated
      })
      expect(afterRemove.length).assertEqual(1)
      expect(afterRemove[0].operatorId).assertEqual('user-b')
    })

    it('should_only_support_succeeded_content_messages', 0, () => {
      expect(canShowMessageReaction(makeMessage(V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT,
        V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED), false)).assertTrue()
      expect(canShowMessageReaction(makeMessage(V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE,
        V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING), false)).assertFalse()
      expect(canShowMessageReaction(makeMessage(V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION,
        V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED), false)).assertFalse()
      expect(canShowMessageReaction(makeMessage(V2NIMMessageType.V2NIM_MESSAGE_TYPE_TIPS,
        V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED), false)).assertFalse()
      expect(canShowMessageReaction(makeMessage(V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE,
        V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED), true)).assertFalse()
      expect(canShowMessageReaction(makeServerFailedMessage(), false)).assertFalse()
    })

    it('should_only_inset_visual_media_when_reaction_is_visible', 0, () => {
      expect(isReactionMediaMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE)).assertTrue()
      expect(isReactionMediaMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO)).assertTrue()
      expect(isReactionMediaMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION)).assertTrue()
      expect(isReactionMediaMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO)).assertTrue()
      expect(isReactionMediaMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT)).assertFalse()
      expect(isReactionMediaMessageType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE)).assertFalse()
    })

    it('should_calculate_reaction_width_from_capsule_content', 0, () => {
      expect(calculateReactionNaturalWidth([8])).assertEqual(93)
      expect(calculateReactionNaturalWidth([8, 16])).assertEqual(154)
      expect(calculateReactionNaturalWidth([])).assertEqual(40)
    })

    it('should_shrink_wrapped_reaction_width_to_the_widest_line', 0, () => {
      expect(calculateReactionLayoutWidth([8, 8, 8], 245)).assertEqual(199)
      expect(calculateReactionLayoutWidth([8, 8, 8, 8], 245)).assertEqual(199)
      expect(calculateReactionLayoutWidth([8, 16], 245)).assertEqual(154)
    })

    it('should_not_shrink_send_message_combo_when_reaction_is_visible', 0, () => {
      expect(getSendMessageComboFlexShrink(true)).assertEqual(0)
      expect(getSendMessageComboFlexShrink(false)).assertEqual(1)
    })

    it('should_not_right_align_send_message_content', 0, () => {
      expect(shouldRightAlignSendMessageContent(V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO)).assertFalse()
      expect(shouldRightAlignSendMessageContent(V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT)).assertFalse()
      expect(shouldRightAlignSendMessageContent(V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE)).assertFalse()
      expect(shouldRightAlignSendMessageContent(V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO)).assertFalse()
      expect(shouldRightAlignSendMessageContent(V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION)).assertFalse()
      expect(shouldRightAlignSendMessageContent(V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE)).assertFalse()
    })

    it('should_only_match_sdk_quick_comment_limit_error_code', 0, () => {
      expect(isQuickCommentLimitErrorCode(
        V2NIMErrorCode.V2NIM_ERROR_CODE_QUICK_COMMENT_LIMIT)).assertTrue()
      expect(isQuickCommentLimitErrorCode(
        V2NIMErrorCode.V2NIM_ERROR_CODE_RATE_LIMIT_REACHED)).assertFalse()
      expect(isQuickCommentLimitErrorCode(undefined)).assertFalse()
    })

    it('should_enable_reaction_for_ai_full_selection_only', 0, () => {
      expect(shouldEnableReactionForSelection(false, false, false)).assertTrue()
      expect(shouldEnableReactionForSelection(true, true, false)).assertTrue()
      expect(shouldEnableReactionForSelection(true, false, false)).assertFalse()
      expect(shouldEnableReactionForSelection(true, true, true)).assertFalse()
    })

    it('should_reposition_expanded_picker_inside_visible_area', 0, () => {
      expect(computeReactionMenuY(400, 450, 251, 700, 100, 12, true)).assertEqual(137)
      expect(computeReactionMenuY(20, 70, 251, 700, 100, 12, true)).assertEqual(82)
      expect(computeReactionMenuY(520, 570, 251, 700, 100, 12, false)).assertEqual(257)
    })
  })
}
