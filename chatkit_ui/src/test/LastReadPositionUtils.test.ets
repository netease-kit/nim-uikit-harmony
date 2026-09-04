/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  V2NIMMessage,
  V2NIMMessageConfig,
  V2NIMMessageListOption,
  V2NIMMessageListResult,
  V2NIMQueryDirection
} from '@nimsdk/base';
import {
  buildLastReadMessageQueryOption,
  canShowLastReadPosition,
  createLastReadPositionStatus,
  finishLastReadPositionJump,
  resolveLastReadPositionAfterUnreadCount,
  LastReadPositionStatus,
  queryLocalUnreadDisplayCount,
  startLastReadPositionJump,
  updateLastReadPositionStatus
} from '../main/ets/utils/LastReadPositionUtils';
import { ChatKitConfig } from '../main/ets/ChatKitConfig';

function makeMessage(messageClientId: string, createTime: number, unreadEnabled: boolean = true): V2NIMMessage {
  const message = new Object() as V2NIMMessage
  const messageConfig = new Object() as V2NIMMessageConfig
  message.messageClientId = messageClientId
  message.conversationId = 'conversation-id'
  message.createTime = createTime
  messageConfig.unreadEnabled = unreadEnabled
  message.messageConfig = messageConfig
  return message
}

function makeResult(messages: V2NIMMessage[], hasMore: boolean = false): V2NIMMessageListResult {
  return new TestMessageListResult(messages, hasMore)
}

class TestMessageListResult implements V2NIMMessageListResult {
  readonly messages: V2NIMMessage[]
  readonly anchorMessage: V2NIMMessage | undefined
  readonly hasMore: boolean

  constructor(messages: V2NIMMessage[], hasMore: boolean) {
    this.messages = messages
    this.anchorMessage = messages.length > 0 ? messages[messages.length - 1] : undefined
    this.hasMore = hasMore
  }
}

export default function lastReadPositionUtilsTest() {
  describe('LastReadPositionUtils', () => {
    it('should_enable_when_read_time_is_non_negative_and_disable_missing_time', 0, () => {
      expect(createLastReadPositionStatus(1)).assertEqual(LastReadPositionStatus.READY)
      expect(createLastReadPositionStatus(0)).assertEqual(LastReadPositionStatus.READY)
      expect(createLastReadPositionStatus(-1)).assertEqual(LastReadPositionStatus.DISABLED)
      expect(createLastReadPositionStatus(undefined)).assertEqual(LastReadPositionStatus.DISABLED)
    })

    it('should_show_after_positive_local_unread_count_is_ready', 0, () => {
      expect(resolveLastReadPositionAfterUnreadCount(LastReadPositionStatus.READY, 15))
        .assertEqual(LastReadPositionStatus.VISIBLE)
      expect(resolveLastReadPositionAfterUnreadCount(LastReadPositionStatus.READY, 0))
        .assertEqual(LastReadPositionStatus.DISABLED)
    })

    it('should_keep_consumed_state_when_count_is_positive', 0, () => {
      expect(resolveLastReadPositionAfterUnreadCount(LastReadPositionStatus.CONSUMED, 15))
        .assertEqual(LastReadPositionStatus.CONSUMED)
    })

    it('should_start_only_from_visible_state', 0, () => {
      expect(startLastReadPositionJump(LastReadPositionStatus.VISIBLE))
        .assertEqual(LastReadPositionStatus.LOCATING)
      expect(startLastReadPositionJump(LastReadPositionStatus.LOCATING))
        .assertEqual(LastReadPositionStatus.LOCATING)
      expect(startLastReadPositionJump(LastReadPositionStatus.CONSUMED))
        .assertEqual(LastReadPositionStatus.CONSUMED)
    })

    it('should_consume_on_success_and_restore_visible_on_failure', 0, () => {
      expect(finishLastReadPositionJump(LastReadPositionStatus.LOCATING, true))
        .assertEqual(LastReadPositionStatus.CONSUMED)
      expect(finishLastReadPositionJump(LastReadPositionStatus.LOCATING, false))
        .assertEqual(LastReadPositionStatus.VISIBLE)
    })

    it('should_build_strictly_after_query_option', 0, () => {
      const option = buildLastReadMessageQueryOption('conversation-id', 3000)

      expect(option.conversationId).assertEqual('conversation-id')
      expect(option.beginTime).assertEqual(3001)
      expect(option.limit).assertEqual(1)
      expect(option.direction).assertEqual(V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC)
      expect(option.strictMode).assertFalse()
      expect(option.onlyQueryLocal).assertFalse()

      const zeroTimeOption = buildLastReadMessageQueryOption('conversation-id', 0)
      expect(zeroTimeOption.beginTime).assertEqual(1)
    })

    it('should_query_local_unread_count_ascending_and_continue_with_anchor', 0, async (done: Function) => {
      const capturedOptions: V2NIMMessageListOption[] = []
      const pages: V2NIMMessageListResult[] = [
        makeResult([
          makeMessage('counted-1', 3001),
          makeMessage('ignored', 3002, false)
        ], true),
        makeResult([makeMessage('counted-2', 3003)])
      ]
      let pageIndex = 0

      const result = await queryLocalUnreadDisplayCount('conversation-id', 3000,
        async (option: V2NIMMessageListOption): Promise<V2NIMMessageListResult> => {
          capturedOptions.push(option)
          return pages[pageIndex++]
        })

      expect(result.count).assertEqual(3)
      expect(result.overflow).assertFalse()
      expect(capturedOptions.length).assertEqual(2)
      expect(capturedOptions[0].beginTime).assertEqual(3001)
      expect(capturedOptions[0].direction).assertEqual(V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC)
      expect(capturedOptions[0].limit).assertEqual(100)
      expect(capturedOptions[0].onlyQueryLocal).assertTrue()
      expect(capturedOptions[0].anchorMessage).assertUndefined()
      expect(capturedOptions[1].beginTime).assertEqual(3002)
      expect(capturedOptions[1].anchorMessage?.messageClientId).assertEqual('ignored')
      done()
    })

    it('should_keep_exact_count_when_local_query_finishes_at_99', 0, async (done: Function) => {
      const messages: V2NIMMessage[] = []
      for (let index = 0; index < 99; index++) {
        messages.push(makeMessage(`message-${index}`, 4000 + index))
      }
      let queryCount = 0

      const result = await queryLocalUnreadDisplayCount('conversation-id', 3000,
        async (_option: V2NIMMessageListOption): Promise<V2NIMMessageListResult> => {
          queryCount++
          return makeResult(messages)
        })

      expect(result.count).assertEqual(99)
      expect(result.overflow).assertFalse()
      expect(queryCount).assertEqual(1)
      done()
    })

    it('should_fail_when_has_more_result_has_no_anchor', 0, async (done: Function) => {
      let failed = false
      try {
        await queryLocalUnreadDisplayCount('conversation-id', 3000,
          async (_option: V2NIMMessageListOption): Promise<V2NIMMessageListResult> => {
            return makeResult([], true)
          })
      } catch (_err) {
        failed = true
      }

      expect(failed).assertTrue()
      done()
    })

    it('should_stop_at_the_100th_counted_message_and_report_overflow', 0, async (done: Function) => {
      const messages: V2NIMMessage[] = []
      for (let index = 0; index < 100; index++) {
        messages.push(makeMessage(`message-${index}`, 4000 + index))
      }
      let queryCount = 0

      const result = await queryLocalUnreadDisplayCount('conversation-id', 3000,
        async (_option: V2NIMMessageListOption): Promise<V2NIMMessageListResult> => {
          queryCount++
          return makeResult(messages)
        })

      expect(result.count).assertEqual(99)
      expect(result.overflow).assertTrue()
      expect(queryCount).assertEqual(1)
      done()
    })

    it('should_enable_last_read_position_by_default', 0, () => {
      expect(ChatKitConfig.enableLastReadPosition).assertTrue()
    })

    it('should_show_only_for_visible_or_locating_state_with_positive_count', 0, () => {
      expect(canShowLastReadPosition(LastReadPositionStatus.VISIBLE, 1, true)).assertTrue()
      expect(canShowLastReadPosition(LastReadPositionStatus.LOCATING, 1, true)).assertTrue()
      expect(canShowLastReadPosition(LastReadPositionStatus.VISIBLE, 1, false)).assertFalse()
      expect(canShowLastReadPosition(LastReadPositionStatus.VISIBLE, 0, true)).assertFalse()
      expect(canShowLastReadPosition(LastReadPositionStatus.CONSUMED, 1, true)).assertFalse()
    })

    it('should_consume_when_scroll_or_anchor_reaches_last_read_time', 0, () => {
      expect(updateLastReadPositionStatus(LastReadPositionStatus.VISIBLE, 3000, 2999))
        .assertEqual(LastReadPositionStatus.CONSUMED)
      expect(updateLastReadPositionStatus(LastReadPositionStatus.VISIBLE, 3000, 3000))
        .assertEqual(LastReadPositionStatus.CONSUMED)
      expect(updateLastReadPositionStatus(LastReadPositionStatus.VISIBLE, 3000, 3001))
        .assertEqual(LastReadPositionStatus.VISIBLE)
      expect(updateLastReadPositionStatus(LastReadPositionStatus.READY, 3000, 2999))
        .assertEqual(LastReadPositionStatus.CONSUMED)
      expect(updateLastReadPositionStatus(LastReadPositionStatus.CONSUMED, 3000, 2999))
        .assertEqual(LastReadPositionStatus.CONSUMED)
    })

  })
}
