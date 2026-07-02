/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium'
import { getOperateMenu } from '../../../main/ets/common/ChatUtils'
import { MessageOperationType } from '../../../main/ets/model/MessageOperationItem'
import {
  V2NIMMessage,
  V2NIMMessageAIConfig,
  V2NIMMessageAIStatus,
  V2NIMMessageAIStreamStatus,
  V2NIMMessageSendingState,
  V2NIMMessageType
} from '@nimsdk/base'
import { NIMMessageInfo } from '../../../main/ets/model/NIMMessageInfo'

function makeMessageInfo(sendingState: V2NIMMessageSendingState): NIMMessageInfo {
  return new NIMMessageInfo({
    messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT,
    text: '发送失败',
    sendingState: sendingState
  } as V2NIMMessage)
}

function makeAIStreamMessageInfo(status: V2NIMMessageAIStreamStatus): NIMMessageInfo {
  const aiConfig = new Object() as V2NIMMessageAIConfig
  aiConfig.accountId = 'ai_1'
  aiConfig.aiStatus = V2NIMMessageAIStatus.V2NIM_MESSAGE_AI_STATUS_RESPONSE
  aiConfig.aiStream = true
  aiConfig.aiStreamStatus = status

  const message = new Object() as V2NIMMessage
  message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT
  message.text = 'streaming'
  message.sendingState = V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
  message.aiConfig = aiConfig
  return new NIMMessageInfo(message)
}

export default function chatOperationMenuTest() {
  describe('ChatOperationMenu', () => {
    it('should_only_show_delete_for_failed_message', 0, () => {
      const menu = getOperateMenu(makeMessageInfo(V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED))

      expect(menu.length).assertEqual(1)
      expect(menu[0].operationType).assertEqual(MessageOperationType.Delete)
    })

    it('should_not_show_menu_for_streaming_ai_message', 0, () => {
      const menu = getOperateMenu(makeAIStreamMessageInfo(
        V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING
      ))

      expect(menu.length).assertEqual(0)
    })

    it('should_not_allow_multi_select_for_ai_stream_placeholder', 0, () => {
      const messageInfo = makeAIStreamMessageInfo(
        V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_PLACEHOLDER
      )

      expect(messageInfo.canOperateInMultiSelect()).assertFalse()
    })

    it('should_not_allow_multi_select_for_ai_streaming_message', 0, () => {
      const messageInfo = makeAIStreamMessageInfo(
        V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING
      )

      expect(messageInfo.canOperateInMultiSelect()).assertFalse()
    })

    it('should_allow_multi_select_for_non_stream_ai_response_message', 0, () => {
      const messageInfo = makeAIStreamMessageInfo(
        V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_NONE
      )

      expect(messageInfo.canOperateInMultiSelect()).assertTrue()
    })

    it('should_allow_multi_select_for_finished_ai_stream_message', 0, () => {
      const messageInfo = makeAIStreamMessageInfo(
        V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_GENERATED
      )

      expect(messageInfo.canOperateInMultiSelect()).assertTrue()
    })

    it('should_not_allow_multi_select_for_failed_message', 0, () => {
      const messageInfo = makeMessageInfo(V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED)

      expect(messageInfo.canOperateInMultiSelect()).assertFalse()
    })

    it('should_not_allow_multi_select_for_sending_message', 0, () => {
      const messageInfo = makeMessageInfo(V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING)

      expect(messageInfo.canOperateInMultiSelect()).assertFalse()
    })
  })
}
