/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { V2NIMMessage, V2NIMMessageSendingState, V2NIMMessageType } from '@nimsdk/base'
import { MessageHistoryItem } from '../model/MessageHistoryItem'
import { NIMMessageInfo } from '../model/NIMMessageInfo'

const AI_HELPER_HISTORY_LIMIT: number = 5

export class AIHelperContext {
  history: MessageHistoryItem[] = []
  receiverLastMessage: string = ''
  latestMessageClientId: string = ''
}

export function buildAIHelperContext(messages: NIMMessageInfo[]): AIHelperContext {
  const context = new AIHelperContext()
  const reversedHistory: MessageHistoryItem[] = []

  for (let index = messages.length - 1; index >= 0; index--) {
    const messageInfo = messages[index]
    if (!isSuccessfulTextMessage(messageInfo.message)) {
      continue
    }

    const text = messageInfo.message.text ?? ''
    if (context.latestMessageClientId.length === 0) {
      context.latestMessageClientId = messageInfo.message.messageClientId ?? ''
    }
    if (reversedHistory.length < AI_HELPER_HISTORY_LIMIT) {
      reversedHistory.push(new MessageHistoryItem(messageInfo.message.senderId, text))
    }
    if (context.receiverLastMessage.length === 0 && messageInfo.isReceiveMsg) {
      context.receiverLastMessage = text
    }
    if (reversedHistory.length >= AI_HELPER_HISTORY_LIMIT && context.receiverLastMessage.length > 0) {
      break
    }
  }

  for (let index = reversedHistory.length - 1; index >= 0; index--) {
    context.history.push(reversedHistory[index])
  }
  return context
}

function isSuccessfulTextMessage(message: V2NIMMessage): boolean {
  return message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT &&
    message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
}
