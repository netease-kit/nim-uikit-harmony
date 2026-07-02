/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { V2NIMMessage, V2NIMMessageSendingState, V2NIMMessageType } from '@nimsdk/base'
import { buildAIHelperContext } from '../../../main/ets/common/AIHelperUtils'
import { NIMMessageInfo } from '../../../main/ets/model/NIMMessageInfo'

function textInfo(text: string, senderId: string, state: V2NIMMessageSendingState =
V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED): NIMMessageInfo {
  const message = new Object() as V2NIMMessage
  message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT
  message.text = text
  message.senderId = senderId
  message.sendingState = state
  message.messageClientId = text
  const info = new Object() as NIMMessageInfo
  info.message = message
  info.isReceiveMsg = senderId === 'peer'
  return info
}

function imageInfo(clientId: string): NIMMessageInfo {
  const message = new Object() as V2NIMMessage
  message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE
  message.senderId = 'peer'
  message.sendingState = V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
  message.messageClientId = clientId
  const info = new Object() as NIMMessageInfo
  info.message = message
  info.isReceiveMsg = true
  return info
}

export default function aiHelperUtilsTest() {
  describe('AIHelperUtils', () => {
    it('should_build_latest_five_successful_text_history_in_time_order', 0, () => {
      const context = buildAIHelperContext([
        textInfo('消息1', 'peer'),
        textInfo('消息2', 'me'),
        textInfo('消息3', 'peer'),
        textInfo('消息4', 'me'),
        textInfo('消息5', 'peer'),
        textInfo('消息6', 'me')
      ])

      expect(context.history.length).assertEqual(5)
      expect(context.history[0].text).assertEqual('消息2')
      expect(context.history[4].text).assertEqual('消息6')
      expect(context.receiverLastMessage).assertEqual('消息5')
    })

    it('should_ignore_failed_text_messages', 0, () => {
      const context = buildAIHelperContext([
        textInfo('成功1', 'peer'),
        textInfo('失败消息', 'me', V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED),
        textInfo('成功2', 'me')
      ])

      expect(context.history.length).assertEqual(2)
      expect(context.history[0].text).assertEqual('成功1')
      expect(context.history[1].text).assertEqual('成功2')
    })

    it('should_skip_non_text_messages_and_keep_searching_text_history', 0, () => {
      const context = buildAIHelperContext([
        textInfo('旧文本1', 'peer'),
        textInfo('旧文本2', 'me'),
        imageInfo('image1'),
        imageInfo('image2'),
        imageInfo('image3')
      ])

      expect(context.history.length).assertEqual(2)
      expect(context.history[0].text).assertEqual('旧文本1')
      expect(context.history[1].text).assertEqual('旧文本2')
      expect(context.receiverLastMessage).assertEqual('旧文本1')
    })

    it('should_use_latest_successful_text_message_id_as_cache_key', 0, () => {
      const context = buildAIHelperContext([
        textInfo('旧文本1', 'peer'),
        textInfo('最新文本', 'me'),
        imageInfo('image1'),
        imageInfo('image2')
      ])

      expect(context.latestMessageClientId).assertEqual('最新文本')
    })

    it('should_find_receiver_last_text_beyond_latest_five_text_messages', 0, () => {
      const context = buildAIHelperContext([
        textInfo('对方较早消息', 'peer'),
        textInfo('我1', 'me'),
        textInfo('我2', 'me'),
        textInfo('我3', 'me'),
        textInfo('我4', 'me'),
        textInfo('我5', 'me'),
        textInfo('我6', 'me')
      ])

      expect(context.history.length).assertEqual(5)
      expect(context.history[0].text).assertEqual('我2')
      expect(context.receiverLastMessage).assertEqual('对方较早消息')
    })
  })
}
