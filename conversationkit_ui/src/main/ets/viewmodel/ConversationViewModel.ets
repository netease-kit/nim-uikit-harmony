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
  CONVERSATION_GROUP_DEFAULT_AIT_KEY,
  CONVERSATION_GROUP_DEFAULT_ALL_KEY,
  CONVERSATION_GROUP_DEFAULT_UNREAD_KEY,
  ContactRepo,
  ConversationGroupEventDisposer,
  ConversationGroupEventRepo,
  ConversationRepo,
  IMKitConfigCenter,
  LocalConversationRepo,
  NEAIUserCache,
  NEFriendUserCache,
  TeamRepo,
  UserAIBotManager
} from '@nimkit/chatkit'
import {
  V2NIMConversation,
  V2NIMConversationFilter,
  V2NIMConversationOption,
  V2NIMConversationType,
  V2NIMFriendDeletionType,
  V2NIMLocalConversationFilter,
  V2NIMTeam,
  V2NIMTeamType,
  V2NIMUser
} from '@nimsdk/base'
import { Constant } from '../loader/Constant'
import { ConversationModel } from '../model/ConversationModel'
import {
  ConversationGroupDefaultCounts,
  ConversationGroupInfo,
  ConversationGroupKind,
  createDefaultUnreadConversationFilter,
  filterConversationsByDefaultGroup,
  isDefaultUnreadConversationFilter
} from '../model/ConversationGroupModel'
import { AitServer, AitSession, AitSessionChangeEvent } from '../service/ait/AitService'
import { ConversationItem, ConversationMode, ConversationStrategy } from '../strategy/ConversationStrategy'
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

const UNREAD_GROUP_QUERY_ID: string = '__default_unread__'

class ConversationApplyResult {
  displayChanged: boolean
  sourceChanged: boolean

  constructor(displayChanged: boolean, sourceChanged: boolean) {
    this.displayChanged = displayChanged
    this.sourceChanged = sourceChanged
  }
}

@ObservedV2
export class ConversationViewModel {
  @Trace isFinishedSyncLoad: boolean = false
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  @Trace aitConversationList: Set<string> = new Set()
  @Trace userAIBotConversationList: Set<string> = new Set()
  @Trace selectedConversationGroupKey: string = CONVERSATION_GROUP_DEFAULT_ALL_KEY
  public onUreadMessageChange?: (unreadCount?: number) => void = undefined
  public onConversationFirstReady?: (count: number) => void = undefined
  public onConversationListCountChange?: (count: number) => void = undefined
  public onConversationSyncFinished?: () => void = undefined
  public onDefaultGroupCountChange?: (counts: ConversationGroupDefaultCounts) => void = undefined
  public data: ConversationData<ConversationItem> = new ConversationData<ConversationItem>()
  public isFinished: boolean = false
  private offset: number = 0
  private defaultFinished: boolean = false
  private customGroupOffset: number = 0
  private customGroupFinished: boolean = false
  private customGroupId: string = ''
  private isLoadingCustomGroupConversation: boolean = false
  private customGroupLoadSeq: number = 0
  private customGroupLoadingSeq: number = 0
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
  private allConversationList: ConversationItem[] = []
  private hasAddedAitSessionListener: boolean = false
  private hasAddedAIUserListener: boolean = false
  private hasAddedFriendCacheListener: boolean = false
  private nonMutedUnreadCount: number = 0
  private hasLoadedNonMutedUnreadCount: boolean = false
  private hasSubscribedNonMutedUnreadCount: boolean = false
  private nonMutedUnreadCountEventDisposer?: ConversationGroupEventDisposer = undefined
  private readonly nonMutedUnreadCountFilter: V2NIMConversationFilter = createDefaultUnreadConversationFilter()
  private readonly localNonMutedUnreadCountFilter: V2NIMLocalConversationFilter = { ignoreMuted: true }
  private model: ConversationModel
  private readonly mode: ConversationMode
  private aitSessionLoadSeq: number = 0
  private p2pUserInfoLoadGeneration: number = 0
  @Trace private p2pAvatarNameMap: Map<string, string> = new Map()

  constructor(strategy: ConversationStrategy) {
    this.model = new ConversationModel(strategy)
    this.mode = strategy.mode
  }

  initConversation() {
    this.logPerf('conversation.vm.init.start')
    this.setupNonMutedUnreadCount()
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

  public getConversationAvatarName(conversation: ConversationItem): string {
    if (conversation.type !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      return conversation.name ?? ''
    }
    const targetId = this.model.parseConversationTargetId(conversation.conversationId)
    const userAIBot = UserAIBotManager.getCachedUserAIBot(targetId)
    if (userAIBot?.name) {
      return userAIBot.name
    }
    const aiUser = IMKitConfigCenter.enableAI ? NEAIUserCache.getAIUser(targetId) : undefined
    if (aiUser?.name) {
      return aiUser.name
    }
    const loadedAvatarName = this.p2pAvatarNameMap.get(targetId)
    if (loadedAvatarName) {
      return loadedAvatarName
    }
    return NEFriendUserCache.peekInstance()?.getFriendById(targetId)?.user?.name || targetId
  }

  public async stickTopConversation(conversationId: string, stickTop: boolean) {
    await this.model.stickTopConversation(conversationId, stickTop)
  }

  public async deleteConversation(conversationId: string) {
    await this.model.deleteConversation(conversationId)
    this.removeFromAllConversationList([conversationId])
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

  public getDefaultConversationGroupCounts(): ConversationGroupDefaultCounts {
    const nonMutedUnreadCount = this.hasLoadedNonMutedUnreadCount ? this.nonMutedUnreadCount : 0
    return new ConversationGroupDefaultCounts(
      nonMutedUnreadCount,
      this.getAitBadgeConversationCount(),
      nonMutedUnreadCount
    )
  }

  public async selectConversationGroup(group: ConversationGroupInfo): Promise<void> {
    if (group.kind === ConversationGroupKind.CUSTOM) {
      await this.selectCustomConversationGroup(group.groupId)
      return
    }
    this.customGroupLoadSeq++
    this.customGroupId = ''
    if (this.mode === ConversationMode.CLOUD && group.kind === ConversationGroupKind.UNREAD) {
      await this.selectCustomConversationGroup(UNREAD_GROUP_QUERY_ID)
      return
    }
    this.selectedConversationGroupKey = group.groupKey
    this.isFinished = this.defaultFinished
    this.reloadDefaultGroupDisplay()
  }

  public async reloadSelectedCustomGroupIfNeeded(groupId: string): Promise<void> {
    if (this.customGroupId !== groupId) {
      return
    }
    await this.selectCustomConversationGroup(groupId)
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
    if (this.hasAddedFriendCacheListener) {
      ContactRepo.listener.off('loadFriendCache', this.onFriendCacheLoaded)
      this.hasAddedFriendCacheListener = false
    }
    this.releaseNonMutedUnreadCount()
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
    this.nonMutedUnreadCount = 0
    this.hasLoadedNonMutedUnreadCount = false
    this.customGroupId = ''
    this.customGroupLoadSeq++
    this.aitSessionLoadSeq++
    this.p2pUserInfoLoadGeneration++
    this.p2pAvatarNameMap = new Map()
    this.selectedConversationGroupKey = CONVERSATION_GROUP_DEFAULT_ALL_KEY
  }

  public async loadMoreConversation() {
    if (this.isCustomGroupSelected()) {
      await this.loadMoreCustomConversationGroup()
      return
    }
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
        this.defaultFinished = result.finished
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

  public isLoadingMoreConversationActive(): boolean {
    return this.isLoadingMoreConversation
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
      await this.reloadLoadedConversationsAfterSync()
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
    // 群名称、头像变化
    this.model.onTeamInfoUpdatedHandler = async (team: V2NIMTeam) => {
      await this.updateConversationById(this.model.teamConversationId(team.teamId))
    }
    // 会话未读数变化
    this.model.onTotalUnreadCountChangedHandler = (unreadCount: number) => {
      this.logPerf('conversation.event.unread', `unread=${unreadCount}`)
      this.notifyDefaultGroupCountChange()
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
    if (!this.hasAddedFriendCacheListener) {
      ContactRepo.listener.on('loadFriendCache', this.onFriendCacheLoaded)
      this.hasAddedFriendCacheListener = true
    }

    this.model.addEventListener()
    this.logPerf('conversation.vm.event_handler_ready')
  }

  private onAIUserChanged = () => {
    this.refreshLoadedConversationDisplayInfo()
  }

  private onFriendCacheLoaded = () => {
    this.refreshLoadedConversationDisplayInfo()
  }

  private onAitSessionChange = (session: AitSession) => {
    let changed = false
    if (session.isAit) {
      if (!this.aitConversationList.has(session.sessionId)) {
        this.aitConversationList.add(session.sessionId)
        changed = true
      }
    } else if (this.aitConversationList.has(session.sessionId)) {
      this.aitConversationList.delete(session.sessionId)
      changed = true
    }
    if (changed) {
      this.refreshDefaultGroupDisplayAfterAitChanged()
    }
  }

  private onNonMutedUnreadCountChangedByFilter = (filter: V2NIMConversationFilter, unreadCount: number): void => {
    if (!isDefaultUnreadConversationFilter(filter)) {
      return
    }
    this.updateNonMutedUnreadCount(unreadCount)
  }

  private onLocalNonMutedUnreadCountChangedByFilter =
    (filter: V2NIMLocalConversationFilter, unreadCount: number): void => {
      const hasConversationTypes = (filter.conversationTypes?.length ?? 0) > 0
      if (filter.ignoreMuted !== true || hasConversationTypes) {
        return
      }
      this.updateNonMutedUnreadCount(unreadCount)
    }

  private setupNonMutedUnreadCount(): void {
    if (this.hasSubscribedNonMutedUnreadCount) {
      return
    }
    if (this.nonMutedUnreadCountEventDisposer === undefined) {
      this.nonMutedUnreadCountEventDisposer = this.mode === ConversationMode.CLOUD ?
        ConversationGroupEventRepo.onUnreadCountChangedByFilter(this.onNonMutedUnreadCountChangedByFilter) :
        ConversationGroupEventRepo.onLocalUnreadCountChangedByFilter(this.onLocalNonMutedUnreadCountChangedByFilter)
    }
    if (this.mode === ConversationMode.CLOUD) {
      this.hasSubscribedNonMutedUnreadCount =
        ConversationRepo.safeSubscribeUnreadCountByFilter(this.nonMutedUnreadCountFilter)
    } else {
      try {
        LocalConversationRepo.subscribeUnreadCountByFilter(this.localNonMutedUnreadCountFilter)
        this.hasSubscribedNonMutedUnreadCount = true
      } catch (e) {
        Logger.error('ConversationKit', `subscribe local non-muted unread count failed: ${e}`)
      }
    }
    this.loadNonMutedUnreadCount()
  }

  private async loadNonMutedUnreadCount(): Promise<void> {
    try {
      const unreadCount = this.mode === ConversationMode.CLOUD ?
        await ConversationRepo.getUnreadCountByFilter(this.nonMutedUnreadCountFilter) :
        await LocalConversationRepo.getUnreadCountByFilter(this.localNonMutedUnreadCountFilter)
      this.updateNonMutedUnreadCount(unreadCount ?? 0)
    } catch (e) {
      Logger.error('ConversationKit', `load non-muted unread count failed: ${e}`)
    }
  }

  private updateNonMutedUnreadCount(unreadCount: number): void {
    const nextUnreadCount = unreadCount < 0 ? 0 : unreadCount
    if (this.hasLoadedNonMutedUnreadCount && this.nonMutedUnreadCount === nextUnreadCount) {
      return
    }
    this.nonMutedUnreadCount = nextUnreadCount
    this.hasLoadedNonMutedUnreadCount = true
    this.onUreadMessageChange?.(nextUnreadCount)
    this.notifyDefaultGroupCountChange()
  }

  private releaseNonMutedUnreadCount(): void {
    if (this.hasSubscribedNonMutedUnreadCount) {
      if (this.mode === ConversationMode.CLOUD) {
        ConversationRepo.safeUnsubscribeUnreadCountByFilter(this.nonMutedUnreadCountFilter)
      } else {
        try {
          LocalConversationRepo.unsubscribeUnreadCountByFilter(this.localNonMutedUnreadCountFilter)
        } catch (e) {
          Logger.error('ConversationKit', `unsubscribe local non-muted unread count failed: ${e}`)
        }
      }
    }
    this.hasSubscribedNonMutedUnreadCount = false
    if (this.nonMutedUnreadCountEventDisposer !== undefined) {
      this.nonMutedUnreadCountEventDisposer()
      this.nonMutedUnreadCountEventDisposer = undefined
    }
    this.hasLoadedNonMutedUnreadCount = false
    this.nonMutedUnreadCount = 0
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
        this.defaultFinished = result.finished
        if (!this.isCustomGroupSelected()) {
          this.isFinished = result.finished
        }
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

  private async reloadLoadedConversationsAfterSync(): Promise<void> {
    if (!this.model.shouldReloadInitialConversationAfterSyncWhenEmpty()) {
      this.logPerf('conversation.reload_loaded_after_sync.skip_strategy')
      return
    }
    if (this.isCustomGroupSelected()) {
      if (!this.customGroupId || this.data.totalCount() <= 0) {
        this.logPerf('conversation.reload_loaded_after_sync.skip_custom_empty')
        return
      }
      // Re-query the selected custom group after reconnect when incremental updates were not emitted.
      await this.selectCustomConversationGroup(this.customGroupId)
      return
    }
    const loadedCount = Math.max(this.allConversationList.length, this.data.totalCount())
    if (loadedCount <= 0) {
      this.logPerf('conversation.reload_loaded_after_sync.skip_empty')
      return
    }
    const limit = Math.max(loadedCount, this.INITIAL_DISPLAY_COUNT)
    this.logPerf('conversation.reload_loaded_after_sync.start', `limit=${limit}`)
    const result = await this.model.getConversationList(0, limit)
    if (result == null) {
      this.logPerf('conversation.reload_loaded_after_sync.skip_null')
      return
    }
    this.offset = result.offset
    this.defaultFinished = result.finished
    this.isFinished = result.finished
    const reloadedConversations = this.snapshotConversations(result.conversationList)
    reloadedConversations.sort((a, b) => this.sortConversation(a, b))
    this.pendingUpsertConversations.clear()
    this.pendingDeletedConversationIds.clear()
    this.deferredLoadQueue = []
    this.allConversationList = reloadedConversations
    this.reloadDefaultGroupDisplay()
    this.reportConversationListCount()
    this.ensureP2PUserInfo(reloadedConversations)
    this.logPerf('conversation.reload_loaded_after_sync.end', `count=${reloadedConversations.length}`)
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
    this.allConversationList = allConversations
    if (!this.isCustomGroupSelected()) {
      this.data.conversationList = initialBatch
      this.reloadDefaultGroupDisplay()
    }
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
      const loginUserId = ChatKitClient.getLoginUserId()
      if (loginUserId.length <= 0) {
        return
      }
      const friendUserCache = NEFriendUserCache.getInstance()
      const loadGeneration = this.p2pUserInfoLoadGeneration
      try {
        // Load friend aliases for visible conversations even before the contact tab is created.
        const userWithFriends = await ContactRepo.getUserWithFriendByIds(accountIds)
        // Ignore profile loads from a destroyed view model or a previous account.
        if (loadGeneration !== this.p2pUserInfoLoadGeneration ||
          loginUserId !== ChatKitClient.getLoginUserId() ||
          NEFriendUserCache.peekInstance() !== friendUserCache) {
          return
        }
        const users: V2NIMUser[] = []
        userWithFriends.forEach((userWithFriend) => {
          if (userWithFriend.user !== undefined) {
            users.push(userWithFriend.user)
          }
        })
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
    let changed = false
    const nextAvatarNameMap = new Map(this.p2pAvatarNameMap)
    users.forEach((user: V2NIMUser) => {
      const avatarName = user.name && user.name.length > 0 ? user.name : user.accountId
      if (avatarName.length > 0 && nextAvatarNameMap.get(user.accountId) !== avatarName) {
        nextAvatarNameMap.set(user.accountId, avatarName)
        changed = true
      }
    })
    if (changed) {
      this.p2pAvatarNameMap = nextAvatarNameMap
    }
    const userMap: Map<string, V2NIMUser> = new Map()
    users.forEach((user: V2NIMUser) => {
      userMap.set(user.accountId, user)
    })

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
      if (userAIBot || aiUser || isFriend) {
        this.resolveConversationDisplayInfo(conversation)
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
    const result = this.applyUpsertConversation(snapshotConversation)
    if (result.displayChanged) {
      if (this.isCustomGroupSelected()) {
        this.data.reloadData()
      } else {
        this.reloadDefaultGroupDisplay()
      }
    }
    if (result.displayChanged || result.sourceChanged) {
      this.reportConversationListCount()
      this.notifyDefaultGroupCountChange()
      this.ensureP2PUserInfo([snapshotConversation])
    }
  }

  private upsertConversation(conversation: ConversationItem) {
    this.logPerf('conversation.upsert', `conversationId=${conversation.conversationId}`)
    this.removeDeferredConversation(conversation.conversationId)
    const result = this.applyUpsertConversation(conversation)
    if (result.displayChanged) {
      if (this.isCustomGroupSelected()) {
        this.data.reloadData()
      } else {
        this.reloadDefaultGroupDisplay()
      }
    }
    if (result.displayChanged || result.sourceChanged) {
      this.notifyDefaultGroupCountChange()
      this.ensureP2PUserInfo([conversation])
    }
    this.reportConversationListCount()
  }

  private upsertConversationBatch(conversations: ConversationItem[],
    syncAllListWhenCustomSelected: boolean = true): void {
    this.logPerf('conversation.upsert_batch.start', `count=${conversations.length}`)
    const snapshotConversations: ConversationItem[] = []
    conversations.forEach((conversation: ConversationItem) => {
      const snapshotConversation = this.snapshotConversation(conversation)
      this.removeDeferredConversation(snapshotConversation.conversationId)
      if (!this.pendingUpsertConversations.has(snapshotConversation.conversationId)) {
        snapshotConversations.push(snapshotConversation)
      }
    })
    const customGroupSelected = this.isCustomGroupSelected()
    let sourceChanged = false
    if (customGroupSelected && syncAllListWhenCustomSelected) {
      sourceChanged = this.mergeAllConversationList(snapshotConversations, new Set<string>())
    }
    const mergeResult = mergeConversationBatch(
      customGroupSelected ? this.data.conversationList : this.allConversationList,
      snapshotConversations,
      new Set<string>(),
      (a: ConversationItem, b: ConversationItem): number => this.sortConversation(a, b)
    )
    let displayChanged = mergeResult.changed
    if (mergeResult.changed) {
      if (customGroupSelected) {
        const displayConversations = this.filterCustomGroupConversations(mergeResult.conversations)
        displayChanged = !this.isSameConversationList(this.data.conversationList, displayConversations)
        if (displayChanged) {
          this.data.conversationList = displayConversations
          this.data.reloadData()
        }
      } else {
        this.allConversationList = mergeResult.conversations
        this.reloadDefaultGroupDisplay()
      }
      this.logPerf('conversation.upsert_batch.reload', `count=${conversations.length}`)
    } else {
      this.logPerf('conversation.upsert_batch.no_reload', `count=${conversations.length}`)
    }
    if (displayChanged || sourceChanged) {
      this.reportConversationListCount()
      this.notifyDefaultGroupCountChange()
      this.ensureP2PUserInfo(snapshotConversations)
    }
  }

  private applyUpsertConversation(conversation: ConversationItem): ConversationApplyResult {
    const snapshotConversation = this.snapshotConversation(conversation)
    this.removeDeferredConversation(snapshotConversation.conversationId)
    if (!this.isCustomGroupSelected()) {
      const existIndex = this.allConversationList.findIndex(item =>
      item.conversationId === snapshotConversation.conversationId)
      if (existIndex > -1) {
        this.allConversationList.splice(existIndex, 1)
      }
      const insertIndex = this.findConversationInsertIndex(snapshotConversation, this.allConversationList)
      this.allConversationList.splice(insertIndex, 0, snapshotConversation)
      return new ConversationApplyResult(true, true)
    }

    const sourceChanged = this.mergeAllConversationList([snapshotConversation], new Set<string>())
    const targetList = this.data.conversationList
    const existIndex = targetList.findIndex(item => item.conversationId === snapshotConversation.conversationId)
    if (existIndex > -1) {
      targetList.splice(existIndex, 1)
    }
    if (!this.isConversationInCurrentCustomGroup(snapshotConversation)) {
      return new ConversationApplyResult(existIndex > -1, sourceChanged)
    }
    const insertIndex = this.findConversationInsertIndex(snapshotConversation, targetList)
    targetList.splice(insertIndex, 0, snapshotConversation)
    return new ConversationApplyResult(true, sourceChanged)
  }

  private mergeAllConversationList(conversations: ConversationItem[], deletedConversationIds: Set<string>): boolean {
    const mergeResult = mergeConversationBatch(
      this.allConversationList,
      conversations,
      deletedConversationIds,
      (a: ConversationItem, b: ConversationItem): number => this.sortConversation(a, b)
    )
    if (mergeResult.changed) {
      this.allConversationList = mergeResult.conversations
    }
    return mergeResult.changed
  }

  private isSameConversationList(first: ConversationItem[], second: ConversationItem[]): boolean {
    if (first.length !== second.length) {
      return false
    }
    for (let i = 0; i < first.length; i++) {
      if (first[i] !== second[i]) {
        return false
      }
    }
    return true
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

    const customGroupSelected = this.isCustomGroupSelected()
    let sourceChanged = false
    if (customGroupSelected) {
      sourceChanged = this.mergeAllConversationList(conversations, deletedConversationIds)
    }
    const mergeResult = mergeConversationBatch(
      customGroupSelected ? this.data.conversationList : this.allConversationList,
      conversations,
      deletedConversationIds,
      (a: ConversationItem, b: ConversationItem): number => this.sortConversation(a, b)
    )

    let displayChanged = mergeResult.changed
    if (mergeResult.changed) {
      if (customGroupSelected) {
        const displayConversations = this.filterCustomGroupConversations(mergeResult.conversations)
        displayChanged = !this.isSameConversationList(this.data.conversationList, displayConversations)
        if (displayChanged) {
          this.data.conversationList = displayConversations
          this.data.reloadData()
        }
      } else {
        this.allConversationList = mergeResult.conversations
        this.reloadDefaultGroupDisplay()
      }
      this.logPerf('conversation.pending_flush.reload')
    } else {
      this.logPerf('conversation.pending_flush.no_reload')
    }
    if (displayChanged || sourceChanged) {
      this.reportConversationListCount()
      this.notifyDefaultGroupCountChange()
      this.ensureP2PUserInfo(conversations)
    }
  }

  private getAitBadgeConversationCount(): number {
    return filterConversationsByDefaultGroup(
      this.allConversationList,
      CONVERSATION_GROUP_DEFAULT_AIT_KEY,
      this.aitConversationList
    ).length
  }

  private reloadDefaultGroupDisplay(): void {
    if (this.isCustomGroupSelected()) {
      return
    }
    this.data.conversationList = filterConversationsByDefaultGroup(
      this.allConversationList,
      this.selectedConversationGroupKey,
      this.aitConversationList
    )
    this.data.reloadData()
    this.notifyDefaultGroupCountChange()
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
    this.removeFromAllConversationList(conversationIds)
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

  private findConversationInsertIndex(conversation: ConversationItem, source?: ConversationItem[]): number {
    const targetList = source ?? this.data.conversationList
    let insertIndex = targetList.length
    for (let i = 0; i < targetList.length; i++) {
      if (conversation.sortOrder > targetList[i].sortOrder) {
        insertIndex = i
        break
      }
    }
    return insertIndex
  }

  private loadAitSessions() {
    const loginUserId = ChatKitClient.getLoginUserId()
    if (loginUserId.length <= 0) {
      return
    }
    const loadSeq = ++this.aitSessionLoadSeq
    AitServer.instance.getAllAitSession(loginUserId, this.mode).then((
      aitSessions: string[]
    ) => {
      // Ignore stale AIT load results after page destroy or account switch.
      if (loadSeq !== this.aitSessionLoadSeq || ChatKitClient.getLoginUserId() !== loginUserId) {
        return
      }
      let changed = false
      aitSessions.forEach((session) => {
        if (!this.aitConversationList.has(session)) {
          this.aitConversationList.add(session)
          changed = true
        }
      })
      if (changed) {
        this.refreshDefaultGroupDisplayAfterAitChanged()
      }
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
    if (userAIBot || aiUser) {
      return resolveConversationDisplayInfo(
        conversation,
        targetId,
        userAIBot ? { name: userAIBot.name, avatar: userAIBot.icon ?? '' } : undefined,
        aiUser ? { name: aiUser.name, avatar: aiUser.avatar ?? '' } : undefined,
        { replaceName: true, replaceAvatar: true }
      )
    }
    const friendInfo = NEFriendUserCache.peekInstance()?.getFriendById(targetId)
    if (friendInfo === undefined) {
      return conversation
    }
    return resolveConversationDisplayInfo(
      conversation,
      targetId,
      { name: friendInfo.showName(), avatar: friendInfo.getAvatar() },
      undefined,
      { replaceName: true }
    )
  }

  private refreshLoadedConversationDisplayInfo(conversationId?: string): void {
    let changed = false
    const sourceList = this.isCustomGroupSelected() ? this.data.conversationList : this.allConversationList
    sourceList.forEach((conversation: ConversationItem) => {
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
      if (this.isCustomGroupSelected()) {
        this.data.reloadData()
      } else {
        this.reloadDefaultGroupDisplay()
      }
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

  private async selectCustomConversationGroup(groupId: string): Promise<void> {
    const requestSeq = ++this.customGroupLoadSeq
    this.selectedConversationGroupKey = groupId === UNREAD_GROUP_QUERY_ID ?
      CONVERSATION_GROUP_DEFAULT_UNREAD_KEY : groupId
    this.customGroupId = groupId
    this.customGroupOffset = 0
    this.customGroupFinished = false
    this.isFinished = false
    this.isLoadingCustomGroupConversation = false
    this.data.conversationList = []
    this.data.reloadData()
    await this.loadMoreCustomConversationGroup(requestSeq)
  }

  private async loadMoreCustomConversationGroup(requestSeq: number = this.customGroupLoadSeq): Promise<void> {
    if (!this.customGroupId || requestSeq !== this.customGroupLoadSeq || this.customGroupFinished) {
      return
    }
    if (this.isLoadingCustomGroupConversation && this.customGroupLoadingSeq === requestSeq) {
      return
    }
    this.isLoadingCustomGroupConversation = true
    this.customGroupLoadingSeq = requestSeq
    try {
      const option: V2NIMConversationOption = this.isUnreadGroupSelected() ? {
        onlyUnread: true
      } : {
        conversationGroupIds: [this.customGroupId]
      }
      let result = await this.model.getConversationListByOption(this.customGroupOffset, this.LOAD_MORE_LIMIT, option)
      while (result !== undefined && requestSeq === this.customGroupLoadSeq) {
        this.customGroupOffset = result.offset
        this.customGroupFinished = result.finished
        this.isFinished = result.finished
        if (result.conversationList.length > 0) {
          this.upsertConversationBatch(result.conversationList, false)
        }
        if (!this.isUnreadGroupSelected() || result.finished || this.data.totalCount() > 0) {
          break
        }
        result = await this.model.getConversationListByOption(this.customGroupOffset, this.LOAD_MORE_LIMIT, option)
        if (requestSeq !== this.customGroupLoadSeq) {
          return
        }
      }
    } finally {
      if (this.customGroupLoadingSeq === requestSeq) {
        this.isLoadingCustomGroupConversation = false
      }
    }
  }

  private isCustomGroupSelected(): boolean {
    return this.customGroupId.length > 0
  }

  private isUnreadGroupSelected(): boolean {
    return this.mode === ConversationMode.CLOUD && this.customGroupId === UNREAD_GROUP_QUERY_ID
  }

  private refreshDefaultGroupDisplayAfterAitChanged(): void {
    if (this.isCustomGroupSelected()) {
      this.notifyDefaultGroupCountChange()
      return
    }
    this.reloadDefaultGroupDisplay()
  }

  private filterCustomGroupConversations(conversations: ConversationItem[]): ConversationItem[] {
    return conversations.filter((conversation: ConversationItem): boolean =>
    this.isConversationInCurrentCustomGroup(conversation))
  }

  private isConversationInCurrentCustomGroup(conversation: ConversationItem): boolean {
    if (this.isUnreadGroupSelected()) {
      return conversation.unreadCount > 0 && conversation.mute !== true
    }
    const cloudConversation = conversation as V2NIMConversation
    return this.customGroupId.length <= 0 || (cloudConversation.groupIds?.includes(this.customGroupId) ?? false)
  }

  private removeFromAllConversationList(conversationIds: string[]): void {
    if (conversationIds.length <= 0 || this.allConversationList.length <= 0) {
      return
    }
    const deletedIds: Set<string> = new Set(conversationIds)
    this.allConversationList = this.allConversationList.filter((conversation: ConversationItem): boolean =>
    !deletedIds.has(conversation.conversationId))
    if (!this.isCustomGroupSelected()) {
      this.reloadDefaultGroupDisplay()
    }
  }

  private notifyDefaultGroupCountChange(): void {
    this.onDefaultGroupCountChange?.(this.getDefaultConversationGroupCounts())
  }
}
