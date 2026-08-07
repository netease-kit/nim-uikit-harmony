/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  ChatKitClient,
  CONVERSATION_GROUP_DEFAULT_ALL_KEY,
  ConversationGroupCreateSource,
  ConversationGroupDisplayConfig,
  ConversationGroupDisplayConfigStore,
  ConversationGroupEventRepo,
  ConversationGroupRepo,
  DisposableBag,
  PreferencesConversationGroupDisplayConfigStorage
} from '@nimkit/chatkit'
import {
  V2NIMConversation,
  V2NIMConversationFilter,
  V2NIMConversationGroup,
  V2NIMConversationGroupResult,
  V2NIMConversationOperationResult
} from '@nimsdk/base'
import {
  buildConversationGroupInfoLists,
  ConversationGroupDefaultCounts,
  ConversationGroupDefaultNames,
  ConversationGroupInfo,
  ConversationGroupInfoListResult,
  ConversationGroupKind,
  createDefaultConversationGroupInfo,
  createInitialConversationGroupInfos
} from '../model/ConversationGroupModel'

const TAG = '[ConversationGroupViewModel]'

@ObservedV2
export class ConversationGroupViewModel {
  @Trace visibleGroups: ConversationGroupInfo[] = []
  @Trace hiddenGroups: ConversationGroupInfo[] = []
  @Trace selectedGroupKey: string = CONVERSATION_GROUP_DEFAULT_ALL_KEY
  @Trace isFinishedLoad: boolean = false
  public onSelectedGroupDeleted?: (group: ConversationGroupInfo) => void = undefined
  public onCustomGroupMembersChanged?: (groupId: string) => void = undefined
  private readonly eventDisposers: DisposableBag = new DisposableBag()
  private readonly subscribedGroupIds: Set<string> = new Set()
  private readonly locallyCreatedGroupIds: Set<string> = new Set()
  private store?: ConversationGroupDisplayConfigStore = undefined
  private accountId: string = ''
  private cloudGroups: V2NIMConversationGroup[] = []
  private customUnreadCountMap: Map<string, number> = new Map()
  private defaultCounts: ConversationGroupDefaultCounts = new ConversationGroupDefaultCounts()
  private defaultNames: ConversationGroupDefaultNames = new ConversationGroupDefaultNames('', '', '')
  private hasAddedEventListener: boolean = false

  setDefaultNames(defaultNames: ConversationGroupDefaultNames): void {
    this.defaultNames = defaultNames
  }

  async initConversationGroups(defaultCounts: ConversationGroupDefaultCounts): Promise<void> {
    this.defaultCounts = defaultCounts
    this.accountId = ChatKitClient.getLoginUserId()
    this.visibleGroups = createInitialConversationGroupInfos(defaultCounts, this.defaultNames)
    this.hiddenGroups = []
    this.ensureStore()
    try {
      const groups = await ConversationGroupRepo.getConversationGroupList()
      this.cloudGroups = groups ?? []
      const groupIds = this.cloudGroups.map((group: V2NIMConversationGroup): string => group.groupId)
      this.store?.load(this.accountId, groupIds)
      this.rebuildGroups()
      await this.refreshCustomUnreadCounts()
      this.addEventListener()
      this.isFinishedLoad = true
    } catch (e) {
      ChatKitClient.logger?.error(TAG, 'initConversationGroups', e)
      this.rebuildGroups()
      this.isFinishedLoad = true
    }
  }

  updateDefaultCounts(defaultCounts: ConversationGroupDefaultCounts): void {
    this.defaultCounts = defaultCounts
    if (!this.isFinishedLoad) {
      this.visibleGroups = createInitialConversationGroupInfos(defaultCounts, this.defaultNames)
      this.hiddenGroups = []
      return
    }
    this.rebuildGroups()
  }

  selectGroup(group: ConversationGroupInfo): void {
    this.selectedGroupKey = group.groupKey
  }

  selectedGroup(): ConversationGroupInfo {
    const group = this.visibleGroups.find((item: ConversationGroupInfo): boolean =>
    item.groupKey === this.selectedGroupKey)
    if (group !== undefined) {
      return group
    }
    return createDefaultConversationGroupInfo(CONVERSATION_GROUP_DEFAULT_ALL_KEY, this.defaultCounts, this.defaultNames)
  }

  async createConversationGroup(name: string, conversationIds?: string[]): Promise<V2NIMConversationGroupResult | undefined> {
    const result = await ConversationGroupRepo.createConversationGroup(name, '', conversationIds)
    if (result?.group !== undefined) {
      this.locallyCreatedGroupIds.add(result.group.groupId)
      this.upsertCloudGroup(result.group)
      this.store?.onLocalGroupCreated(this.accountId, result.group.groupId)
      this.rebuildGroups()
      await this.refreshCustomUnreadCount(result.group.groupId)
    }
    return result
  }

  async updateConversationGroup(groupId: string, name: string): Promise<void> {
    await ConversationGroupRepo.updateConversationGroup(groupId, name, undefined)
    const group = this.cloudGroups.find((item: V2NIMConversationGroup): boolean => item.groupId === groupId)
    if (group !== undefined) {
      group.name = name
      this.rebuildGroups()
    }
  }

  async deleteConversationGroup(groupId: string): Promise<void> {
    await ConversationGroupRepo.deleteConversationGroup(groupId)
    this.onConversationGroupDeleted(groupId)
  }

  async addConversationsToGroup(groupId: string,
    conversationIds: string[]): Promise<V2NIMConversationOperationResult[] | undefined> {
    const result = await ConversationGroupRepo.addConversationsToGroup(groupId, conversationIds)
    await this.refreshCustomUnreadCount(groupId)
    this.onCustomGroupMembersChanged?.(groupId)
    return result
  }

  async removeConversationsFromGroup(groupId: string,
    conversationIds: string[]): Promise<V2NIMConversationOperationResult[] | undefined> {
    const result = await ConversationGroupRepo.removeConversationsFromGroup(groupId, conversationIds)
    await this.refreshCustomUnreadCount(groupId)
    this.onCustomGroupMembersChanged?.(groupId)
    return result
  }

  moveToVisible(group: ConversationGroupInfo): void {
    this.store?.moveToVisible(this.accountId, group.groupKey)
    this.rebuildGroups()
  }

  moveToHidden(group: ConversationGroupInfo): void {
    const shouldResetSelectedGroup = this.selectedGroupKey === group.groupKey
    this.store?.moveToHidden(this.accountId, group.groupKey)
    if (shouldResetSelectedGroup) {
      this.selectedGroupKey = CONVERSATION_GROUP_DEFAULT_ALL_KEY
    }
    this.rebuildGroups()
    if (shouldResetSelectedGroup) {
      this.onSelectedGroupDeleted?.(this.selectedGroup())
    }
  }

  reorderVisible(groupKeys: string[]): void {
    this.store?.reorderVisible(this.accountId, groupKeys)
    this.rebuildGroups()
  }

  onDestroy(): void {
    this.eventDisposers.dispose()
    this.hasAddedEventListener = false
    this.subscribedGroupIds.forEach((groupId: string) => {
      ConversationGroupRepo.safeUnsubscribeUnreadCountByGroupId(groupId)
    })
    this.subscribedGroupIds.clear()
    this.locallyCreatedGroupIds.clear()
  }

  private ensureStore(): void {
    if (this.store !== undefined) {
      return
    }
    this.store = new ConversationGroupDisplayConfigStore(
      new PreferencesConversationGroupDisplayConfigStorage(getContext())
    )
  }

  private addEventListener(): void {
    if (this.hasAddedEventListener) {
      return
    }
    this.eventDisposers.addAll([
      ConversationGroupEventRepo.onConversationGroupCreated(this.onConversationGroupCreated),
      ConversationGroupEventRepo.onConversationGroupDeleted(this.onConversationGroupDeleted),
      ConversationGroupEventRepo.onConversationGroupChanged(this.onConversationGroupChanged),
      ConversationGroupEventRepo.onConversationsAddedToGroup(this.onConversationsAddedToGroup),
      ConversationGroupEventRepo.onConversationsRemovedFromGroup(this.onConversationsRemovedFromGroup),
      ConversationGroupEventRepo.onUnreadCountChangedByFilter(this.onUnreadCountChangedByFilter)
    ])
    this.hasAddedEventListener = true
  }

  private onConversationGroupCreated = async (group: V2NIMConversationGroup): Promise<void> => {
    this.upsertCloudGroup(group)
    if (this.locallyCreatedGroupIds.has(group.groupId)) {
      this.locallyCreatedGroupIds.delete(group.groupId)
    } else {
      this.store?.onGroupCreated(this.accountId, group.groupId, ConversationGroupCreateSource.REMOTE)
    }
    this.rebuildGroups()
    await this.refreshCustomUnreadCount(group.groupId)
  }

  private onConversationGroupDeleted = (groupId: string): void => {
    this.cloudGroups = this.cloudGroups.filter((group: V2NIMConversationGroup): boolean => group.groupId !== groupId)
    this.customUnreadCountMap.delete(groupId)
    this.store?.onGroupDeleted(this.accountId, groupId)
    ConversationGroupRepo.safeUnsubscribeUnreadCountByGroupId(groupId)
    this.subscribedGroupIds.delete(groupId)
    const shouldResetSelectedGroup = this.selectedGroupKey === groupId
    if (shouldResetSelectedGroup) {
      this.selectedGroupKey = CONVERSATION_GROUP_DEFAULT_ALL_KEY
    }
    this.rebuildGroups()
    if (shouldResetSelectedGroup) {
      this.onSelectedGroupDeleted?.(this.selectedGroup())
    }
  }

  private onConversationGroupChanged = (group: V2NIMConversationGroup): void => {
    this.upsertCloudGroup(group)
    this.rebuildGroups()
  }

  private onConversationsAddedToGroup = async (groupId: string, _conversations: V2NIMConversation[]): Promise<void> => {
    await this.refreshCustomUnreadCount(groupId)
    this.onCustomGroupMembersChanged?.(groupId)
  }

  private onConversationsRemovedFromGroup = async (groupId: string, _conversationIds: string[]): Promise<void> => {
    await this.refreshCustomUnreadCount(groupId)
    this.onCustomGroupMembersChanged?.(groupId)
  }

  private onUnreadCountChangedByFilter = (filter: V2NIMConversationFilter, unreadCount: number): void => {
    const groupId = filter.conversationGroupId ?? ''
    if (groupId.length <= 0) {
      return
    }
    this.customUnreadCountMap.set(groupId, unreadCount)
    this.rebuildGroups()
  }

  private rebuildGroups(): void {
    const config = this.currentConfig()
    const result: ConversationGroupInfoListResult = buildConversationGroupInfoLists(
      config,
      this.cloudGroups,
      this.customUnreadCountMap,
      this.defaultCounts,
      this.defaultNames
    )
    this.visibleGroups = result.visibleGroups
    this.hiddenGroups = result.hiddenGroups
    if (this.visibleGroups.find((group: ConversationGroupInfo): boolean =>
    group.groupKey === this.selectedGroupKey) === undefined) {
      this.selectedGroupKey = CONVERSATION_GROUP_DEFAULT_ALL_KEY
    }
  }

  private currentConfig(): ConversationGroupDisplayConfig {
    this.ensureStore()
    const groupIds = this.cloudGroups.map((group: V2NIMConversationGroup): string => group.groupId)
    return this.store?.normalize(this.accountId, groupIds) as ConversationGroupDisplayConfig
  }

  private async refreshCustomUnreadCounts(): Promise<void> {
    for (const group of this.cloudGroups) {
      await this.refreshCustomUnreadCount(group.groupId)
    }
  }

  private async refreshCustomUnreadCount(groupId: string): Promise<void> {
    if (groupId.length <= 0) {
      return
    }
    try {
      const unreadCount = await ConversationGroupRepo.getUnreadCountByGroupId(groupId)
      this.customUnreadCountMap.set(groupId, unreadCount ?? 0)
      if (!this.subscribedGroupIds.has(groupId)) {
        if (ConversationGroupRepo.safeSubscribeUnreadCountByGroupId(groupId)) {
          this.subscribedGroupIds.add(groupId)
        }
      }
      this.rebuildGroups()
    } catch (e) {
      ChatKitClient.logger?.error(TAG, 'refreshCustomUnreadCount', groupId, e)
    }
  }

  private upsertCloudGroup(group: V2NIMConversationGroup): void {
    const index = this.cloudGroups.findIndex((item: V2NIMConversationGroup): boolean => item.groupId === group.groupId)
    if (index >= 0) {
      this.cloudGroups.splice(index, 1, group)
      return
    }
    this.cloudGroups.push(group)
  }
}
