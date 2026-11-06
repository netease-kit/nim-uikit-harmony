/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { ConversationOpenIntent, ConversationOpenSource, ConversationRouteKind } from '@nimkit/conversationkit_ui'

export const ADAPTIVE_EMPTY_DETAIL_ROUTE: string = 'AdaptiveEmptyDetailPage'
export const ADAPTIVE_EMPTY_DETAIL_CONVERSATION: string = 'conversation'
export const ADAPTIVE_EMPTY_DETAIL_CONTACT: string = 'contact'
export const ADAPTIVE_EMPTY_DETAIL_MINE: string = 'mine'

export function resolveAdaptiveDetailPlaceholderTarget(tabIndex: number): string {
  if (tabIndex === 1) {
    return ADAPTIVE_EMPTY_DETAIL_CONTACT
  }
  if (tabIndex === 2) {
    return ADAPTIVE_EMPTY_DETAIL_MINE
  }
  return ADAPTIVE_EMPTY_DETAIL_CONVERSATION
}

export enum ConversationNavigationAction {
  REJECT = 'reject',
  NO_OP = 'noOp',
  PUSH_CHAT_ROOT = 'pushChatRoot',
  POP_TO_CHAT_ROOT = 'popToChatRoot',
  REPLACE_CHAT_ROOT = 'replaceChatRoot'
}

export class ConversationNavigationState {
  activeKey: string
  chatRootName: string
  hasExtensionRoute: boolean
  selectedConversationId: string

  constructor(activeKey: string = '', chatRootName: string = '', hasExtensionRoute: boolean = false,
    selectedConversationId: string = '') {
    this.activeKey = activeKey
    this.chatRootName = chatRootName
    this.hasExtensionRoute = hasExtensionRoute
    this.selectedConversationId = selectedConversationId
  }
}

export function shouldResetAdaptiveDetailForConversationOpen(isSplitMode: boolean,
  state: ConversationNavigationState, source: ConversationOpenSource): boolean {
  // 来源详情页需要保留在返回栈中，其他入口首次打开时初始化分屏详情槽。
  if (!isSplitMode || source === ConversationOpenSource.CONTACT || source === ConversationOpenSource.SEARCH ||
    source === ConversationOpenSource.AI_ENTRY) {
    return false
  }
  return state.activeKey.length === 0
}

/**
 * 从好友名片进入聊天时替换掉这一层，模拟 10.9.60 的 replacePath 语义：
 * 好友名片 → 聊天 → 返回直接回到通讯录，而不是回到名片页（OMIM-73499 验收要求）。
 * 数字人名片从聊天返回必须回名片（73571）、群名片从聊天返回必须回名片（73519），
 * 两者的"退群/群失效回会话列表"分别由壳层与 kit 各自的清理链路负责，因此都不在此列。
 */
export const PERSON_CARD_ROUTE_NAMES: string[] = ['PersonInfoPage']

export function shouldReplacePersonCardForConversationOpen(pathNames: string[]): boolean {
  if (pathNames.length === 0) {
    return false
  }
  return PERSON_CARD_ROUTE_NAMES.includes(pathNames[pathNames.length - 1])
}

export function resolveConversationOpenTabIndex(currentIndex: number, source: ConversationOpenSource): number {
  if (source === ConversationOpenSource.CONTACT || source === ConversationOpenSource.SEARCH ||
    source === ConversationOpenSource.AI_ENTRY) {
    return currentIndex
  }
  return 0
}

export class ConversationNavigationDecision {
  action: ConversationNavigationAction
  state: ConversationNavigationState

  constructor(action: ConversationNavigationAction, state: ConversationNavigationState) {
    this.action = action
    this.state = state
  }
}

export abstract class ConversationNavigationStack {
  abstract getAllPathName(): string[]
  abstract pushPath(info: NavPathInfo, animated?: boolean): void
  abstract popToName(name: string, animated?: boolean): void
  abstract removeByIndexes(indexes: number[]): void
  abstract moveIndexToTop(index: number, animated?: boolean): void
  abstract clear(animated?: boolean): void
}

export class NavPathStackConversationAdapter extends ConversationNavigationStack {
  private readonly stack: NavPathStack

  constructor(stack: NavPathStack) {
    super()
    this.stack = stack
  }

  getAllPathName(): string[] {
    return this.stack.getAllPathName()
  }

  pushPath(info: NavPathInfo, animated: boolean = true): void {
    this.stack.pushPath(info, animated)
  }

  popToName(name: string, animated: boolean = true): void {
    this.stack.popToName(name, animated)
  }

  removeByIndexes(indexes: number[]): void {
    this.stack.removeByIndexes(indexes)
  }

  moveIndexToTop(index: number, animated: boolean = true): void {
    this.stack.moveIndexToTop(index, animated)
  }

  clear(animated: boolean = true): void {
    this.stack.clear(animated)
  }
}

export function reduceConversationNavigation(state: ConversationNavigationState,
  intent: ConversationOpenIntent): ConversationNavigationDecision {
  if (!intent.isValid()) {
    return new ConversationNavigationDecision(ConversationNavigationAction.REJECT, copyState(state))
  }

  const targetKey = intent.key.toStableKey()
  const targetRootName = resolveChatRootName(intent.key.routeKind)
  if (targetRootName.length === 0) {
    return new ConversationNavigationDecision(ConversationNavigationAction.REJECT, copyState(state))
  }

  if (state.activeKey === targetKey) {
    if (state.hasExtensionRoute) {
      return new ConversationNavigationDecision(
        ConversationNavigationAction.POP_TO_CHAT_ROOT,
        new ConversationNavigationState(targetKey, targetRootName, false, intent.key.conversationId)
      )
    }
    return new ConversationNavigationDecision(ConversationNavigationAction.NO_OP, copyState(state))
  }

  const nextState = new ConversationNavigationState(targetKey, targetRootName, false, intent.key.conversationId)
  if (state.activeKey.length === 0) {
    return new ConversationNavigationDecision(ConversationNavigationAction.PUSH_CHAT_ROOT, nextState)
  }
  return new ConversationNavigationDecision(ConversationNavigationAction.REPLACE_CHAT_ROOT, nextState)
}

export function resolveChatRootName(routeKind: ConversationRouteKind): string {
  if (routeKind === ConversationRouteKind.P2P) {
    return 'ChatP2PPage'
  }
  if (routeKind === ConversationRouteKind.TEAM || routeKind === ConversationRouteKind.SUPER_TEAM) {
    return 'ChatTeamPage'
  }
  if (routeKind === ConversationRouteKind.BOT_SUB_SESSION_LIST) {
    return 'ChatBotSubSessionListPage'
  }
  if (routeKind === ConversationRouteKind.BOT_SUB_SESSION) {
    return 'ChatBotSubSessionPage'
  }
  return ''
}

export function executeConversationNavigation(stack: ConversationNavigationStack,
  state: ConversationNavigationState, intent: ConversationOpenIntent,
  animated: boolean = true, onChatRootPop?: () => void): ConversationNavigationState {
  const decision = reduceConversationNavigation(synchronizeStateWithStack(state, stack.getAllPathName()), intent)
  if (decision.action === ConversationNavigationAction.PUSH_CHAT_ROOT) {
    stack.pushPath(buildChatRootPath(intent, decision.state.chatRootName, onChatRootPop), animated)
  } else if (decision.action === ConversationNavigationAction.POP_TO_CHAT_ROOT) {
    stack.popToName(decision.state.chatRootName, animated)
  } else if (decision.action === ConversationNavigationAction.REPLACE_CHAT_ROOT) {
    removeChatSubtree(stack)
    stack.pushPath(buildChatRootPath(intent, decision.state.chatRootName, onChatRootPop), animated)
  }
  return decision.state
}

export function openPrimaryDetail(stack: ConversationNavigationStack, info: NavPathInfo,
  isSplitMode: boolean, placeholderTarget: string = ADAPTIVE_EMPTY_DETAIL_CONVERSATION): void {
  if (isSplitMode) {
    stack.clear(false)
    stack.pushPath({ name: ADAPTIVE_EMPTY_DETAIL_ROUTE, param: placeholderTarget }, false)
    stack.pushPath(info, false)
    return
  }
  stack.pushPath(info, true)
}

export function ensureAdaptiveDetailPlaceholder(stack: ConversationNavigationStack, isSplitMode: boolean,
  placeholderTarget: string = ADAPTIVE_EMPTY_DETAIL_CONVERSATION): void {
  const pathNames = stack.getAllPathName()
  const placeholderIndex = pathNames.indexOf(ADAPTIVE_EMPTY_DETAIL_ROUTE)
  if (isSplitMode) {
    if (placeholderIndex < 0) {
      stack.pushPath({ name: ADAPTIVE_EMPTY_DETAIL_ROUTE, param: placeholderTarget }, false)
      for (let index = 0; index < pathNames.length; index++) {
        stack.moveIndexToTop(0, false)
      }
    }
    return
  }
  if (placeholderIndex >= 0) {
    stack.removeByIndexes([placeholderIndex])
  }
}

export function resetAdaptiveDetail(stack: ConversationNavigationStack, isSplitMode: boolean,
  placeholderTarget: string = ADAPTIVE_EMPTY_DETAIL_CONVERSATION): void {
  stack.clear(false)
  ensureAdaptiveDetailPlaceholder(stack, isSplitMode, placeholderTarget)
}

export function resolveSelectedConversationId(state: ConversationNavigationState, isSplitMode: boolean,
  pathNames: string[]): string {
  if (!isSplitMode || state.chatRootName.length === 0 || !pathNames.includes(state.chatRootName)) {
    return ''
  }
  return state.selectedConversationId
}

export function synchronizeStateWithStack(state: ConversationNavigationState,
  pathNames: string[]): ConversationNavigationState {
  if (state.activeKey.length === 0 || state.chatRootName.length === 0) {
    return copyState(state)
  }
  const rootIndex = pathNames.lastIndexOf(state.chatRootName)
  if (rootIndex < 0) {
    return new ConversationNavigationState()
  }
  return new ConversationNavigationState(
    state.activeKey,
    state.chatRootName,
    rootIndex < pathNames.length - 1,
    state.selectedConversationId
  )
}

export function reconcileConversationNavigationState(stack: ConversationNavigationStack,
  state: ConversationNavigationState): ConversationNavigationState {
  return synchronizeStateWithStack(state, stack.getAllPathName())
}

export function clearConversationNavigation(stack: ConversationNavigationStack): ConversationNavigationState {
  removeChatSubtree(stack)
  return new ConversationNavigationState()
}

function buildChatRootPath(intent: ConversationOpenIntent, rootName: string,
  onChatRootPop?: () => void): NavPathInfo {
  const onPop = onChatRootPop ? (popInfo: PopInfo): void => {
    onChatRootPop()
  } : undefined
  if (intent.key.routeKind === ConversationRouteKind.BOT_SUB_SESSION_LIST) {
    return {
      name: rootName,
      param: [intent.key.conversationId, intent.targetId, intent.displayName],
      onPop: onPop
    }
  }
  if (intent.key.routeKind === ConversationRouteKind.BOT_SUB_SESSION) {
    return {
      name: rootName,
      param: [intent.key.conversationId, intent.key.subSessionId, intent.targetId, intent.displayName],
      onPop: onPop
    }
  }
  return { name: rootName, param: intent.key.conversationId, onPop: onPop }
}

function removeChatSubtree(stack: ConversationNavigationStack): void {
  const pathNames = stack.getAllPathName()
  let firstChatRootIndex = -1
  for (let index = 0; index < pathNames.length; index++) {
    if (isChatRoot(pathNames[index])) {
      firstChatRootIndex = index
      break
    }
  }
  if (firstChatRootIndex < 0) {
    return
  }
  const indexes: number[] = []
  for (let index = firstChatRootIndex; index < pathNames.length; index++) {
    indexes.push(index)
  }
  stack.removeByIndexes(indexes)
}

function isChatRoot(name: string): boolean {
  return name === 'ChatP2PPage' || name === 'ChatTeamPage' ||
    name === 'ChatBotSubSessionListPage' || name === 'ChatBotSubSessionPage'
}

function copyState(state: ConversationNavigationState): ConversationNavigationState {
  return new ConversationNavigationState(
    state.activeKey,
    state.chatRootName,
    state.hasExtensionRoute,
    state.selectedConversationId
  )
}
