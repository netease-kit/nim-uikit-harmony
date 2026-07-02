/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import {
  AIRepo,
  AIUserManager
} from '@nimkit/chatkit'
import {
  V2NIMAIModelCallContent,
  V2NIMAIModelCallMessage,
  V2NIMAIModelCallResult,
  V2NIMAIModelConfigParams,
  V2NIMAIModelRoleType,
  V2NIMProxyAIModelCallParams
} from '@nimsdk/base'
import { NECommonUtils } from '@nimkit/common'

export class AISearchMessage {
  answer: string = ''

  constructor(answer: string = '') {
    this.answer = answer
  }
}

@ObservedV2
export class AISearchViewModel {
  @Trace messages: AISearchMessage[] = []
  @Trace isLoading: boolean = false
  @Trace errorText: ResourceStr | string = ''
  private requestIds: string[] = []
  private contextMessages: V2NIMAIModelCallMessage[] = []

  private proxyCallback = (result: V2NIMAIModelCallResult) => {
    const aiUser = AIUserManager.getAISearchUser()
    if (!aiUser || result.accountId !== aiUser.accountId || !this.requestIds.includes(result.requestId)) {
      return
    }

    if (result.code === 200 || result.code === 0) {
      this.setLatestAnswer(result.content?.msg ?? '')
    } else {
      this.setLatestAnswer(getAISearchErrorText(result.code))
    }
    this.requestIds = this.requestIds.filter((requestId: string) => requestId !== result.requestId)
    if (this.requestIds.length === 0) {
      this.isLoading = false
    }
  }

  aboutToAppear(): void {
    AIRepo.onProxyAIModelCall(this.proxyCallback)
  }

  aboutToDisappear(): void {
    AIRepo.offProxyAIModelCall(this.proxyCallback)
    this.requestIds = []
    this.contextMessages = []
  }

  search(keyword: string): boolean {
    const text = keyword.trim()
    const aiUser = AIUserManager.getAISearchUser()
    if (text.length === 0 || !aiUser || this.isLoading) {
      return false
    }

    const requestId = this.createRequestId()
    const params: V2NIMProxyAIModelCallParams = {
      accountId: aiUser.accountId,
      requestId: requestId,
      content: { msg: text, type: 0 } as V2NIMAIModelCallContent,
      messages: this.contextMessages.length > 0 ? this.contextMessages : undefined,
      modelConfigParams: { temperature: 0.8 } as V2NIMAIModelConfigParams
    }

    this.isLoading = true
    this.errorText = ''
    AIRepo.proxyAIModelCall(params)
      .then(() => {
        this.requestIds.push(requestId)
        this.contextMessages.unshift({
          role: V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_USER,
          msg: text,
          type: 0
        } as V2NIMAIModelCallMessage)
      })
      .catch(() => {
        this.isLoading = false
        NECommonUtils.showToast($r('app.string.chat_ai_search_error'))
      })
    return true
  }

  private setLatestAnswer(answer: ResourceStr | string): void {
    if (this.messages.length === 0) {
      this.messages.unshift(new AISearchMessage(answer as string))
      return
    }
    this.messages.unshift(new AISearchMessage(answer as string))
  }

  private createRequestId(): string {
    return 'ai_search_' + Date.now() + '_' + Math.floor(Math.random() * 1000000)
  }
}

export function getAISearchErrorText(errorCode?: number): ResourceStr {
  switch (errorCode) {
    case 102416:
      return $r('app.string.chat_ai_error_failed_request_to_the_llm')
    case 102417:
      return $r('app.string.chat_ai_error_ai_messages_function_disabled')
    case 102418:
      return $r('app.string.chat_ai_error_not_an_ai_account')
    case 102419:
      return $r('app.string.chat_ai_error_cannot_blocklist_an_ai_account')
    case 191004:
      return $r('app.string.chat_ai_error_parameter')
    case 191005:
    case 191006:
      return $r('app.string.chat_ai_error_user_not_exist')
    case 191007:
      return $r('app.string.chat_ai_error_user_banned')
    case 191008:
      return $r('app.string.chat_ai_error_user_chat_banned')
    case 191009:
      return $r('app.string.chat_ai_error_message_hit_antispam')
    case 191010:
      return $r('app.string.chat_ai_error_team_member_not_exist')
    case 191011:
      return $r('app.string.chat_ai_error_team_normal_member_chat_banned')
    case 191012:
      return $r('app.string.chat_ai_error_team_member_chat_banned')
    case 191013:
      return $r('app.string.chat_ai_error_rate_limit_exceeded')
    default:
      return $r('app.string.chat_ai_search_error')
  }
}
