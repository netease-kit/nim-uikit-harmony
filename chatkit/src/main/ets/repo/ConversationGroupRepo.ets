/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMConversationFilter,
  V2NIMConversationGroup,
  V2NIMConversationGroupResult,
  V2NIMConversationOperationResult
} from '@nimsdk/base'
import { ChatKitClient } from '../ChatKitClient'

const TAG = '[ConversationGroupRepo]'

export class ConversationGroupRepo {
  static async createConversationGroup(name: string, serverExtension?: string,
    conversationIds?: string[]): Promise<V2NIMConversationGroupResult | undefined> {
    return await ChatKitClient.nim.conversationGroupService?.createConversationGroup(name, serverExtension,
      conversationIds)
  }

  static async deleteConversationGroup(groupId: string): Promise<void> {
    return await ChatKitClient.nim.conversationGroupService?.deleteConversationGroup(groupId)
  }

  static async updateConversationGroup(groupId: string, name?: string, serverExtension?: string): Promise<void> {
    return await ChatKitClient.nim.conversationGroupService?.updateConversationGroup(groupId, name, serverExtension)
  }

  static async addConversationsToGroup(groupId: string,
    conversationIds: string[]): Promise<V2NIMConversationOperationResult[] | undefined> {
    return await ChatKitClient.nim.conversationGroupService?.addConversationsToGroup(groupId, conversationIds)
  }

  static async removeConversationsFromGroup(groupId: string,
    conversationIds: string[]): Promise<V2NIMConversationOperationResult[] | undefined> {
    return await ChatKitClient.nim.conversationGroupService?.removeConversationsFromGroup(groupId, conversationIds)
  }

  static async getConversationGroup(groupId: string): Promise<V2NIMConversationGroup | undefined> {
    return await ChatKitClient.nim.conversationGroupService?.getConversationGroup(groupId)
  }

  static async getConversationGroupList(): Promise<V2NIMConversationGroup[] | undefined> {
    return await ChatKitClient.nim.conversationGroupService?.getConversationGroupList()
  }

  static async getConversationGroupListByIds(groupIds: string[]): Promise<V2NIMConversationGroup[] | undefined> {
    return await ChatKitClient.nim.conversationGroupService?.getConversationGroupListByIds(groupIds)
  }

  static async getUnreadCountByGroupId(groupId: string): Promise<number | undefined> {
    return await ChatKitClient.nim.conversationService?.getUnreadCountByFilter({
      conversationGroupId: groupId
    })
  }

  static subscribeUnreadCountByGroupId(groupId: string): void {
    const filter: V2NIMConversationFilter = {
      conversationGroupId: groupId
    }
    ChatKitClient.nim.conversationService?.subscribeUnreadCountByFilter(filter)
  }

  static safeSubscribeUnreadCountByGroupId(groupId: string): boolean {
    try {
      ConversationGroupRepo.subscribeUnreadCountByGroupId(groupId)
      return true
    } catch (e) {
      ChatKitClient.logger?.error(TAG, 'safeSubscribeUnreadCountByGroupId', groupId, `${e}`)
      return false
    }
  }

  static unsubscribeUnreadCountByGroupId(groupId: string): void {
    const filter: V2NIMConversationFilter = {
      conversationGroupId: groupId
    }
    ChatKitClient.nim.conversationService?.unsubscribeUnreadCountByFilter(filter)
  }

  static safeUnsubscribeUnreadCountByGroupId(groupId: string): boolean {
    try {
      ConversationGroupRepo.unsubscribeUnreadCountByGroupId(groupId)
      return true
    } catch (e) {
      ChatKitClient.logger?.error(TAG, 'safeUnsubscribeUnreadCountByGroupId', groupId, `${e}`)
      return false
    }
  }
}
