/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMConversation,
  V2NIMConversationResult,
  V2NIMLocalConversation,
  V2NIMLocalConversationResult
} from '@nimsdk/base'
import { ConversationRepo } from '../repo/ConversationRepo'
import { LocalConversationRepo } from '../repo/LocalConversationRepo'
import { ConversationEventRepo } from '../repo/ConversationEventRepo'

export enum ConversationMode {
  CLOUD = 'cloud',
  LOCAL = 'local'
}

export type ConversationItem = V2NIMConversation | V2NIMLocalConversation
export type ConversationResult = V2NIMConversationResult | V2NIMLocalConversationResult

export interface ConversationStrategy {
  readonly mode: ConversationMode

  getConversationList(offset: number, limit: number): Promise<ConversationResult | null>
  getConversation(conversationId: string): Promise<ConversationItem | undefined>
  deleteConversation(conversationId: string): Promise<void>
  stickTopConversation(conversationId: string, stickTop: boolean): Promise<void>
  clearUnreadCount(conversationIds: string[]): Promise<void>
  getTotalUnreadCount(): number | undefined
  shouldReloadInitialConversationAfterSyncWhenEmpty(): boolean

  onSyncStarted(callback: () => void): void
  onSyncFinished(callback: () => void): void
  onSyncFailed(callback: () => void): void
  onConversationCreated(callback: (conversation: ConversationItem) => void): void
  onConversationDeleted(callback: (conversationIds: string[]) => void): void
  onConversationChanged(callback: (updateList: ConversationItem[]) => void): void
  onTotalUnreadCountChanged(callback: (unreadCount: number) => void): void
  offSyncStarted(callback: () => void): void
  offSyncFinished(callback: () => void): void
  offSyncFailed(callback: () => void): void
  offConversationCreated(callback: (conversation: ConversationItem) => void): void
  offConversationDeleted(callback: (conversationIds: string[]) => void): void
  offConversationChanged(callback: (updateList: ConversationItem[]) => void): void
  offTotalUnreadCountChanged(callback: (unreadCount: number) => void): void

  requiresNetworkForDelete(): boolean
}

export class CloudConversationStrategy implements ConversationStrategy {
  readonly mode: ConversationMode = ConversationMode.CLOUD

  async getConversationList(offset: number, limit: number): Promise<ConversationResult | null> {
    return await ConversationRepo.getConversationList(offset, limit)
  }

  async getConversation(conversationId: string): Promise<ConversationItem | undefined> {
    return await ConversationRepo.getConversation(conversationId)
  }

  async deleteConversation(conversationId: string): Promise<void> {
    await ConversationRepo.deleteConversation(conversationId)
  }

  async stickTopConversation(conversationId: string, stickTop: boolean): Promise<void> {
    await ConversationRepo.stickTopConversation(conversationId, stickTop)
  }

  async clearUnreadCount(conversationIds: string[]): Promise<void> {
    await ConversationRepo.clearUnreadCountByIds(conversationIds)
  }

  getTotalUnreadCount(): number | undefined {
    return ConversationRepo.getTotalUnreadCount()
  }

  shouldReloadInitialConversationAfterSyncWhenEmpty(): boolean {
    return true
  }

  onSyncStarted(callback: () => void): void {
    ConversationEventRepo.onCloudSyncStarted(callback)
  }

  offSyncStarted(callback: () => void): void {
    ConversationEventRepo.offCloudSyncStarted(callback)
  }

  onSyncFinished(callback: () => void): void {
    ConversationEventRepo.onCloudSyncFinished(callback)
  }

  offSyncFinished(callback: () => void): void {
    ConversationEventRepo.offCloudSyncFinished(callback)
  }

  onSyncFailed(callback: () => void): void {
    ConversationEventRepo.onCloudSyncFailed(callback)
  }

  offSyncFailed(callback: () => void): void {
    ConversationEventRepo.offCloudSyncFailed(callback)
  }

  onConversationCreated(callback: (conversation: ConversationItem) => void): void {
    ConversationEventRepo.onCloudConversationCreated(callback as (conversation: V2NIMConversation) => void)
  }

  offConversationCreated(callback: (conversation: ConversationItem) => void): void {
    ConversationEventRepo.offCloudConversationCreated(callback as (conversation: V2NIMConversation) => void)
  }

  onConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ConversationEventRepo.onCloudConversationDeleted(callback)
  }

  offConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ConversationEventRepo.offCloudConversationDeleted(callback)
  }

  onConversationChanged(callback: (updateList: ConversationItem[]) => void): void {
    ConversationEventRepo.onCloudConversationChanged(callback as (updateList: V2NIMConversation[]) => void)
  }

  offConversationChanged(callback: (updateList: ConversationItem[]) => void): void {
    ConversationEventRepo.offCloudConversationChanged(callback as (updateList: V2NIMConversation[]) => void)
  }

  onTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ConversationEventRepo.onCloudTotalUnreadCountChanged(callback)
  }

  offTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ConversationEventRepo.offCloudTotalUnreadCountChanged(callback)
  }

  requiresNetworkForDelete(): boolean {
    return true
  }
}

export class LocalConversationStrategy implements ConversationStrategy {
  readonly mode: ConversationMode = ConversationMode.LOCAL

  async getConversationList(offset: number, limit: number): Promise<ConversationResult | null> {
    return await LocalConversationRepo.getConversationList(offset, limit)
  }

  async getConversation(conversationId: string): Promise<ConversationItem | undefined> {
    return await LocalConversationRepo.getConversation(conversationId)
  }

  async deleteConversation(conversationId: string): Promise<void> {
    await LocalConversationRepo.deleteConversation(conversationId)
  }

  async stickTopConversation(conversationId: string, stickTop: boolean): Promise<void> {
    await LocalConversationRepo.stickTopConversation(conversationId, stickTop)
  }

  async clearUnreadCount(conversationIds: string[]): Promise<void> {
    await LocalConversationRepo.clearUnreadCountByIds(conversationIds)
  }

  getTotalUnreadCount(): number | undefined {
    return LocalConversationRepo.getTotalUnreadCount()
  }

  shouldReloadInitialConversationAfterSyncWhenEmpty(): boolean {
    return false
  }

  onSyncStarted(callback: () => void): void {
    ConversationEventRepo.onLocalSyncStarted(callback)
  }

  offSyncStarted(callback: () => void): void {
    ConversationEventRepo.offLocalSyncStarted(callback)
  }

  onSyncFinished(callback: () => void): void {
    ConversationEventRepo.onLocalSyncFinished(callback)
  }

  offSyncFinished(callback: () => void): void {
    ConversationEventRepo.offLocalSyncFinished(callback)
  }

  onSyncFailed(callback: () => void): void {
    ConversationEventRepo.onLocalSyncFailed(callback)
  }

  offSyncFailed(callback: () => void): void {
    ConversationEventRepo.offLocalSyncFailed(callback)
  }

  onConversationCreated(callback: (conversation: ConversationItem) => void): void {
    ConversationEventRepo.onLocalConversationCreated(callback as (conversation: V2NIMLocalConversation) => void)
  }

  offConversationCreated(callback: (conversation: ConversationItem) => void): void {
    ConversationEventRepo.offLocalConversationCreated(callback as (conversation: V2NIMLocalConversation) => void)
  }

  onConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ConversationEventRepo.onLocalConversationDeleted(callback)
  }

  offConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ConversationEventRepo.offLocalConversationDeleted(callback)
  }

  onConversationChanged(callback: (updateList: ConversationItem[]) => void): void {
    ConversationEventRepo.onLocalConversationChanged(callback as (updateList: V2NIMLocalConversation[]) => void)
  }

  offConversationChanged(callback: (updateList: ConversationItem[]) => void): void {
    ConversationEventRepo.offLocalConversationChanged(callback as (updateList: V2NIMLocalConversation[]) => void)
  }

  onTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ConversationEventRepo.onLocalTotalUnreadCountChanged(callback)
  }

  offTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ConversationEventRepo.offLocalTotalUnreadCountChanged(callback)
  }

  requiresNetworkForDelete(): boolean {
    return false
  }
}
