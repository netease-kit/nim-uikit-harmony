/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { http } from '@kit.NetworkKit'
import { AIHelperItem } from '../model/AIHelperItem'
import { MessageHistoryItem } from '../model/MessageHistoryItem'
import { ChatKitClient } from '@nimkit/chatkit'

const TAG_COLORS: ResourceColor[] = ['#FFE8F3', '#FFE8E8', '#E8F4FF']
const TAG_TEXT_COLORS: ResourceColor[] = ['#F159A2', '#E75257', '#598CF1']

/**
 * AI 助聊 API 仓库
 * 对齐 Android IMKitNetRequester.requestAIChatHelper()
 */
export class AIHelperRepo {
  private static readonly HOST: string = 'https://yiyong.netease.im/'
  private static readonly PATH: string = 'im/ai/chat_assistant/v1/chat_assist'

  static async requestAIHelper(body: string): Promise<AIHelperItem[]> {
    const httpRequest = http.createHttp()
    try {
      const fullUrl = AIHelperRepo.HOST + AIHelperRepo.PATH
      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'appKey': ChatKitClient.appKey,
          'accountId': ChatKitClient.getLoginUserId(),
          'accessToken': ChatKitClient.accountToken
        },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 15000
      })

      if (response.responseCode === 200) {
        const json: Record<string, Object> = JSON.parse(response.result as string) as Record<string, Object>
        const data = json['data'] as Record<string, Object> | undefined
        if (data) {
          const items = data['items'] as Array<Record<string, Object>> | undefined
          if (items && items.length > 0) {
            return AIHelperRepo.convertToAIHelperItems(items)
          }
        }
      }
      return []
    } finally {
      httpRequest.destroy()
    }
  }

  private static convertToAIHelperItems(items: Array<Record<string, Object>>): AIHelperItem[] {
    const result: AIHelperItem[] = []
    for (let i = 0; i < items.length; i++) {
      const answerItem = items[i]
      const answer = answerItem['answer'] as string ?? ''
      const styleName = answerItem['style_name'] as string ?? ''
      const helperItem = new AIHelperItem(answer, styleName)
      helperItem.tagBgColor = TAG_COLORS[i % 3]
      helperItem.tagTextColor = TAG_TEXT_COLORS[i % 3]
      result.push(helperItem)
    }
    return result
  }

  static buildRequestJSON(
    messageTexts: MessageHistoryItem[],
    lastReceivedText: string,
    chatAccountId: string,
    selfAccountId: string
  ): string {
    const history: Record<string, Object>[] = []
    for (let i = 0; i < messageTexts.length; i++) {
      const msg = messageTexts[i]
      const entry: Record<string, Object> = {}
      entry['sender_id'] = msg.senderId
      entry['text'] = msg.text
      history.push(entry)
    }
    const body: Record<string, Object> = {}
    body['receiver_last_message'] = lastReceivedText
    body['history'] = history
    body['sender_id'] = chatAccountId
    body['receiver_id'] = selfAccountId
    body['style_list'] = ['warm', 'hot', 'smart']
    return JSON.stringify(body)
  }
}
