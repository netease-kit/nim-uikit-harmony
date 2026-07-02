/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  buildAIReplyContextMessage,
  buildAIContextMessages,
  getAIMessageContent,
  isForwardMessageSupportedForAI,
  isEmojiOnlyText,
  resolveAIMessageContentForForward,
  resolveAIMessageContentForSend
} from '../../../main/ets/common/AIChatUtils'
import {
  V2NIMAIModelRoleType,
  V2NIMMessage,
  V2NIMMessageAIStatus,
  V2NIMMessageAIConfig,
  V2NIMMessageAttachment,
  V2NIMMessageType
} from '@nimsdk/base'

interface MultiLineTestAttachmentData {
  title: string
  body: string
}

interface MultiLineTestAttachmentPayload {
  type: number
  data: MultiLineTestAttachmentData
}

interface MergedForwardTestAttachmentData {
  title: string
  abstracts: string[]
}

interface MergedForwardTestAttachmentPayload {
  type: number
  data: MergedForwardTestAttachmentData
}

function textMessage(text: string, senderId: string = 'me', aiStatus?: V2NIMMessageAIStatus): V2NIMMessage {
  const message = new Object() as V2NIMMessage
  message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT
  message.text = text
  message.senderId = senderId
  if (aiStatus !== undefined) {
    const aiConfig = new Object() as V2NIMMessageAIConfig
    aiConfig.accountId = 'ai_1'
    aiConfig.aiStatus = aiStatus
    message.aiConfig = aiConfig
  }
  return message
}

function customAttachment(raw: string): V2NIMMessageAttachment {
  const attachment = new Object() as V2NIMMessageAttachment
  attachment.raw = raw
  return attachment
}

function messageWithType(messageType: V2NIMMessageType, text?: string): V2NIMMessage {
  const message = new Object() as V2NIMMessage
  message.messageType = messageType
  message.text = text
  return message
}

function multiLineMessage(title: string, body: string): V2NIMMessage {
  const data: MultiLineTestAttachmentData = {
    title: title,
    body: body
  }
  const payload: MultiLineTestAttachmentPayload = {
    type: 102,
    data: data
  }
  const raw = JSON.stringify(payload)
  const message = new Object() as V2NIMMessage
  message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM
  message.text = `${title}\n${body}`
  message.attachment = customAttachment(raw)
  return message
}

function mergedForwardCustomMessage(text: string): V2NIMMessage {
  const data: MergedForwardTestAttachmentData = {
    title: '合并转发',
    abstracts: []
  }
  const payload: MergedForwardTestAttachmentPayload = {
    type: 101,
    data: data
  }
  const raw = JSON.stringify(payload)
  const message = new Object() as V2NIMMessage
  message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM
  message.text = text
  message.attachment = customAttachment(raw)
  return message
}

function aiResponseMessage(text: string): V2NIMMessage {
  return textMessage(text, 'me', V2NIMMessageAIStatus.V2NIM_MESSAGE_AI_STATUS_RESPONSE)
}

function imageMessage(): V2NIMMessage {
  return messageWithType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE)
}

function locationMessage(text: string): V2NIMMessage {
  return messageWithType(V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION, text)
}

export default function aiChatUtilsTest() {
  describe('AIChatUtils', () => {
    it('should_join_multiline_title_and_body_as_ai_content', 0, () => {
      expect(getAIMessageContent(multiLineMessage('标题', '正文'))).assertEqual('标题正文')
    })

    it('should_not_use_non_text_message_text_as_ai_content_for_send', 0, () => {
      expect(resolveAIMessageContentForSend(locationMessage('位置标题'), '')).assertUndefined()
    })

    it('should_use_text_message_text_as_ai_content_for_send', 0, () => {
      expect(resolveAIMessageContentForSend(textMessage('hello'))).assertEqual('hello')
    })

    it('should_use_multiline_body_when_title_empty_as_ai_content', 0, () => {
      expect(getAIMessageContent(multiLineMessage('', '正文'))).assertEqual('正文')
    })

    it('should_not_use_non_text_message_as_ai_content_for_forward', 0, () => {
      expect(resolveAIMessageContentForForward(imageMessage())).assertUndefined()
    })

    it('should_use_multiline_message_as_ai_content_for_forward', 0, () => {
      const message = multiLineMessage('标题', '正文')

      expect(isForwardMessageSupportedForAI(message)).assertTrue()
      expect(resolveAIMessageContentForForward(message)).assertEqual('标题正文')
    })

    it('should_not_use_non_multiline_custom_message_as_ai_content', 0, () => {
      const message = mergedForwardCustomMessage('[聊天记录]hello')

      expect(getAIMessageContent(message)).assertEqual('')
      expect(resolveAIMessageContentForSend(message, message.text)).assertUndefined()
      expect(isForwardMessageSupportedForAI(message)).assertFalse()
      expect(resolveAIMessageContentForForward(message)).assertUndefined()
    })

    it('should_not_include_non_multiline_custom_message_in_ai_context', 0, () => {
      const messages: V2NIMMessage[] = [
        textMessage('旧消息', 'me'),
        mergedForwardCustomMessage('[聊天记录]hello'),
        multiLineMessage('标题', '正文')
      ]

      const contextMessages = buildAIContextMessages(messages)

      expect(contextMessages.length).assertEqual(2)
      expect(contextMessages[0].msg).assertEqual('旧消息')
      expect(contextMessages[1].msg).assertEqual('标题正文')
    })

    it('should_not_use_emoji_only_text_as_ai_content_for_forward', 0, () => {
      const message = textMessage('😀')

      expect(isEmojiOnlyText('😀')).assertTrue()
      expect(isForwardMessageSupportedForAI(message)).assertFalse()
      expect(resolveAIMessageContentForForward(message)).assertUndefined()
    })

    it('should_not_use_custom_emoji_only_text_as_ai_content_for_forward', 0, () => {
      const message = textMessage('[大笑]')

      expect(isForwardMessageSupportedForAI(message)).assertFalse()
      expect(resolveAIMessageContentForForward(message)).assertUndefined()
    })

    it('should_use_plain_text_message_as_ai_content_for_forward', 0, () => {
      expect(resolveAIMessageContentForForward(textMessage('hello'))).assertEqual('hello')
    })

    it('should_build_context_from_loaded_text_messages_without_querying_more', 0, () => {
      const messages: V2NIMMessage[] = [
        textMessage('旧消息', 'me'),
        aiResponseMessage('AI 回复'),
        imageMessage(),
        textMessage('最新问题', 'me')
      ]

      const contextMessages = buildAIContextMessages(messages)

      expect(contextMessages.length).assertEqual(3)
      expect(contextMessages[0].role).assertEqual(V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_USER)
      expect(contextMessages[0].msg).assertEqual('旧消息')
      expect(contextMessages[1].role).assertEqual(V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_ASSISTANT)
      expect(contextMessages[2].msg).assertEqual('最新问题')
    })

    it('should_build_single_reply_context_message', 0, () => {
      const replyContext = buildAIReplyContextMessage(textMessage('被回复消息', 'user_1'))

      expect(replyContext).not().assertUndefined()
      expect(replyContext?.role).assertEqual(V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_USER)
      expect(replyContext?.msg).assertEqual('被回复消息')
    })

    it('should_build_reply_context_as_user_role_for_ai_response', 0, () => {
      const replyContext = buildAIReplyContextMessage(aiResponseMessage('数字人回复'))

      expect(replyContext).not().assertUndefined()
      expect(replyContext?.role).assertEqual(V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_USER)
      expect(replyContext?.msg).assertEqual('数字人回复')
    })

    it('should_not_build_reply_context_for_non_text_like_message', 0, () => {
      expect(buildAIReplyContextMessage(imageMessage())).assertUndefined()
    })

    it('should_drop_leading_ai_response_from_context', 0, () => {
      const messages: V2NIMMessage[] = [
        aiResponseMessage('AI 回复'),
        textMessage('用户问题', 'me')
      ]

      const contextMessages = buildAIContextMessages(messages)

      expect(contextMessages.length).assertEqual(1)
      expect(contextMessages[0].msg).assertEqual('用户问题')
    })

    it('should_only_use_last_30_loaded_messages_as_context_window', 0, () => {
      const messages: V2NIMMessage[] = []
      for (let index = 0; index < 35; index++) {
        messages.push(textMessage(`消息${index}`))
      }

      const contextMessages = buildAIContextMessages(messages)

      expect(contextMessages.length).assertEqual(30)
      expect(contextMessages[0].msg).assertEqual('消息5')
      expect(contextMessages[29].msg).assertEqual('消息34')
    })
  })
}
