import { ChatKitClient, ConversationRepo, LocalConversationRepo } from '@nimkit/chatkit'
import {
  V2NIMConversation,
  V2NIMConversationResult,
  V2NIMLocalConversation,
  V2NIMLocalConversationResult
} from '@nimsdk/base'

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

  onSyncStarted(callback: () => void): void
  onSyncFinished(callback: () => void): void
  onSyncFailed(callback: () => void): void
  onConversationCreated(callback: (conversation: ConversationItem) => void): void
  onConversationDeleted(callback: (conversationIds: string[]) => void): void
  onConversationChanged(callback: (updateList: ConversationItem[]) => void): void
  onTotalUnreadCountChanged(callback: (unreadCount: number) => void): void

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

  onSyncStarted(callback: () => void): void {
    ChatKitClient.nim.conversationService?.on('onSyncStarted', callback)
  }

  onSyncFinished(callback: () => void): void {
    ChatKitClient.nim.conversationService?.on('onSyncFinished', callback)
  }

  onSyncFailed(callback: () => void): void {
    ChatKitClient.nim.conversationService?.on('onSyncFailed', callback)
  }

  onConversationCreated(callback: (conversation: ConversationItem) => void): void {
    ChatKitClient.nim.conversationService?.on('onConversationCreated', callback)
  }

  onConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ChatKitClient.nim.conversationService?.on('onConversationDeleted', callback)
  }

  onConversationChanged(callback: (updateList: ConversationItem[]) => void): void {
    ChatKitClient.nim.conversationService?.on('onConversationChanged', callback)
  }

  onTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ChatKitClient.nim.conversationService?.on('onTotalUnreadCountChanged', callback)
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

  onSyncStarted(callback: () => void): void {
    ChatKitClient.nim.localConversationService?.on('onSyncStarted', callback)
  }

  onSyncFinished(callback: () => void): void {
    ChatKitClient.nim.localConversationService?.on('onSyncFinished', callback)
  }

  onSyncFailed(callback: () => void): void {
    ChatKitClient.nim.localConversationService?.on('onSyncFailed', callback)
  }

  onConversationCreated(callback: (conversation: ConversationItem) => void): void {
    ChatKitClient.nim.localConversationService?.on('onConversationCreated', callback)
  }

  onConversationDeleted(callback: (conversationIds: string[]) => void): void {
    ChatKitClient.nim.localConversationService?.on('onConversationDeleted', callback)
  }

  onConversationChanged(callback: (updateList: ConversationItem[]) => void): void {
    ChatKitClient.nim.localConversationService?.on('onConversationChanged', callback)
  }

  onTotalUnreadCountChanged(callback: (unreadCount: number) => void): void {
    ChatKitClient.nim.localConversationService?.on('onTotalUnreadCountChanged', callback)
  }

  requiresNetworkForDelete(): boolean {
    return false
  }
}
