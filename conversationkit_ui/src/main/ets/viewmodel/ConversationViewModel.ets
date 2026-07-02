/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  AIRepo,
  ChatKitClient,
  ContactRepo,
  IMKitConfigCenter,
  NEAIUserCache,
  NEFriendUserCache,
  TeamRepo,
  UserAIBotManager
} from '@nimkit/chatkit'
import {
  V2NIMConversationType,
  V2NIMFriendDeletionType,
  V2NIMTeam,
  V2NIMTeamType,
  V2NIMUser
} from '@nimsdk/base'
import { Constant } from '../loader/Constant'
import { ConversationModel } from '../model/ConversationModel'
import { AitServer, AitSession, AitSessionChangeEvent } from '../service/ait/AitService'
import { ConversationItem, ConversationStrategy } from '../strategy/ConversationStrategy'
import ConversationData from './ConversationData'
import {
  applyP2PUserProfileDisplayInfo,
  collectP2PConversationTargetIds,
  filterLoadedConversationIds,
  hasLoadedConversationId,
  mergeConversationBatch,
  mergeInitialConversations,
  resolveConversationDisplayInfo,
  resolveDeferredBatchDelay
} from './ConversationUpdateUtils'

@ObservedV2
export class ConversationViewModel {
  @Trace isFinishedSyncLoad: boolean = false
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  @Trace aitConversationList: Set<string> = new Set()
  @Trace userAIBotConversationList: Set<string> = new Set()
  public onUreadMessageChange?: (unreadCount?: number) => void = undefined
  public onConversationFirstReady?: (count: number) => void = undefined
  public onConversationListCountChange?: (count: number) => void = undefined
  public onConversationSyncFinished?: () => void = undefined
  public data: ConversationData<ConversationItem> = new ConversationData<ConversationItem>()
  public isFinished: boolean = false
  private offset: number = 0
  private readonly INITIAL_DISPLAY_COUNT: number = 12
  private readonly LOAD_MORE_LIMIT: number = Constant.PAGE_SIZE
  private readonly DEFERRED_BATCH_SIZE: number = 20
  private readonly PENDING_EVENT_FLUSH_DELAY_MS: number = 200
  private readonly DEFERRED_BATCH_DELAY_MS: number = 100
  private readonly DEFERRED_MAX_BATCH_DELAY_MS: number = 300
  private readonly NON_CRITICAL_STARTUP_DELAY_MS: number = 500
  private hasLoadedInitialConversation: boolean = false
  private hasDeferredLoadScheduled: boolean = false
  private isLoadingInitialConversation: boolean = false
  private initialConversationLoadPromise: Promise<void> | undefined = undefined
  private isLoadingMoreConversation: boolean = false
  private hasReportedFirstReady: boolean = false
  private hasReportedFirstVisible: boolean = false
  private pendingFlushTimer: number = -1
  private nonCriticalStartupTimer: number = -1
  private pendingUpsertConversations: Map<string, ConversationItem> = new Map()
  private pendingDeletedConversationIds: Set<string> = new Set()
  private deferredLoadQueue: ConversationItem[] = []
  private hasAddedAitSessionListener: boolean = false
  private hasAddedAIUserListener: boolean = false
  private model: ConversationModel
  private readonly mode: string

  constructor(strategy: ConversationStrategy) {
    this.model = new ConversationModel(strategy)
    this.mode = strategy.mode
  }

  initConversation() {
    this.logPerf('conversation.vm.init.start')
    if (this.hasLoadedConversationForReuse()) {
      this.setupEventHandler()
      this.logPerf('conversation.vm.init.skip_loaded')
      return
    }
    this.loadConversation()
    this.setupEventHandler()
    this.logPerf('conversation.vm.init.end')
  }

  public hasLoadedConversationForReuse(): boolean {
    return this.isFinishedSyncLoad && this.hasLoadedInitialConversation && this.data.totalCount() > 0
  }

  public async stickTopConversation(conversationId: string, stickTop: boolean) {
    await this.model.stickTopConversation(conversationId, stickTop)
  }

  public async deleteConversation(conversationId: string) {
    await this.model.deleteConversation(conversationId)
    const index = this.data.conversationList?.findIndex((m) => m.conversationId == conversationId)
    if (index > -1) {
      this.data.removeData(index)
    }
    this.userAIBotConversationList.delete(conversationId)
  }

  public async ensureUserAIBotConversation(conversation: ConversationItem): Promise<void> {
    if (conversation.type !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      return
    }
    if (this.userAIBotConversationList.has(conversation.conversationId)) {
      return
    }
    const targetId = this.model.parseConversationTargetId(conversation.conversationId)
    const isUserAIBot = await UserAIBotManager.isUserAIBot(targetId)
    if (isUserAIBot) {
      const updatedSet: Set<string> = new Set(this.userAIBotConversationList)
      updatedSet.add(conversation.conversationId)
      this.userAIBotConversationList = updatedSet
      this.refreshLoadedConversationDisplayInfo(conversation.conversationId)
    }
  }

  public requiresNetworkForDelete(): boolean {
    return this.model.requiresNetworkForDelete()
  }

  public onDestroy(): void {
    this.logPerf('conversation.vm.destroy')
    if (this.hasAddedAitSessionListener) {
      getContext().eventHub.off(AitSessionChangeEvent, this.onAitSessionChange)
      this.hasAddedAitSessionListener = false
    }
    if (this.hasAddedAIUserListener) {
      AIRepo.listener.off('onLoadAIUserComplete', this.onAIUserChanged)
      this.hasAddedAIUserListener = false
    }
    this.model.removeEventListener()
    if (this.pendingFlushTimer >= 0) {
      clearTimeout(this.pendingFlushTimer)
      this.pendingFlushTimer = -1
    }
    if (this.nonCriticalStartupTimer >= 0) {
      clearTimeout(this.nonCriticalStartupTimer)
      this.nonCriticalStartupTimer = -1
    }
    this.pendingUpsertConversations.clear()
    this.pendingDeletedConversationIds.clear()
    this.deferredLoadQueue = []
    this.hasDeferredLoadScheduled = false
    this.userAIBotConversationList.clear()
  }

  public async loadMoreConversation() {
    if (!this.isFinishedSyncLoad) {
      this.logPerf('conversation.load_more.skip_sync')
      return
    }
    if (this.isLoadingMoreConversation) {
      this.logPerf('conversation.load_more.skip_loading')
      return
    }
    if (this.isFinished) {
      this.logPerf('conversation.load_more.skip_finished')
      return
    }
    if (this.data.totalCount() <= 0) {
      this.logPerf('conversation.load_more.skip_empty')
      return
    }

    this.isLoadingMoreConversation = true
    this.logPerf('conversation.load_more.start', `offset=${this.offset} limit=${this.LOAD_MORE_LIMIT}`)
    try {
      const result = await this.model.getConversationList(this.offset, this.LOAD_MORE_LIMIT)
      this.logPerf('conversation.load_more.result',
        `result=${result == null ? 'null' : result.conversationList.length.toString()} finished=${result?.finished ?? false}`)
      if (result) {
        this.offset = result.offset
        this.isFinished = result.finished
      }
      if (result && result.conversationList.length > 0) {
        let newConversation = this.snapshotConversations(result.conversationList)
        this.upsertConversationBatch(newConversation)
      }
    } finally {
      this.isLoadingMoreConversation = false
      this.logPerf('conversation.load_more.end')
    }
  }

  private async updateConversationById(conversationId: string) {
    if (!hasLoadedConversationId(this.data.conversationList, conversationId)) {
      this.logPerf('conversation.update_by_id.skip_unloaded', `conversationId=${conversationId}`)
      return
    }
    this.logPerf('conversation.update_by_id.start', `conversationId=${conversationId}`)
    const newConversation = await this.model.getConversation(conversationId)
    this.logPerf('conversation.update_by_id.result', `conversationId=${conversationId} hasConversation=${newConversation != null}`)
    if (newConversation) {
      this.enqueueOrApplyConversationUpdate(newConversation)
    }
  }

  private async updateLoadedP2PConversations(accountIds: string[]): Promise<void> {
    const changedConversationIds: string[] =
      accountIds.map((accountId: string): string => this.model.p2pConversationId(accountId))
    const loadedConversationIds: string[] =
      filterLoadedConversationIds(this.data.conversationList, changedConversationIds)
    this.logPerf('conversation.update_loaded_p2p.filter',
      `source=${changedConversationIds.length} loaded=${loadedConversationIds.length}`)
    for (const conversationId of loadedConversationIds) {
      await this.updateConversationById(conversationId)
    }
  }

  private async addTeamConversation(conversation: ConversationItem) {
    this.logPerf('conversation.team.validate.start', `conversationId=${conversation.conversationId}`)
    const teamId = this.model.parseConversationTargetId(conversation.conversationId)
    const team = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
    this.logPerf('conversation.team.validate.result',
      `conversationId=${conversation.conversationId} valid=${team?.isValidTeam ?? false}`)
    if (team?.isValidTeam) {
      if (this.shouldApplyFirstVisibleImmediately()) {
        this.addConversation(conversation)
        return
      }
      this.enqueuePendingConversation(conversation)
    } else {
      this.enqueuePendingConversationDelete([conversation.conversationId])
    }
  }

  private setupEventHandler() {
    this.model.onSyncStartedHandle = async () => {
      this.logPerf('conversation.event.sync_started', `hasLoadedInitial=${this.hasLoadedInitialConversation}`)
      if (!this.hasLoadedInitialConversation) {
        await this.loadConversation()
      }
    }

    this.model.onSyncFinishedHandle = async () => {
      this.logPerf('conversation.event.sync_finished')
      await this.reloadInitialConversationAfterSyncWhenEmpty()
      this.isFinishedSyncLoad = true
      this.onConversationSyncFinished?.()
      this.schedulePendingConversationFlush()
    }

    this.model.onSyncFailedHandle = async () => {
      this.logPerf('conversation.event.sync_failed')
      this.isFinishedSyncLoad = true
      this.schedulePendingConversationFlush()
    }

    this.model.onNetBrokenHandle = (networkBroken: boolean) => {
      this.logPerf('conversation.event.network', `networkBroken=${networkBroken}`)
      this.networkBroken = networkBroken
    }
    //好友信息变更修改
    this.model.onFriendInfoChangedHandler = async (accountId: string) => {
      await this.updateLoadedP2PConversations([accountId])
    }
    //用户信息变更修改（昵称、头像等）
    this.model.onUserProfileChangedHandler = async (users: V2NIMUser[]) => {
      const accountIds: string[] = users.map((user: V2NIMUser): string => user.accountId)
      await this.updateLoadedP2PConversations(accountIds)
    }
    //好友删除，别名不存在需要更新
    this.model.onFriendDeletedHandler = async (accountId: string, deletionType: V2NIMFriendDeletionType) => {
      await this.updateLoadedP2PConversations([accountId])
    }

    // 群解散
    this.model.onTeamDismissedHandler = (team: V2NIMTeam) => {
      this.deleteConversation(this.model.teamConversationId(team.teamId))
    }
    // 退出群
    this.model.onTeamLeftHandler = (team: V2NIMTeam) => {
      this.deleteConversation(this.model.teamConversationId(team.teamId))
    }
    // 会话未读数变化
    this.model.onTotalUnreadCountChangedHandler = (unreadCount: number) => {
      this.logPerf('conversation.event.unread', `unread=${unreadCount}`)
      if (this.onUreadMessageChange) {
        this.onUreadMessageChange(unreadCount)
      }
    }
    this.model.onConversationCreatedHandler = (conversation: ConversationItem) => {
      this.logPerf('conversation.event.created',
        `conversationId=${conversation.conversationId} type=${conversation.type}`)
      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        this.addTeamConversation(conversation)
        return
      }
      if (this.shouldApplyFirstVisibleImmediately()) {
        this.addConversation(conversation)
        return
      }
      this.enqueuePendingConversation(conversation)
    }
    this.model.onConversationDeletedHandler = (conversationIds: string[]) => {
      this.logPerf('conversation.event.deleted', `count=${conversationIds.length}`)
      this.enqueuePendingConversationDelete(conversationIds)
    }
    this.model.onConversationChangedHandler = (updateList: ConversationItem[]) => {
      this.logPerf('conversation.event.changed', `count=${updateList.length}`)
      if (this.shouldApplyFirstVisibleImmediately() && updateList.length > 0) {
        this.showFirstVisibleConversationChanges(updateList)
        return
      }
      this.enqueuePendingConversations(updateList)
    }
    if (!this.hasAddedAitSessionListener) {
      getContext().eventHub.on(AitSessionChangeEvent, this.onAitSessionChange)
      this.hasAddedAitSessionListener = true
    }
    if (IMKitConfigCenter.enableAI && !this.hasAddedAIUserListener) {
      AIRepo.listener.on('onLoadAIUserComplete', this.onAIUserChanged)
      this.hasAddedAIUserListener = true
    }

    this.model.addEventListener()
    this.logPerf('conversation.vm.event_handler_ready')
  }

  private onAIUserChanged = () => {
    this.refreshLoadedConversationDisplayInfo()
  }

  private onAitSessionChange = (session: AitSession) => {
    if (session.isAit) {
      this.aitConversationList.add(session.sessionId)
    } else if (this.aitConversationList.has(session.sessionId)) {
      this.aitConversationList.delete(session.sessionId)
    }
  }

  private async loadConversation() {
    if (this.isLoadingInitialConversation) {
      this.logPerf('conversation.load.skip_loading')
      await this.initialConversationLoadPromise
      return
    }

    this.isLoadingInitialConversation = true
    this.initialConversationLoadPromise = this.loadConversationOnce()
    try {
      await this.initialConversationLoadPromise
    } finally {
      this.initialConversationLoadPromise = undefined
    }
  }

  private async loadConversationOnce() {
    this.logPerf('conversation.load.start', `offset=${this.offset} limit=${this.INITIAL_DISPLAY_COUNT}`)
    let firstReadyCount = 0
    try {
      const result = await this.model.getConversationList(this.offset, this.INITIAL_DISPLAY_COUNT)
      firstReadyCount = result?.conversationList.length ?? 0
      this.logPerf('conversation.load.result',
        `result=${result == null ? 'null' : result.conversationList.length.toString()} finished=${result?.finished ?? false}`)
      if (result != null) {
        this.hasLoadedInitialConversation = true
      }

      if (result != null && result.conversationList.length > 0) {
        this.offset = result.offset
        this.isFinished = result.finished
        const allConversations = this.snapshotConversations(result.conversationList)
        allConversations.sort((a, b) => this.sortConversation(a, b))

        this.showInitialConversations(allConversations)
      } else {
        this.logPerf('conversation.load.empty_or_null')
      }
    } finally {
      this.reportConversationFirstReady(firstReadyCount)
      this.isLoadingInitialConversation = false
      this.logPerf('conversation.load.end')
    }
  }

  private async reloadInitialConversationAfterSyncWhenEmpty(): Promise<void> {
    if (!this.model.shouldReloadInitialConversationAfterSyncWhenEmpty()) {
      this.logPerf('conversation.reload_after_sync.skip_strategy')
      return
    }
    if (this.data.totalCount() > 0) {
      this.logPerf('conversation.reload_after_sync.skip_has_data')
      return
    }
    if (this.isLoadingInitialConversation) {
      this.logPerf('conversation.reload_after_sync.wait_loading')
      await this.initialConversationLoadPromise
      if (this.data.totalCount() > 0) {
        this.logPerf('conversation.reload_after_sync.skip_loaded_after_wait')
        return
      }
    }
    this.logPerf('conversation.reload_after_sync.start')
    this.offset = 0
    this.isFinished = false
    await this.loadConversation()
    this.logPerf('conversation.reload_after_sync.end')
  }

  private showInitialConversations(conversations: ConversationItem[]): void {
    this.logPerf('conversation.show_initial.start', `sourceCount=${conversations.length}`)
    const pendingUpsertConversations: ConversationItem[] = []
    this.pendingUpsertConversations.forEach((conversation: ConversationItem) => {
      pendingUpsertConversations.push(conversation)
    })
    const allConversations = mergeInitialConversations(
      this.snapshotConversations(conversations),
      pendingUpsertConversations,
      this.pendingDeletedConversationIds,
      (a: ConversationItem, b: ConversationItem): number => this.sortConversation(a, b)
    )
    const initialBatch = allConversations.slice(0, this.INITIAL_DISPLAY_COUNT)
    this.pendingUpsertConversations.clear()
    this.pendingDeletedConversationIds.clear()
    this.deferredLoadQueue = []
    this.data.conversationList = initialBatch
    this.data.reloadData()
    this.logPerf('conversation.show_initial.reload', `initialCount=${initialBatch.length}`)
    this.reportConversationListCount()
    this.ensureP2PUserInfo(initialBatch)

    const remaining = allConversations.slice(this.INITIAL_DISPLAY_COUNT)
    if (remaining.length > 0) {
      this.logPerf('conversation.show_initial.defer_remaining', `remaining=${remaining.length}`)
      this.scheduleDeferredLoad(remaining)
    }
  }

  private showFirstVisibleConversationChanges(conversations: ConversationItem[]): void {
    this.logPerf('conversation.show_first_visible_changes.start', `count=${conversations.length}`)
    const nonTeamConversations: ConversationItem[] = []
    conversations.forEach(conversation => {
      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        this.addTeamConversation(conversation)
        return
      }
      nonTeamConversations.push(conversation)
    })
    if (nonTeamConversations.length > 0) {
      this.logPerf('conversation.show_first_visible_changes.non_team', `count=${nonTeamConversations.length}`)
      this.showInitialConversations(nonTeamConversations)
    }
  }

  private scheduleDeferredLoad(conversations: ConversationItem[], initialDelay?: number): void {
    if (conversations.length <= 0) {
      this.logPerf('conversation.deferred.skip_empty')
      return
    }
    conversations.forEach(conversation => {
      if (!this.pendingDeletedConversationIds.has(conversation.conversationId)) {
        this.deferredLoadQueue.push(conversation)
      }
    })
    if (this.hasDeferredLoadScheduled) {
      this.logPerf('conversation.deferred.already_scheduled', `queue=${this.deferredLoadQueue.length}`)
      return
    }

    this.hasDeferredLoadScheduled = true
    const delay = initialDelay ?? this.resolveDeferredDelay()
    this.logPerf('conversation.deferred.schedule', `queue=${this.deferredLoadQueue.length} delay=${delay}`)

    const processBatch = () => {
      if (this.deferredLoadQueue.length <= 0) {
        this.hasDeferredLoadScheduled = false
        this.logPerf('conversation.deferred.done')
        return
      }
      const batch = this.deferredLoadQueue.splice(0, this.DEFERRED_BATCH_SIZE)
      this.logPerf('conversation.deferred.batch', `batch=${batch.length} remaining=${this.deferredLoadQueue.length}`)
      this.upsertConversationBatch(batch)
      if (this.deferredLoadQueue.length > 0) {
        setTimeout(processBatch, this.resolveDeferredDelay())
      } else {
        this.hasDeferredLoadScheduled = false
      }
    }
    setTimeout(processBatch, delay)
  }

  private async ensureP2PUserInfo(conversations: ConversationItem[]) {
    const accountIds: string[] = collectP2PConversationTargetIds(
      conversations,
      (conversationId: string): string => this.model.parseConversationTargetId(conversationId)
    )

    if (accountIds.length > 0) {
      try {
        const users = await ContactRepo.getUserListFromCloud(accountIds)
        this.refreshLoadedP2PUserInfo(users)
      } catch (e) {
        Logger.error('ConversationKit', `ensureP2PUserInfo failed: ${e}`)
      }
    }
  }

  private refreshLoadedP2PUserInfo(users: V2NIMUser[]): void {
    if (users.length <= 0) {
      return
    }
    const userMap: Map<string, V2NIMUser> = new Map()
    users.forEach((user: V2NIMUser) => {
      userMap.set(user.accountId, user)
    })

    let changed = false
    this.data.conversationList.forEach((conversation: ConversationItem) => {
      if (conversation.type !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        return
      }
      const targetId = this.model.parseConversationTargetId(conversation.conversationId)
      const user = userMap.get(targetId)
      if (user === undefined) {
        return
      }
      const name = conversation.name ?? ''
      const avatar = conversation.avatar ?? ''
      const userAIBot = UserAIBotManager.getCachedUserAIBot(targetId)
      const aiUser = IMKitConfigCenter.enableAI ? NEAIUserCache.getAIUser(targetId) : undefined
      const isFriend = NEFriendUserCache.peekInstance()?.isFriend(targetId) ?? false
      if (userAIBot || aiUser) {
        resolveConversationDisplayInfo(
          conversation,
          targetId,
          userAIBot ? { name: userAIBot.name, avatar: userAIBot.icon ?? '' } : undefined,
          aiUser ? { name: aiUser.name, avatar: aiUser.avatar ?? '' } : undefined,
          { replaceName: true, replaceAvatar: true }
        )
      } else if (!isFriend) {
        applyP2PUserProfileDisplayInfo(conversation, targetId, { name: user.name, avatar: user.avatar })
      }
      if ((conversation.name ?? '') !== name || (conversation.avatar ?? '') !== avatar) {
        changed = true
      }
    })

    if (changed) {
      this.data.reloadData()
    }
  }

  private addConversation(conversation: ConversationItem) {
    this.logPerf('conversation.add', `conversationId=${conversation.conversationId}`)
    const snapshotConversation = this.snapshotConversation(conversation)
    this.removeDeferredConversation(snapshotConversation.conversationId)
    const existIndex = this.data.conversationList.findIndex(item => item.conversationId === snapshotConversation.conversationId)
    if (existIndex > -1) {
      this.upsertConversation(snapshotConversation)
      return
    }
    const insertIndex = this.findConversationInsertIndex(snapshotConversation)
    this.data.addData(insertIndex, snapshotConversation)
    this.reportConversationListCount()
    this.ensureP2PUserInfo([snapshotConversation])
  }

  private upsertConversation(conversation: ConversationItem) {
    this.logPerf('conversation.upsert', `conversationId=${conversation.conversationId}`)
    this.removeDeferredConversation(conversation.conversationId)
    if (this.applyUpsertConversation(conversation)) {
      this.data.reloadData()
      this.ensureP2PUserInfo([conversation])
    }
    this.reportConversationListCount()
  }

  private upsertConversationBatch(conversations: ConversationItem[]): void {
    this.logPerf('conversation.upsert_batch.start', `count=${conversations.length}`)
    const snapshotConversations: ConversationItem[] = []
    conversations.forEach((conversation: ConversationItem) => {
      const snapshotConversation = this.snapshotConversation(conversation)
      this.removeDeferredConversation(snapshotConversation.conversationId)
      if (!this.pendingUpsertConversations.has(snapshotConversation.conversationId)) {
        snapshotConversations.push(snapshotConversation)
      }
    })
    const mergeResult = mergeConversationBatch(
      this.data.conversationList,
      snapshotConversations,
      new Set<string>(),
      (a: ConversationItem, b: ConversationItem): number => this.sortConversation(a, b)
    )
    if (mergeResult.changed) {
      this.data.conversationList = mergeResult.conversations
      this.data.reloadData()
      this.logPerf('conversation.upsert_batch.reload', `count=${conversations.length}`)
      this.reportConversationListCount()
      this.ensureP2PUserInfo(snapshotConversations)
    } else {
      this.logPerf('conversation.upsert_batch.no_reload', `count=${conversations.length}`)
    }
  }

  private applyUpsertConversation(conversation: ConversationItem): boolean {
    const snapshotConversation = this.snapshotConversation(conversation)
    this.removeDeferredConversation(snapshotConversation.conversationId)
    const existIndex = this.data.conversationList.findIndex(item => item.conversationId === snapshotConversation.conversationId)
    if (existIndex > -1) {
      this.data.conversationList.splice(existIndex, 1)
    }
    const insertIndex = this.findConversationInsertIndex(snapshotConversation)
    this.data.conversationList.splice(insertIndex, 0, snapshotConversation)
    return true
  }

  private reportConversationListCount(): void {
    const count = this.data.totalCount()
    if (count <= 0 || this.hasReportedFirstVisible) {
      this.logPerf('conversation.report_count.skip', `count=${count} reported=${this.hasReportedFirstVisible}`)
      return
    }
    this.hasReportedFirstVisible = true
    this.logPerf('conversation.report_count.first_visible', `count=${count}`)
    this.onConversationListCountChange?.(count)
    this.scheduleLoadAitSessions()
  }

  private reportConversationFirstReady(count: number): void {
    if (this.hasReportedFirstReady) {
      this.logPerf('conversation.report_ready.skip', `count=${count}`)
      return
    }
    this.hasReportedFirstReady = true
    this.logPerf('conversation.report_ready.first', `count=${count}`)
    this.onConversationFirstReady?.(count)
  }

  private shouldApplyFirstVisibleImmediately(): boolean {
    return this.data.totalCount() <= 0 && !this.hasReportedFirstVisible
  }

  private enqueueOrApplyConversationUpdate(conversation: ConversationItem): void {
    if (this.shouldApplyFirstVisibleImmediately()) {
      this.addConversation(conversation)
      return
    }
    this.enqueuePendingConversation(conversation)
  }

  private enqueuePendingConversations(conversations: ConversationItem[]): void {
    conversations.forEach(conversation => {
      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        this.addTeamConversation(conversation)
        return
      }
      this.enqueuePendingConversation(conversation, false)
    })
    this.schedulePendingConversationFlush()
  }

  private enqueuePendingConversation(conversation: ConversationItem, scheduleFlush: boolean = true): void {
    if (!conversation.conversationId) {
      return
    }
    this.pendingDeletedConversationIds.delete(conversation.conversationId)
    this.pendingUpsertConversations.set(conversation.conversationId, this.snapshotConversation(conversation))
    if (scheduleFlush) {
      this.schedulePendingConversationFlush()
    }
  }

  private enqueuePendingConversationDelete(conversationIds: string[]): void {
    conversationIds.forEach(conversationId => {
      this.pendingUpsertConversations.delete(conversationId)
      this.pendingDeletedConversationIds.add(conversationId)
      this.userAIBotConversationList.delete(conversationId)
      this.removeDeferredConversation(conversationId)
    })
    this.schedulePendingConversationFlush()
  }

  private schedulePendingConversationFlush(): void {
    if (this.pendingFlushTimer >= 0) {
      this.logPerf('conversation.pending_flush.skip',
        `timer=${this.pendingFlushTimer}`)
      return
    }
    this.logPerf('conversation.pending_flush.schedule', `delay=${this.PENDING_EVENT_FLUSH_DELAY_MS}`)
    this.pendingFlushTimer = setTimeout(() => {
      this.pendingFlushTimer = -1
      this.flushPendingConversationUpdates()
    }, this.PENDING_EVENT_FLUSH_DELAY_MS)
  }

  private flushPendingConversationUpdates(): void {
    this.logPerf('conversation.pending_flush.start',
      `upserts=${this.pendingUpsertConversations.size} deletes=${this.pendingDeletedConversationIds.size}`)
    if (this.pendingFlushTimer >= 0) {
      clearTimeout(this.pendingFlushTimer)
      this.pendingFlushTimer = -1
    }

    this.pendingDeletedConversationIds.forEach(conversationId => {
      this.removeDeferredConversation(conversationId)
    })
    const deletedConversationIds: Set<string> = new Set()
    this.pendingDeletedConversationIds.forEach((conversationId: string) => {
      deletedConversationIds.add(conversationId)
    })
    this.pendingDeletedConversationIds.clear()

    const conversations: ConversationItem[] = []
    this.pendingUpsertConversations.forEach(conversation => {
      this.removeDeferredConversation(conversation.conversationId)
      conversations.push(conversation)
    })
    this.pendingUpsertConversations.clear()
    const mergeResult = mergeConversationBatch(
      this.data.conversationList,
      conversations,
      deletedConversationIds,
      (a: ConversationItem, b: ConversationItem): number => this.sortConversation(a, b)
    )

    if (mergeResult.changed) {
      this.data.conversationList = mergeResult.conversations
      this.data.reloadData()
      this.logPerf('conversation.pending_flush.reload')
      this.reportConversationListCount()
      this.ensureP2PUserInfo(conversations)
    } else {
      this.logPerf('conversation.pending_flush.no_reload')
    }
  }

  private removeDeferredConversation(conversationId: string): void {
    if (this.deferredLoadQueue.length <= 0) {
      return
    }
    this.deferredLoadQueue = this.deferredLoadQueue.filter(conversation =>
    conversation.conversationId !== conversationId)
  }

  private resolveDeferredDelay(): number {
    return resolveDeferredBatchDelay(
      this.deferredLoadQueue.length,
      this.DEFERRED_BATCH_SIZE,
      this.DEFERRED_BATCH_DELAY_MS,
      this.DEFERRED_MAX_BATCH_DELAY_MS
    )
  }

  private findConversationInsertIndex(conversation: ConversationItem): number {
    let insertIndex = this.data.conversationList.length
    for (let i = 0; i < this.data.conversationList.length; i++) {
      if (conversation.sortOrder > this.data.conversationList[i].sortOrder) {
        insertIndex = i
        break
      }
    }
    return insertIndex
  }

  private loadAitSessions() {
    AitServer.instance.getAllAitSession(ChatKitClient.getLoginUserId()).then((
      aitSessions: string[]
    ) => {
      aitSessions.forEach((session) => {
        this.aitConversationList.add(session)
      })
    })
  }

  private scheduleLoadAitSessions(): void {
    if (this.nonCriticalStartupTimer >= 0) {
      this.logPerf('conversation.ait.skip_scheduled')
      return
    }
    this.logPerf('conversation.ait.schedule', `delay=${this.NON_CRITICAL_STARTUP_DELAY_MS}`)
    this.nonCriticalStartupTimer = setTimeout(() => {
      this.nonCriticalStartupTimer = -1
      this.logPerf('conversation.ait.load_start')
      this.loadAitSessions()
    }, this.NON_CRITICAL_STARTUP_DELAY_MS)
  }

  private logPerf(_stage: string, _detail: string = ''): void {
  }

  private sortConversation(a: ConversationItem, b: ConversationItem): number {
    return b.sortOrder - a.sortOrder
  }

  private snapshotConversations(conversations: ConversationItem[]): ConversationItem[] {
    return conversations.map(conversation => this.snapshotConversation(conversation))
  }

  private snapshotConversation(conversation: ConversationItem): ConversationItem {
    return this.resolveConversationDisplayInfo(conversation)
  }

  private resolveConversationDisplayInfo(conversation: ConversationItem): ConversationItem {
    if (conversation.type !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      return conversation
    }
    const targetId = this.model.parseConversationTargetId(conversation.conversationId)
    const userAIBot = UserAIBotManager.getCachedUserAIBot(targetId)
    const aiUser = IMKitConfigCenter.enableAI ? NEAIUserCache.getAIUser(targetId) : undefined
    return resolveConversationDisplayInfo(
      conversation,
      targetId,
      userAIBot ? { name: userAIBot.name, avatar: userAIBot.icon ?? '' } : undefined,
      aiUser ? { name: aiUser.name, avatar: aiUser.avatar ?? '' } : undefined,
      userAIBot || aiUser ? { replaceName: true, replaceAvatar: true } : undefined
    )
  }

  private refreshLoadedConversationDisplayInfo(conversationId?: string): void {
    let changed = false
    this.data.conversationList.forEach((conversation: ConversationItem) => {
      if (conversationId !== undefined && conversation.conversationId !== conversationId) {
        return
      }
      const name = conversation.name ?? ''
      const avatar = conversation.avatar ?? ''
      this.resolveConversationDisplayInfo(conversation)
      if ((conversation.name ?? '') !== name || (conversation.avatar ?? '') !== avatar) {
        changed = true
      }
    })
    if (changed) {
      this.data.reloadData()
    }

    this.pendingUpsertConversations.forEach((conversation: ConversationItem, key: string) => {
      if (conversationId !== undefined && conversation.conversationId !== conversationId) {
        return
      }
      this.pendingUpsertConversations.set(key, this.resolveConversationDisplayInfo(conversation))
    })
    if (this.deferredLoadQueue.length > 0) {
      this.deferredLoadQueue = this.deferredLoadQueue.map((conversation: ConversationItem): ConversationItem => {
        if (conversationId !== undefined && conversation.conversationId !== conversationId) {
          return conversation
        }
        return this.resolveConversationDisplayInfo(conversation)
      })
    }
  }
}
