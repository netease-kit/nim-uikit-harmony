/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  CONVERSATION_GROUP_DEFAULT_AIT_KEY,
  CONVERSATION_GROUP_DEFAULT_ALL_KEY,
  CONVERSATION_GROUP_DEFAULT_UNREAD_KEY,
  ConversationGroupDisplayConfig
} from '@nimkit/chatkit'
import {
  V2NIMConversation,
  V2NIMConversationFilter,
  V2NIMConversationGroup,
  V2NIMError,
  V2NIMErrorMap
} from '@nimsdk/base'
import { ConversationItem } from '../strategy/ConversationStrategy'

export const CONVERSATION_GROUP_NAME_MAX_LENGTH: number = 20
export const CONVERSATION_GROUP_SELECT_CONVERSATION_LIMIT: number = 100
const CONVERSATION_GROUP_LIMIT_ERROR_CODE: number =
  V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_GROUP_LIMIT.code
const CONVERSATION_GROUP_NOT_EXIST_ERROR_CODE: number =
  V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_GROUP_NOT_EXIST.code
const CONVERSATION_BELONGED_GROUP_LIMIT_ERROR_CODE: number =
  V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_BELONGED_GROUP_LIMIT.code
const CONVERSATION_NOT_EXIST_ERROR_CODE: number =
  V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_NOT_EXIST.code
const CONVERSATIONS_IN_GROUP_LIMIT_ERROR_CODE: number =
  V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATIONS_IN_GROUP_LIMIT.code

export enum ConversationGroupKind {
  ALL = 'all',
  AIT = 'ait',
  UNREAD = 'unread',
  CUSTOM = 'custom'
}

export enum ConversationGroupOperationFailureKind {
  GROUP_NOT_EXIST = 'group_not_exist',
  BELONGED_GROUP_LIMIT = 'belonged_group_limit',
  CONVERSATIONS_IN_GROUP_LIMIT = 'conversations_in_group_limit',
  CONVERSATION_NOT_EXIST = 'conversation_not_exist',
  UNKNOWN = 'unknown'
}

export class ConversationGroupDefaultCounts {
  allUnreadCount: number
  aitCount: number
  unreadCount: number

  constructor(allUnreadCount: number = 0, aitCount: number = 0, unreadCount: number = 0) {
    this.allUnreadCount = allUnreadCount
    this.aitCount = aitCount
    this.unreadCount = unreadCount
  }
}

export class ConversationGroupDefaultNames {
  allName: string
  aitName: string
  unreadName: string

  constructor(allName: string, aitName: string, unreadName: string) {
    this.allName = allName
    this.aitName = aitName
    this.unreadName = unreadName
  }
}

export class ConversationGroupInfo {
  groupKey: string
  groupId: string
  name: string
  kind: ConversationGroupKind
  unreadCount: number
  canHide: boolean
  canSetting: boolean
  canDelete: boolean

  constructor(groupKey: string, groupId: string, name: string, kind: ConversationGroupKind,
    unreadCount: number = 0, canHide: boolean = true, canSetting: boolean = false,
    canDelete: boolean = false) {
    this.groupKey = groupKey
    this.groupId = groupId
    this.name = name
    this.kind = kind
    this.unreadCount = unreadCount
    this.canHide = canHide
    this.canSetting = canSetting
    this.canDelete = canDelete
  }
}

export class ConversationGroupInfoListResult {
  visibleGroups: ConversationGroupInfo[]
  hiddenGroups: ConversationGroupInfo[]

  constructor(visibleGroups: ConversationGroupInfo[], hiddenGroups: ConversationGroupInfo[]) {
    this.visibleGroups = visibleGroups
    this.hiddenGroups = hiddenGroups
  }
}

export class ConversationSelectionResult {
  selectedIds: string[]
  reachedLimit: boolean

  constructor(selectedIds: string[], reachedLimit: boolean = false) {
    this.selectedIds = selectedIds
    this.reachedLimit = reachedLimit
  }
}

export function isDefaultConversationGroupKey(groupKey: string): boolean {
  return groupKey === CONVERSATION_GROUP_DEFAULT_ALL_KEY ||
    groupKey === CONVERSATION_GROUP_DEFAULT_AIT_KEY ||
    groupKey === CONVERSATION_GROUP_DEFAULT_UNREAD_KEY
}

export function isCustomConversationGroupKey(groupKey: string): boolean {
  return !isDefaultConversationGroupKey(groupKey)
}

export function createDefaultConversationGroupInfo(groupKey: string,
  counts: ConversationGroupDefaultCounts, names: ConversationGroupDefaultNames): ConversationGroupInfo {
  if (groupKey === CONVERSATION_GROUP_DEFAULT_AIT_KEY) {
    return new ConversationGroupInfo(groupKey, '', names.aitName, ConversationGroupKind.AIT, counts.aitCount, true,
      false, false)
  }
  if (groupKey === CONVERSATION_GROUP_DEFAULT_UNREAD_KEY) {
    return new ConversationGroupInfo(groupKey, '', names.unreadName, ConversationGroupKind.UNREAD, counts.unreadCount,
      true, false, false)
  }
  return new ConversationGroupInfo(CONVERSATION_GROUP_DEFAULT_ALL_KEY, '', names.allName, ConversationGroupKind.ALL,
    counts.allUnreadCount, false, false, false)
}

export function createCustomConversationGroupInfo(group: V2NIMConversationGroup,
  unreadCount: number = 0): ConversationGroupInfo {
  return new ConversationGroupInfo(group.groupId, group.groupId, group.name, ConversationGroupKind.CUSTOM,
    unreadCount, true, true, true)
}

export function createInitialConversationGroupInfos(counts: ConversationGroupDefaultCounts,
  names: ConversationGroupDefaultNames): ConversationGroupInfo[] {
  return [createDefaultConversationGroupInfo(CONVERSATION_GROUP_DEFAULT_ALL_KEY, counts, names)]
}

export function createDefaultUnreadConversationFilter(): V2NIMConversationFilter {
  return {
    ignoreMuted: true
  }
}

export function isDefaultUnreadConversationFilter(filter: V2NIMConversationFilter): boolean {
  const hasConversationGroupId = (filter.conversationGroupId ?? '').length > 0
  const hasConversationTypes = (filter.conversationTypes?.length ?? 0) > 0
  return filter.ignoreMuted === true && !hasConversationGroupId && !hasConversationTypes
}

export function isConversationGroupLimitError(error?: V2NIMError): boolean {
  return error?.code === CONVERSATION_GROUP_LIMIT_ERROR_CODE
}

export function isConversationGroupNotExistError(error?: V2NIMError): boolean {
  return error?.code === CONVERSATION_GROUP_NOT_EXIST_ERROR_CODE
}

export function isConversationBelongedGroupLimitError(error?: V2NIMError): boolean {
  return error?.code === CONVERSATION_BELONGED_GROUP_LIMIT_ERROR_CODE
}

export function isConversationNotExistError(error?: V2NIMError): boolean {
  return error?.code === CONVERSATION_NOT_EXIST_ERROR_CODE
}

export function isConversationsInGroupLimitError(error?: V2NIMError): boolean {
  return error?.code === CONVERSATIONS_IN_GROUP_LIMIT_ERROR_CODE
}

export function resolveConversationGroupOperationFailureKind(errors: V2NIMError[]):
  ConversationGroupOperationFailureKind {
  if (errors.some((error: V2NIMError): boolean => isConversationGroupNotExistError(error))) {
    return ConversationGroupOperationFailureKind.GROUP_NOT_EXIST
  }
  if (errors.some((error: V2NIMError): boolean => isConversationBelongedGroupLimitError(error))) {
    return ConversationGroupOperationFailureKind.BELONGED_GROUP_LIMIT
  }
  if (errors.some((error: V2NIMError): boolean => isConversationsInGroupLimitError(error))) {
    return ConversationGroupOperationFailureKind.CONVERSATIONS_IN_GROUP_LIMIT
  }
  if (errors.some((error: V2NIMError): boolean => isConversationNotExistError(error))) {
    return ConversationGroupOperationFailureKind.CONVERSATION_NOT_EXIST
  }
  return ConversationGroupOperationFailureKind.UNKNOWN
}

export function buildConversationGroupInfoLists(config: ConversationGroupDisplayConfig,
  cloudGroups: V2NIMConversationGroup[], customUnreadCountMap: Map<string, number>,
  counts: ConversationGroupDefaultCounts, names: ConversationGroupDefaultNames): ConversationGroupInfoListResult {
  const groupMap: Map<string, V2NIMConversationGroup> = new Map()
  cloudGroups.forEach((group: V2NIMConversationGroup) => {
    groupMap.set(group.groupId, group)
  })
  const visibleGroups: ConversationGroupInfo[] = []
  const hiddenGroups: ConversationGroupInfo[] = []
  appendConversationGroupInfos(visibleGroups, config.visibleGroupKeys, groupMap, customUnreadCountMap, counts, names)
  appendConversationGroupInfos(hiddenGroups, config.hiddenGroupKeys, groupMap, customUnreadCountMap, counts, names)
  return new ConversationGroupInfoListResult(visibleGroups, hiddenGroups)
}

export function appendConversationGroupInfos(target: ConversationGroupInfo[], groupKeys: string[],
  groupMap: Map<string, V2NIMConversationGroup>, customUnreadCountMap: Map<string, number>,
  counts: ConversationGroupDefaultCounts, names: ConversationGroupDefaultNames): void {
  groupKeys.forEach((groupKey: string) => {
    if (isDefaultConversationGroupKey(groupKey)) {
      target.push(createDefaultConversationGroupInfo(groupKey, counts, names))
      return
    }
    const group = groupMap.get(groupKey)
    if (group !== undefined) {
      target.push(createCustomConversationGroupInfo(group, customUnreadCountMap.get(groupKey) ?? 0))
    }
  })
}

export function isConversationAitBadgeVisible(conversation: ConversationItem,
  aitConversationIds: Set<string>): boolean {
  return aitConversationIds.has(conversation.conversationId) && conversation.unreadCount > 0
}

export function filterConversationsByDefaultGroup(conversations: ConversationItem[], groupKey: string,
  aitConversationIds: Set<string>): ConversationItem[] {
  if (groupKey === CONVERSATION_GROUP_DEFAULT_AIT_KEY) {
    return conversations.filter((conversation: ConversationItem): boolean =>
    isConversationAitBadgeVisible(conversation, aitConversationIds))
  }
  if (groupKey === CONVERSATION_GROUP_DEFAULT_UNREAD_KEY) {
    return conversations.filter((conversation: ConversationItem): boolean =>
    conversation.unreadCount > 0 && conversation.mute !== true)
  }
  return conversations.slice()
}

export function filterAddConversationCandidates(conversations: V2NIMConversation[],
  currentGroupConversationIds: Set<string>): V2NIMConversation[] {
  return conversations.filter((conversation: V2NIMConversation): boolean =>
  !currentGroupConversationIds.has(conversation.conversationId))
}

export function filterAddConversationCandidatesForGroup(conversations: V2NIMConversation[],
  currentGroupConversationIds: Set<string>, groupId: string): V2NIMConversation[] {
  return conversations.filter((conversation: V2NIMConversation): boolean =>
  !currentGroupConversationIds.has(conversation.conversationId) &&
    !(conversation.groupIds?.includes(groupId) ?? false))
}

export function pickConversationsByIds(conversations: V2NIMConversation[],
  conversationIds: string[]): V2NIMConversation[] {
  const conversationMap: Map<string, V2NIMConversation> = new Map()
  conversations.forEach((conversation: V2NIMConversation) => {
    conversationMap.set(conversation.conversationId, conversation)
  })
  const result: V2NIMConversation[] = []
  conversationIds.forEach((conversationId: string) => {
    const conversation = conversationMap.get(conversationId)
    if (conversation !== undefined) {
      result.push(conversation)
    }
  })
  return result
}

export function mergeConversationGroupMemberConversations(source: V2NIMConversation[],
  incoming: V2NIMConversation[]): V2NIMConversation[] {
  const result = source.slice()
  const conversationIndexMap: Map<string, number> = new Map()
  result.forEach((conversation: V2NIMConversation, index: number) => {
    conversationIndexMap.set(conversation.conversationId, index)
  })
  incoming.forEach((conversation: V2NIMConversation) => {
    const index = conversationIndexMap.get(conversation.conversationId)
    if (index !== undefined) {
      result.splice(index, 1, conversation)
      return
    }
    conversationIndexMap.set(conversation.conversationId, result.length)
    result.push(conversation)
  })
  return result.sort((a: V2NIMConversation, b: V2NIMConversation): number =>
  (b.sortOrder ?? 0) - (a.sortOrder ?? 0))
}

export function buildConversationGroupSuccessNameList(conversations: V2NIMConversation[],
  separator: string, overflowSuffix: string, maxNameCount: number = 10): string {
  const names = conversations.slice(0, maxNameCount)
    .map((conversation: V2NIMConversation): string => conversation.name ?? conversation.conversationId)
    .filter((name: string): boolean => name.length > 0)
  const suffix = conversations.length > maxNameCount ? overflowSuffix : ''
  return `${names.join(separator)}${suffix}`
}

export function filterConversationsByKeyword(conversations: V2NIMConversation[],
  keyword: string): V2NIMConversation[] {
  const trimmedKeyword = keyword.trim().toLowerCase()
  if (trimmedKeyword.length <= 0) {
    return conversations.slice()
  }
  return conversations.filter((conversation: V2NIMConversation): boolean => {
    const name = (conversation.name ?? '').toLowerCase()
    return name.includes(trimmedKeyword)
  })
}

export function toggleConversationSelection(selectedIds: string[], conversationId: string,
  limit: number = CONVERSATION_GROUP_SELECT_CONVERSATION_LIMIT): ConversationSelectionResult {
  if (conversationId.length <= 0) {
    return new ConversationSelectionResult(selectedIds.slice(), false)
  }
  const nextSelectedIds = selectedIds.slice()
  const index = nextSelectedIds.indexOf(conversationId)
  if (index >= 0) {
    nextSelectedIds.splice(index, 1)
    return new ConversationSelectionResult(nextSelectedIds, false)
  }
  if (nextSelectedIds.length >= limit) {
    return new ConversationSelectionResult(nextSelectedIds, true)
  }
  nextSelectedIds.push(conversationId)
  return new ConversationSelectionResult(nextSelectedIds, false)
}

export function moveConversationGroupKeysByIndex(groupKeys: string[], from: number, to: number): string[] {
  if (from < 0 || to < 0 || from >= groupKeys.length || to >= groupKeys.length || from === to) {
    return groupKeys.slice()
  }
  const nextGroupKeys = groupKeys.slice()
  const movedGroupKeys = nextGroupKeys.splice(from, 1)
  if (movedGroupKeys.length <= 0) {
    return groupKeys.slice()
  }
  nextGroupKeys.splice(to, 0, movedGroupKeys[0])
  return nextGroupKeys
}

export function normalizeConversationGroupName(name: string): string {
  return name.trim().substring(0, CONVERSATION_GROUP_NAME_MAX_LENGTH)
}
