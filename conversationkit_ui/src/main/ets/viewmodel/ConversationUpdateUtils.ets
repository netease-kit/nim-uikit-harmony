/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMConversationType } from '@nimsdk/base'

export interface ConversationIdRef {
  conversationId: string
}

export interface ConversationDisplayRef extends ConversationIdRef {
  type: V2NIMConversationType
  name?: string
  avatar?: string
}

export interface ConversationDisplayInfo {
  name?: string
  avatar?: string
}

export interface ConversationDisplayResolveOptions {
  replaceName?: boolean
  replaceAvatar?: boolean
}

export interface ConversationBatchMergeResult<T extends ConversationIdRef> {
  conversations: T[]
  changed: boolean
}

function getNonEmptyText(first?: string, second?: string): string | undefined {
  if (first !== undefined && first.length > 0) {
    return first
  }
  if (second !== undefined && second.length > 0) {
    return second
  }
  return undefined
}

function getDefinedText(first?: string, second?: string): string | undefined {
  if (first !== undefined) {
    return first
  }
  if (second !== undefined) {
    return second
  }
  return undefined
}

function isEmptyText(value?: string): boolean {
  return value === undefined || value.length <= 0
}

export function resolveConversationDisplayInfo<T extends ConversationDisplayRef>(
  conversation: T,
  targetId: string,
  primaryInfo?: ConversationDisplayInfo,
  secondaryInfo?: ConversationDisplayInfo,
  options?: ConversationDisplayResolveOptions
): T {
  if (conversation.type !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P || targetId.length <= 0) {
    return conversation
  }

  const replaceAvatar = options?.replaceAvatar === true
  const avatar = replaceAvatar ? getDefinedText(primaryInfo?.avatar, secondaryInfo?.avatar) :
  getNonEmptyText(primaryInfo?.avatar, secondaryInfo?.avatar)
  if (avatar !== undefined) {
    conversation.avatar = avatar
  }

  const name = getNonEmptyText(primaryInfo?.name, secondaryInfo?.name)
  if (name !== undefined &&
    (options?.replaceName === true || isEmptyText(conversation.name) || conversation.name === targetId)) {
    conversation.name = name
  }

  return conversation
}

export function collectP2PConversationTargetIds<T extends ConversationDisplayRef>(
  conversations: T[],
  parseConversationTargetId: (conversationId: string) => string
): string[] {
  const accountIdSet: Set<string> = new Set()
  conversations.forEach((conversation: T) => {
    if (conversation.type !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      return
    }
    const targetId = parseConversationTargetId(conversation.conversationId)
    if (targetId.length > 0) {
      accountIdSet.add(targetId)
    }
  })

  const accountIds: string[] = []
  accountIdSet.forEach((accountId: string) => {
    accountIds.push(accountId)
  })
  return accountIds
}

export function applyP2PUserProfileDisplayInfo<T extends ConversationDisplayRef>(
  conversation: T,
  targetId: string,
  userInfo?: ConversationDisplayInfo
): T {
  if (conversation.type !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P || targetId.length <= 0) {
    return conversation
  }

  if (userInfo?.avatar !== undefined && userInfo.avatar.length > 0) {
    conversation.avatar = userInfo.avatar
  }
  if (userInfo?.name !== undefined && userInfo.name.length > 0) {
    conversation.name = userInfo.name
  }

  return conversation
}

export function mergeInitialConversations<T extends ConversationIdRef>(
  initialConversations: T[],
  pendingUpserts: T[],
  pendingDeletes: Set<string>,
  sorter: (a: T, b: T) => number
): T[] {
  const mergedConversationMap: Map<string, T> = new Map()
  initialConversations.forEach((conversation: T) => {
    if (!pendingDeletes.has(conversation.conversationId)) {
      mergedConversationMap.set(conversation.conversationId, conversation)
    }
  })
  pendingUpserts.forEach((conversation: T) => {
    if (!pendingDeletes.has(conversation.conversationId)) {
      mergedConversationMap.set(conversation.conversationId, conversation)
    }
  })

  const mergedConversations: T[] = []
  mergedConversationMap.forEach((conversation: T) => {
    mergedConversations.push(conversation)
  })
  mergedConversations.sort(sorter)
  return mergedConversations
}

export function mergeConversationBatch<T extends ConversationIdRef>(
  loadedConversations: T[],
  upsertConversations: T[],
  deletedConversationIds: Set<string>,
  sorter: (a: T, b: T) => number
): ConversationBatchMergeResult<T> {
  if (upsertConversations.length <= 0 && deletedConversationIds.size <= 0) {
    return {
      conversations: loadedConversations,
      changed: false
    }
  }

  let changed = upsertConversations.length > 0
  const mergedConversationMap: Map<string, T> = new Map()
  loadedConversations.forEach((conversation: T) => {
    if (deletedConversationIds.has(conversation.conversationId)) {
      changed = true
      return
    }
    mergedConversationMap.set(conversation.conversationId, conversation)
  })
  upsertConversations.forEach((conversation: T) => {
    if (!deletedConversationIds.has(conversation.conversationId)) {
      mergedConversationMap.set(conversation.conversationId, conversation)
    }
  })

  const mergedConversations: T[] = []
  mergedConversationMap.forEach((conversation: T) => {
    mergedConversations.push(conversation)
  })
  mergedConversations.sort(sorter)
  return {
    conversations: mergedConversations,
    changed: changed
  }
}

export function resolveDeferredBatchDelay(
  pendingCount: number,
  batchSize: number,
  baseDelayMs: number,
  maxDelayMs: number
): number {
  if (pendingCount <= 0) {
    return 0
  }
  if (batchSize <= 0 || baseDelayMs <= 0) {
    return baseDelayMs
  }
  const batchIndex = Math.ceil(pendingCount / (batchSize * 2))
  const delay = batchIndex * baseDelayMs
  return Math.min(delay, maxDelayMs)
}

export function filterLoadedConversationIds(
  loadedConversations: ConversationIdRef[],
  conversationIds: string[]
): string[] {
  const loadedConversationIds: Set<string> = new Set()
  loadedConversations.forEach((conversation: ConversationIdRef) => {
    if (conversation.conversationId.length > 0) {
      loadedConversationIds.add(conversation.conversationId)
    }
  })

  const filteredConversationIds: string[] = []
  const emittedConversationIds: Set<string> = new Set()
  conversationIds.forEach((conversationId: string) => {
    if (loadedConversationIds.has(conversationId) && !emittedConversationIds.has(conversationId)) {
      emittedConversationIds.add(conversationId)
      filteredConversationIds.push(conversationId)
    }
  })
  return filteredConversationIds
}

export function hasLoadedConversationId(
  loadedConversations: ConversationIdRef[],
  conversationId: string
): boolean {
  if (conversationId.length <= 0) {
    return false
  }
  const index = loadedConversations.findIndex((conversation: ConversationIdRef) =>
  conversation.conversationId === conversationId)
  return index > -1
}

export function collectPendingSubscriptionAccounts(pendingAccounts: Set<string>): string[] {
  const accountIds: string[] = []
  pendingAccounts.forEach((accountId: string) => {
    if (accountId.length > 0) {
      accountIds.push(accountId)
    }
  })
  pendingAccounts.clear()
  return accountIds
}
