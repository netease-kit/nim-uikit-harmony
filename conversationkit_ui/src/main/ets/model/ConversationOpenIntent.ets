/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

export enum ConversationRouteKind {
  P2P = 'p2p',
  TEAM = 'team',
  SUPER_TEAM = 'superTeam',
  BOT_SUB_SESSION_LIST = 'botSubSessionList',
  BOT_SUB_SESSION = 'botSubSession'
}

export enum ConversationOpenSource {
  CONVERSATION_LIST = 'conversationList',
  CONTACT = 'contact',
  SEARCH = 'search',
  NOTIFICATION = 'notification',
  AI_ENTRY = 'aiEntry',
  BOT_SUB_SESSION = 'botSubSession'
}

export class ConversationRouteKey {
  routeKind: ConversationRouteKind
  conversationId: string
  subSessionId: string

  constructor(routeKind: ConversationRouteKind, conversationId: string, subSessionId: string = '') {
    this.routeKind = routeKind
    this.conversationId = conversationId
    this.subSessionId = subSessionId
  }

  toStableKey(): string {
    return `${this.routeKind}|${this.escapePart(this.conversationId)}|${this.escapePart(this.subSessionId)}`
  }

  private escapePart(value: string): string {
    return encodeURIComponent(value)
  }
}

export class ConversationOpenIntent {
  key: ConversationRouteKey
  source: ConversationOpenSource
  targetId: string
  displayName: string

  constructor(key: ConversationRouteKey, source: ConversationOpenSource, targetId: string = '',
    displayName: string = '') {
    this.key = key
    this.source = source
    this.targetId = targetId
    this.displayName = displayName
  }

  isValid(): boolean {
    return this.key.conversationId.trim().length > 0
  }
}

export type ConversationOpenHandler = (intent: ConversationOpenIntent) => void

export class ConversationOpenRegistry {
  private handler?: ConversationOpenHandler = undefined

  setHandler(handler: ConversationOpenHandler): void {
    this.handler = handler
  }

  clearHandler(handler?: ConversationOpenHandler): void {
    if (!handler || this.handler === handler) {
      this.handler = undefined
    }
  }

  open(intent: ConversationOpenIntent): boolean {
    if (!this.handler || !intent.isValid()) {
      return false
    }
    this.handler(intent)
    return true
  }
}

export const conversationOpenRegistry: ConversationOpenRegistry = new ConversationOpenRegistry()
