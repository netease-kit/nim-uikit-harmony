/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMAIModelCallMessage,
  V2NIMAIModelRoleType,
  V2NIMMessage,
  V2NIMMessageAIStatus,
  V2NIMMessageType
} from '@nimsdk/base'
import {
  getMultiLineBody,
  getMultiLineTitle,
  isMultiLineMessage
} from '@nimkit/chatkit'
import { EmojiParseType, NEEmojiManager, NEEmojiParseResult } from '../manager/NEEmojiManager'

const AI_CONTEXT_LIMIT: number = 30
const CUSTOM_EMOJI_TAG_PATTERN: RegExp = /^\[[^\]]+\]$/

export function isTextLikeMessageForAI(message: V2NIMMessage): boolean {
  if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    return !isEmojiOnlyText(message.text ?? '')
  }
  return isSupportedCustomMessageForAI(message)
}

export function isForwardMessageSupportedForAI(message: V2NIMMessage): boolean {
  if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    return !isEmojiOnlyText(message.text ?? '')
  }
  return isSupportedCustomMessageForAI(message)
}

export function getAIMessageContent(message: V2NIMMessage): string {
  if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    return message.text ?? ''
  }
  if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
    const title = getMultiLineTitle(message)
    const body = getMultiLineBody(message)
    if (title.length > 0 && body.length > 0) {
      return `${title}${body}`
    }
    return title || body
  }
  return ''
}

export function resolveAIMessageContentForSend(message: V2NIMMessage, content?: string): string | undefined {
  if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    const textContent = content !== undefined && content.length > 0 ? content : getAIMessageContent(message)
    return textContent.length > 0 ? textContent : undefined
  }
  if (isSupportedCustomMessageForAI(message)) {
    const customContent = content !== undefined && content.length > 0 ? content : getAIMessageContent(message)
    return customContent.length > 0 ? customContent : undefined
  }
  return undefined
}

export function resolveAIMessageContentForForward(message: V2NIMMessage): string | undefined {
  if (!isForwardMessageSupportedForAI(message)) {
    return undefined
  }
  const content = getAIMessageContent(message)
  return content.length > 0 ? content : undefined
}

function isSupportedCustomMessageForAI(message: V2NIMMessage): boolean {
  if (message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
    return false
  }
  if (!isMultiLineMessage(message)) {
    return false
  }
  return getAIMessageContent(message).trim().length > 0
}

export function isEmojiOnlyText(text: string): boolean {
  const trimmedText = text.trim()
  if (trimmedText.length === 0) {
    return false
  }
  if (isSystemEmojiOnlyText(trimmedText)) {
    return true
  }
  if (CUSTOM_EMOJI_TAG_PATTERN.test(trimmedText)) {
    return true
  }
  const parsedItems: NEEmojiParseResult[] = NEEmojiManager.instance.parseEmojiText(trimmedText)
  let hasEmoji = false
  for (const item of parsedItems) {
    if (item.type === EmojiParseType.emoji && item.emoji !== undefined) {
      hasEmoji = true
    } else if ((item.text ?? '').trim().length > 0) {
      return false
    }
  }
  return hasEmoji
}

function isSystemEmojiOnlyText(text: string): boolean {
  const compactText = text.replace(/\s/g, '')
  if (compactText.length === 0) {
    return false
  }
  const withoutSurrogateEmoji = compactText.replace(/[\uD83C-\uDBFF][\uDC00-\uDFFF]/g, '')
  const withoutBmpEmoji = withoutSurrogateEmoji.replace(/[\u2600-\u27BF]\uFE0F?/g, '')
  return withoutBmpEmoji.length === 0
}

export function buildAIContextMessages(messages: V2NIMMessage[]): V2NIMAIModelCallMessage[] {
  const result: V2NIMAIModelCallMessage[] = []
  const startIndex = Math.max(messages.length - AI_CONTEXT_LIMIT, 0)
  for (let index = messages.length - 1; index >= startIndex; index--) {
    const message = messages[index]
    if (!isTextLikeMessageForAI(message)) {
      continue
    }
    const content = getAIMessageContent(message).trim()
    if (content.length === 0) {
      continue
    }
    const isAIResponse = message.aiConfig?.aiStatus === V2NIMMessageAIStatus.V2NIM_MESSAGE_AI_STATUS_RESPONSE
    result.unshift({
      role: isAIResponse ? V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_ASSISTANT :
      V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_USER,
      msg: content,
      type: 0
    })
  }

  while (result.length > 0 && result[0].role === V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_ASSISTANT) {
    result.shift()
  }
  return result
}

export function buildAIReplyContextMessage(message: V2NIMMessage): V2NIMAIModelCallMessage | undefined {
  if (!isTextLikeMessageForAI(message)) {
    return undefined
  }
  const content = getAIMessageContent(message).trim()
  if (content.length === 0) {
    return undefined
  }
  return {
    role: V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_USER,
    msg: content,
    type: 0
  }
}
