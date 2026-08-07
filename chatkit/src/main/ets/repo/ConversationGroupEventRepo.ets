/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMConversation,
  V2NIMConversationFilter,
  V2NIMConversationGroup
} from '@nimsdk/base'
import { ChatKitClient } from '../ChatKitClient'
import { EventDisposer } from '../utils/DisposableBag'
import { createEventListenerHandle } from '../utils/EventListenerHandle'

export type ConversationGroupEventDisposer = EventDisposer

export class ConversationGroupEventRepo {
  static onConversationGroupCreated(
    callback: (conversationGroup: V2NIMConversationGroup) => void
  ): ConversationGroupEventDisposer {
    const service = ChatKitClient.nim.conversationGroupService
    return createEventListenerHandle((listener: (conversationGroup: V2NIMConversationGroup) => void): void => {
      service?.on('onConversationGroupCreated', listener)
    }, (listener: (conversationGroup: V2NIMConversationGroup) => void): void => {
      service?.off('onConversationGroupCreated', listener)
    }, callback)
  }

  static onConversationGroupDeleted(callback: (groupId: string) => void): ConversationGroupEventDisposer {
    const service = ChatKitClient.nim.conversationGroupService
    return createEventListenerHandle((listener: (groupId: string) => void): void => {
      service?.on('onConversationGroupDeleted', listener)
    }, (listener: (groupId: string) => void): void => {
      service?.off('onConversationGroupDeleted', listener)
    }, callback)
  }

  static onConversationGroupChanged(
    callback: (conversationGroup: V2NIMConversationGroup) => void
  ): ConversationGroupEventDisposer {
    const service = ChatKitClient.nim.conversationGroupService
    return createEventListenerHandle((listener: (conversationGroup: V2NIMConversationGroup) => void): void => {
      service?.on('onConversationGroupChanged', listener)
    }, (listener: (conversationGroup: V2NIMConversationGroup) => void): void => {
      service?.off('onConversationGroupChanged', listener)
    }, callback)
  }

  static onConversationsAddedToGroup(
    callback: (groupId: string, conversations: V2NIMConversation[]) => void
  ): ConversationGroupEventDisposer {
    const service = ChatKitClient.nim.conversationGroupService
    return createEventListenerHandle(
      (listener: (groupId: string, conversations: V2NIMConversation[]) => void): void => {
        service?.on('onConversationsAddedToGroup', listener)
      },
      (listener: (groupId: string, conversations: V2NIMConversation[]) => void): void => {
        service?.off('onConversationsAddedToGroup', listener)
      },
      callback
    )
  }

  static onConversationsRemovedFromGroup(
    callback: (groupId: string, conversationIds: string[]) => void
  ): ConversationGroupEventDisposer {
    const service = ChatKitClient.nim.conversationGroupService
    return createEventListenerHandle(
      (listener: (groupId: string, conversationIds: string[]) => void): void => {
        service?.on('onConversationsRemovedFromGroup', listener)
      },
      (listener: (groupId: string, conversationIds: string[]) => void): void => {
        service?.off('onConversationsRemovedFromGroup', listener)
      },
      callback
    )
  }

  static onUnreadCountChangedByFilter(
    callback: (filter: V2NIMConversationFilter, unreadCount: number) => void
  ): ConversationGroupEventDisposer {
    const service = ChatKitClient.nim.conversationService
    return createEventListenerHandle(
      (listener: (filter: V2NIMConversationFilter, unreadCount: number) => void): void => {
        service?.on('onUnreadCountChangedByFilter', listener)
      },
      (listener: (filter: V2NIMConversationFilter, unreadCount: number) => void): void => {
        service?.off('onUnreadCountChangedByFilter', listener)
      },
      callback
    )
  }
}
