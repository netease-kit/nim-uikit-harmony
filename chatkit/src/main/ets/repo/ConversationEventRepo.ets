/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMConversation,
  V2NIMError,
  V2NIMLocalConversation
} from '@nimsdk/base'
import { ChatKitClient } from '../ChatKitClient'

export class ConversationEventRepo {
  static onCloudSyncStarted(callback: () => void): void {
    ChatKitClient.nim.conversationService?.on('onSyncStarted', callback)
  }

  static offCloudSyncStarted(callback: () => void): void {
    ChatKitClient.nim.conversationService?.off('onSyncStarted', callback)
  }

  static onLocalSyncStarted(callback: () => void): void {
    ChatKitClient.nim.localConversationService?.on('onSyncStarted', callback)
  }

  static offLocalSyncStarted(callback: () => void): void {
    ChatKitClient.nim.localConversationService?.off('onSyncStarted', callback)
  }

  static onCloudSyncFinished(callback: () => void): void {
    ChatKitClient.nim.conversationService?.on('onSyncFinished', callback)
  }

  static offCloudSyncFinished(callback: () => void): void {
    ChatKitClient.nim.conversationService?.off('onSyncFinished', callback)
  }

  static onLocalSyncFinished(callback: () => void): void {
    ChatKitClient.nim.localConversationService?.on('onSyncFinished', callback)
  }

  static offLocalSyncFinished(callback: () => void): void {
    ChatKitClient.nim.localConversationService?.off('onSyncFinished', callback)
  }

  static onCloudSyncFailed(callback: (error?: V2NIMError) => void): void {
    const listener = callback as (error: V2NIMError) => void
    ChatKitClient.nim.conversationService?.on('onSyncFailed', listener)
  }

  static offCloudSyncFailed(callback: (error?: V2NIMError) => void): void {
    const listener = callback as (error: V2NIMError) => void
    ChatKitClient.nim.conversationService?.off('onSyncFailed', listener)
  }

  static onLocalSyncFailed(callback: (error?: V2NIMError) => void): void {
    const listener = callback as (error: V2NIMError) => void
    ChatKitClient.nim.localConversationService?.on('onSyncFailed', listener)
  }

  static offLocalSyncFailed(callback: (error?: V2NIMError) => void): void {
    const listener = callback as (error: V2NIMError) => void
    ChatKitClient.nim.localConversationService?.off('onSyncFailed', listener)
  }

  static onCloudConversationCreated(callback: (conversation: V2NIMConversation) => void): void {
    ChatKitClient.nim.conversationService?.on('onConversationCreated', callback)
  }

  static offCloudConversationCreated(callback: (conversation: V2NIMConversation) => void): void {
    ChatKitClient.nim.conversationService?.off('onConversationCreated', callback)
  }

  static onLocalConversationCreated(callback: (conversation: V2NIMLocalConversation) => void): void {
    ChatKitClient.nim.localConversationService?.on('onConversationCreated', callback)
  }

  static offLocalConversationCreated(callback: (conversation: V2NIMLocalConversation) => void): void {
    ChatKitClient.nim.localConversationService?.off('onConversationCreated', callback)
  }

  static onCloudConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ChatKitClient.nim.conversationService?.on('onConversationDeleted', callback)
  }

  static offCloudConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ChatKitClient.nim.conversationService?.off('onConversationDeleted', callback)
  }

  static onLocalConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ChatKitClient.nim.localConversationService?.on('onConversationDeleted', callback)
  }

  static offLocalConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ChatKitClient.nim.localConversationService?.off('onConversationDeleted', callback)
  }

  static onCloudConversationChanged(callback: (conversationList: V2NIMConversation[]) => void): void {
    ChatKitClient.nim.conversationService?.on('onConversationChanged', callback)
  }

  static offCloudConversationChanged(callback: (conversationList: V2NIMConversation[]) => void): void {
    ChatKitClient.nim.conversationService?.off('onConversationChanged', callback)
  }

  static onLocalConversationChanged(callback: (conversationList: V2NIMLocalConversation[]) => void): void {
    ChatKitClient.nim.localConversationService?.on('onConversationChanged', callback)
  }

  static offLocalConversationChanged(callback: (conversationList: V2NIMLocalConversation[]) => void): void {
    ChatKitClient.nim.localConversationService?.off('onConversationChanged', callback)
  }

  static onCloudTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ChatKitClient.nim.conversationService?.on('onTotalUnreadCountChanged', callback)
  }

  static offCloudTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ChatKitClient.nim.conversationService?.off('onTotalUnreadCountChanged', callback)
  }

  static onLocalTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ChatKitClient.nim.localConversationService?.on('onTotalUnreadCountChanged', callback)
  }

  static offLocalTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ChatKitClient.nim.localConversationService?.off('onTotalUnreadCountChanged', callback)
  }
}
