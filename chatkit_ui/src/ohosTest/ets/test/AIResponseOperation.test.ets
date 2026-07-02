/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  V2NIMConversationType,
  V2NIMMessage,
  V2NIMMessageAIConfig,
  V2NIMMessageAIStatus,
  V2NIMMessageAIStreamStatus,
  V2NIMMessageRefer,
  V2NIMMessageType
} from '@nimsdk/base'
import { canOperateAIResponseMessage } from '../../../main/ets/model/NIMMessageInfo'

function makeAIResponseMessage(messageSenderId: string, requesterId?: string): V2NIMMessage {
  const aiConfig = new Object() as V2NIMMessageAIConfig
  aiConfig.accountId = 'ai_1'
  aiConfig.aiStatus = V2NIMMessageAIStatus.V2NIM_MESSAGE_AI_STATUS_RESPONSE
  aiConfig.aiStream = true
  aiConfig.aiStreamStatus = V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING

  const message = new Object() as V2NIMMessage
  message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT
  message.senderId = messageSenderId
  message.aiConfig = aiConfig
  if (requesterId) {
    const threadReply = new Object() as V2NIMMessageRefer
    threadReply.senderId = requesterId
    threadReply.receiverId = 'receiver_1'
    threadReply.messageClientId = 'root_client_id'
    threadReply.messageServerId = 'root_server_id'
    threadReply.createTime = 1
    threadReply.conversationType = V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P
    threadReply.conversationId = 'p2p_user_1'
    message.threadReply = threadReply
  }
  return message
}

/**
 * AIResponseOperation 测试：
 * canOperateAIResponse 依赖 ChatKitClient.nim.loginService.getLoginUser()
 * 由于 ArkTS 不允许在 src/test 中 mock NIMInterface 类型的 ChatKitClient.nim，
 * 这些测试需移至 ohosTest 设备环境
 */
export default function aiResponseOperationTest() {
  describe('aiResponseOperationTest', () => {
    it('should_exist_as_test_entry', 0, () => {
      expect(true).assertTrue();
    });

    it('should_allow_requester_to_operate_ai_response_even_when_sender_is_ai_user', 0, () => {
      const message = makeAIResponseMessage('ai_1', 'user_1')

      expect(canOperateAIResponseMessage(message, 'user_1')).assertTrue()
    })

    it('should_not_allow_non_requester_to_operate_ai_response', 0, () => {
      const message = makeAIResponseMessage('ai_1', 'user_1')

      expect(canOperateAIResponseMessage(message, 'user_2')).assertFalse()
    })

    it('should_not_allow_ai_response_without_requester_refer', 0, () => {
      const message = makeAIResponseMessage('user_1')

      expect(canOperateAIResponseMessage(message, 'user_1')).assertFalse()
    })
  });
}
