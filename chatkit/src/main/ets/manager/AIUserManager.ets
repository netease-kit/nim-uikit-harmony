/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { NEAIUserCache } from '../NEAIUserCache'
import { V2NIMAIUser } from '@nimsdk/base'

export const AI_CHAT_KEY: string = 'aiChat'
export const AI_CHAT_LEGACY_KEY: string = 'ai_chat'
export const AI_WELCOME_TEXT_KEY: string = 'welcomeText'

type AIUserExtensionValue = string | number | boolean | Object | undefined

function parseAIUserExtension(source?: string): Record<string, AIUserExtensionValue> {
  if (!source || source.length === 0) {
    return {}
  }

  try {
    const parsed = JSON.parse(source) as Record<string, AIUserExtensionValue>
    if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed
    }
  } catch (_e) {
    return {}
  }
  return {}
}

export function isAIChatUserByServerExtension(serverExtension?: string): boolean {
  const extension = parseAIUserExtension(serverExtension)
  const aiChat = extension[AI_CHAT_KEY] ?? extension[AI_CHAT_LEGACY_KEY]
  return aiChat === 1 || aiChat === '1'
}

export function getAIWelcomeTextByServerExtension(serverExtension?: string): string {
  const extension = parseAIUserExtension(serverExtension)
  const welcomeText = extension[AI_WELCOME_TEXT_KEY]
  return typeof welcomeText === 'string' ? welcomeText : ''
}

export function filterAIChatUsers(users: V2NIMAIUser[]): V2NIMAIUser[] {
  return users.filter((user: V2NIMAIUser) => {
    return isAIChatUserByServerExtension(user.serverExtension)
  })
}

export interface AIUserAgentProvider {
  getAiSearchUser(users: V2NIMAIUser[]): V2NIMAIUser | undefined
  getAiTranslateUser(users: V2NIMAIUser[]): V2NIMAIUser | undefined
  getAiTranslateLanguages(users: V2NIMAIUser[]): string[]
}

/**
 * AI 用户管理器
 * 对齐 Android AIUserManager
 */
export class AIUserManager {
  private static aiUserProvider: AIUserAgentProvider | undefined = undefined

  static setProvider(provider: AIUserAgentProvider | undefined): void {
    AIUserManager.aiUserProvider = provider
  }

  static setAIUserAgentProvider(provider: AIUserAgentProvider | undefined): void {
    AIUserManager.setProvider(provider)
  }

  /**
   * 获取 AI 划词搜索数字人
   * 对齐 Android AIUserManager.getAISearchUser()
   */
  static getAISearchUser(): V2NIMAIUser | undefined {
    return AIUserManager.aiUserProvider?.getAiSearchUser(NEAIUserCache.getAIUserList())
  }

  /**
   * 获取 AI 翻译数字人
   * 对齐 Android AIUserManager.getAITranslateUser()
   */
  static getAITranslateUser(): V2NIMAIUser | undefined {
    return AIUserManager.aiUserProvider?.getAiTranslateUser(NEAIUserCache.getAIUserList())
  }

  /**
   * 获取翻译目标语言列表
   * 对齐 Android AIUserManager.getAITranslateLanguages()
   */
  static getAITranslateLanguages(): string[] {
    return AIUserManager.aiUserProvider?.getAiTranslateLanguages(NEAIUserCache.getAIUserList()) ?? []
  }

  /**
   * 获取可被 @ 加入对话的 AI 聊数字人
   * 对齐 Android AIUserManager.getAIChatUserList()
   */
  static getAIChatUserList(): V2NIMAIUser[] {
    return filterAIChatUsers(NEAIUserCache.getAIUserList())
  }

  static getWelcomeText(accountId: string): string {
    const aiUser = NEAIUserCache.getAIUser(accountId)
    return getAIWelcomeTextByServerExtension(aiUser?.serverExtension)
  }

  static isAIUser(accountId?: string): boolean {
    if (!accountId || accountId.length === 0) {
      return false
    }
    return NEAIUserCache.getAIUser(accountId) !== undefined
  }

  static isAIChatUser(accountId?: string): boolean {
    if (!accountId || accountId.length === 0) {
      return false
    }
    const aiUser = NEAIUserCache.getAIUser(accountId)
    return isAIChatUserByServerExtension(aiUser?.serverExtension)
  }
}
