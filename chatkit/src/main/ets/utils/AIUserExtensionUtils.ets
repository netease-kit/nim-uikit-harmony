/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMAIUser } from '@nimsdk/base'

export const AI_USER_PIN_DEFAULT_KEY: string = 'pinDefault'
export const MINE_UNPIN_AI_USERS_KEY: string = 'unpinAIUsers'

type AIUserExtensionValue = Object | string | number | boolean | string[] | undefined

function parseJsonObject(source?: string): Record<string, AIUserExtensionValue> {
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

export function isPinDefaultAIUser(aiUser?: V2NIMAIUser): boolean {
  const extension = parseJsonObject(aiUser?.serverExtension)
  const pinDefault = extension[AI_USER_PIN_DEFAULT_KEY]
  return pinDefault === 1 || pinDefault === '1'
}

export function canShowAIUserPinSwitch(aiUser?: V2NIMAIUser): boolean {
  return isPinDefaultAIUser(aiUser)
}

export function getUnpinAIUserList(mineServerExtension?: string): string[] {
  const extension = parseJsonObject(mineServerExtension)
  const unpinAIUsers = extension[MINE_UNPIN_AI_USERS_KEY]
  if (!Array.isArray(unpinAIUsers)) {
    return []
  }

  const result: string[] = []
  unpinAIUsers.forEach((item: string) => {
    if (typeof item === 'string' && item.length > 0) {
      result.push(item)
    }
  })
  return result
}

export function isAIUserPinnedByMine(accountId: string, mineServerExtension?: string): boolean {
  return !getUnpinAIUserList(mineServerExtension).includes(accountId)
}

export function buildMineServerExtensionWithAIUserPin(mineServerExtension: string | undefined, accountId: string,
  pinned: boolean): string {
  const extension = parseJsonObject(mineServerExtension)
  const oldUnpinAIUsers = getUnpinAIUserList(mineServerExtension)
  const nextUnpinAIUsers: string[] = []

  oldUnpinAIUsers.forEach((unpinAccountId: string) => {
    if (unpinAccountId !== accountId && !nextUnpinAIUsers.includes(unpinAccountId)) {
      nextUnpinAIUsers.push(unpinAccountId)
    }
  })

  if (!pinned && accountId.length > 0 && !nextUnpinAIUsers.includes(accountId)) {
    nextUnpinAIUsers.push(accountId)
  }

  extension[MINE_UNPIN_AI_USERS_KEY] = nextUnpinAIUsers
  return JSON.stringify(extension)
}

export function filterPinnedAIUsers(aiUsers: V2NIMAIUser[], mineServerExtension?: string): V2NIMAIUser[] {
  const unpinAIUsers = getUnpinAIUserList(mineServerExtension)
  return aiUsers.filter((aiUser: V2NIMAIUser) => {
    return isPinDefaultAIUser(aiUser) && !unpinAIUsers.includes(aiUser.accountId)
  })
}
