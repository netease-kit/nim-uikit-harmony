/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  ChatKitClient,
  ConversationIdUtilRepo,
  ErrorUtils,
  IMKitConfigCenter,
  UserAIBotManager
} from '@nimkit/chatkit'
import { CommonEmptyResult, CommonLongLoadingProgress, CustomLoadMoreBuilder, Logger, NetworkBrokenBuilder } from '@nimkit/common'
import {
  V2NIMAIUser,
  V2NIMConversationType,
  V2NIMP2PMessageMuteMode,
  V2NIMTeamMessageMuteMode,
  V2NIMTeamType
} from '@nimsdk/base'
import { ConversationGroupDefaultNames } from '../model/ConversationGroupModel'
import {
  ConversationOpenIntent,
  ConversationOpenSource,
  ConversationRouteKey,
  ConversationRouteKind
} from '../model/ConversationOpenIntent'
import { AitServer } from '../service/ait/AitService'
import {
  CloudConversationStrategy,
  ConversationItem,
  ConversationMode,
  LocalConversationStrategy
} from '../strategy/ConversationStrategy'
import { ConversationAIUserViewItem } from '../view/ConversationAIUserViewItem'
import { ConversationGroupBar } from '../view/ConversationGroupBar'
import { ConversationNavigationView } from '../view/ConversationNavigationView'
import { ConversationViewItem, resolveConversationItemBackground } from '../view/ConversationViewItem'
import { EndItemView } from '../view/EndItemView'
import { FraudTipView } from '../view/FraudTipView'
import { ConversationAIViewModel } from '../viewmodel/ConversationAIViewModel'
import { collectPendingSubscriptionAccounts } from '../viewmodel/ConversationUpdateUtils'
import { ConversationGroupViewModel } from '../viewmodel/ConversationGroupViewModel'
import { ConversationViewModel } from '../viewmodel/ConversationViewModel'
import { SubscriptionViewModel } from '../viewmodel/SubscriptionViewModel'

@ComponentV2
struct ConversationPageContent {
  @Param mode: ConversationMode = ConversationMode.CLOUD
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined
  @Param onConversationFirstReady?: (count: number) => void = undefined
  @Param onConversationFirstStable?: (count: number) => void = undefined
  @Param onOpenConversation?: (intent: ConversationOpenIntent) => void = undefined
  @Param onOpenDetail?: (info: NavPathInfo) => void = undefined
  @Param selectedConversationId: string = ''
  private readonly cloudStrategy: CloudConversationStrategy = new CloudConversationStrategy()
  private readonly localStrategy: LocalConversationStrategy = new LocalConversationStrategy()
  @Local cloudViewModel: ConversationViewModel = new ConversationViewModel(this.cloudStrategy)
  @Local localViewModel: ConversationViewModel = new ConversationViewModel(this.localStrategy)
  @Local subscriptViewModel: SubscriptionViewModel = new SubscriptionViewModel()
  @Local viewModelAI: ConversationAIViewModel = new ConversationAIViewModel()
  @Local conversationGroupViewModel: ConversationGroupViewModel = new ConversationGroupViewModel()
  @Local hasConversationFirstStable: boolean = false
  private scroller: ListScroller = new ListScroller()
  private pendingSubscribeAccounts: Set<string> = new Set()
  private hasRequestedAIUsersOnDemand: boolean = false

  @Monitor('selectedConversationId')
  onSelectedConversationChanged(): void {
    this.applyPinnedConversation(this.selectedConversationId)
  }

  private applyPinnedConversation(conversationId: string): void {
    this.cloudViewModel.setPinnedConversation(conversationId)
    this.localViewModel.setPinnedConversation(conversationId)
  }

  aboutToAppear(): void {
    this.logPerf('conversation.page.appear.start')
    this.applyPinnedConversation(this.selectedConversationId)
    this.activeViewModel().onUreadMessageChange = this.onUreadMessageChange
    this.activeViewModel().onConversationFirstReady = (count: number) => {
      this.logPerf('conversation.page.first_ready_callback', `count=${count}`)
      this.onConversationFirstReady?.(count)
    }
    this.activeViewModel().onConversationListCountChange = (count: number) => {
      if (count > 0) {
        this.logPerf('conversation.page.first_visible_callback', `count=${count}`)
        this.markConversationFirstStable(count)
        this.refreshAIUsersFromCacheIfReady()
        this.flushPendingSubscriptionsIfReady()
      }
    }
    this.activeViewModel().onConversationSyncFinished = () => {
      this.logPerf('conversation.page.sync_finished_callback')
      if (!this.hasConversationFirstStable) {
        // Empty conversation lists should still allow pinned AI users to appear.
        this.markConversationFirstStable(this.activeViewModel().data.totalCount())
      }
      this.conversationGroupViewModel.updateDefaultCounts(this.activeViewModel().getDefaultConversationGroupCounts())
      this.refreshAIUsersFromCacheIfReady()
      this.flushPendingSubscriptionsIfReady()
    }
    this.activeViewModel().onDefaultGroupCountChange = (counts) => {
      this.conversationGroupViewModel.updateDefaultCounts(counts)
    }
    if (this.shouldShowConversationGroupBar()) {
      this.conversationGroupViewModel.setDefaultNames(this.resolveDefaultGroupNames())
      this.conversationGroupViewModel.onSelectedGroupDeleted = async (group) => {
        await this.activeViewModel().selectConversationGroup(group)
      }
      this.conversationGroupViewModel.onCustomGroupMembersChanged = async (groupId: string) => {
        await this.activeViewModel().reloadSelectedCustomGroupIfNeeded(groupId)
      }
      this.conversationGroupViewModel.initConversationGroups(this.activeViewModel().getDefaultConversationGroupCounts())
    }
    this.logPerf('conversation.page.ait_init.start')
    AitServer.instance.init(this.mode)
    this.logPerf('conversation.page.ait_init.end')
    this.activeViewModel().initConversation()
    this.viewModelAI.initAIUsers()
    this.logPerf('conversation.page.appear.end')
  }

  aboutToDisappear(): void {
    this.logPerf('conversation.page.disappear')
    this.pendingSubscribeAccounts.clear()
    this.hasRequestedAIUsersOnDemand = false
    this.activeViewModel().onConversationSyncFinished = undefined
    this.activeViewModel().onDefaultGroupCountChange = undefined
    this.activeViewModel().onDestroy()
    this.viewModelAI.onDestroy()
    if (this.shouldShowConversationGroupBar()) {
      this.conversationGroupViewModel.onDestroy()
    }
  }

  build() {
    NavDestination() {
      Column() {
        Column() {
          FraudTipView({
            pathStack: this.pathStack,
            canReport: false,
            canCancel: false
          })

          if (this.activeViewModel().networkBroken) {
            NetworkBrokenBuilder()
          }
        }
        .width('100%')
        .zIndex(10)

        List({ scroller: this.scroller }) {
          if (this.shouldShowAIUserList()) {
            ListItem() {
              this.aiUserListBuilder()
            }
            .height(83)
            .backgroundColor('#ffFFFFFF')
          }

          if (this.shouldShowConversationGroupBar()) {
            ListItemGroup({ header: this.conversationGroupBarBuilder() }) {
              this.conversationListContentBuilder()
            }
          } else {
            this.conversationListContentBuilder()
          }
        }
        .sticky(StickyStyle.Header)
        .listDirection(Axis.Vertical)
        .onReachEnd(() => {
          if (this.activeViewModel().isFinishedSyncLoad &&
            this.activeViewModel().data.totalCount() > 0 &&
            !this.activeViewModel().isFinished) {
            this.activeViewModel().loadMoreConversation()
          }
        })
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#ffFFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#ffFFFFFF')
    }
    .title(this.titleBuilder)
    .backgroundColor(Color.White)
  }

  @Builder
  private aiUserListBuilder() {
    Column() {
      List() {
        ForEach(this.viewModelAI.aiUsers, (item: V2NIMAIUser) => {
          ListItem() {
            ConversationAIUserViewItem({
              aiUserInfo: item,
              onItemClick: () => {
                this.goToAIChatPage(item)
              }
            })
          }
        })
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(82)
      .backgroundColor('#ffFFFFFF')

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#E9EFF5')
    }
    .width('100%')
    .height(83)
    .backgroundColor('#ffFFFFFF')
  }

  @Builder
  private conversationGroupBarBuilder() {
    ConversationGroupBar({
      viewModel: this.conversationGroupViewModel,
      onGroupClick: async (group) => {
        this.conversationGroupViewModel.selectGroup(group)
        await this.activeViewModel().selectConversationGroup(group)
      },
      onManageClick: () => {
        this.openDetail({
          name: 'ConversationGroupManagePage',
          param: this.conversationGroupViewModel
        })
      }
    })
  }

  @Builder
  private conversationListContentBuilder() {
    // 「未读 / @我」分组按未读数据过滤，首屏没有未读时过滤结果可能为空，但角标来自服务端聚合计数。
    // 这种「假空」状态下不能直接显示空态，要显示 loading，由 viewmodel 逐页补拉。
    if (this.activeViewModel().isFinishedSyncLoad && this.activeViewModel().data.totalCount() <= 0 &&
      !this.activeViewModel().isRefillingGroup) {
      ListItem() {
        Column() {
          CommonEmptyResult({
            tips: $r('app.string.conversation_empty')
          })
            .margin({
              top: 80
            })
        }
        .width('100%')
        .height(360)
        .backgroundColor('#ffFFFFFF')
      }
    } else if ((!this.activeViewModel().isFinishedSyncLoad || this.activeViewModel().isRefillingGroup) &&
      this.activeViewModel().data.totalCount() <= 0) {
      ListItem() {
        Column() {
          CommonLongLoadingProgress()
        }
        .width('100%')
        .height(360)
        .backgroundColor('#ffFFFFFF')
      }
    } else {
      LazyForEach(this.activeViewModel().data, (item: ConversationItem, index: number) => {
        this.conversationItemBuilder(item, index)
      }, (item: ConversationItem) => this.conversationItemKey(item))

      if (this.shouldShowBottomSpacer()) {
        ListItem() {
          Column() {
            if (this.shouldShowLoadMoreFooter()) {
              CustomLoadMoreBuilder({
                isVisibleLoadMore: true
              })
            }

            // 列表底部留白：2in1/桌面窗口下窗口底边会吃掉约 20vp，
            // 留白给到 50vp，保证最后一条会话能完整滚进视口。
            Row()
              .width('100%')
              .height(50)
              .backgroundColor('#ffFFFFFF')
          }
        }
      }
    }
  }

  @Builder
  private conversationItemBuilder(item: ConversationItem, index: number) {
    ListItem() {
      ConversationViewItem({
        conversationInfo: item,
        avatarName: this.activeViewModel().getConversationAvatarName(item),
        haveBeanAit: this.activeViewModel().aitConversationList.has(item.conversationId),
        isUserAIBot: this.activeViewModel().userAIBotConversationList.has(item.conversationId),
        isAIUser: this.isAIUserConversation(item),
        isSelected: this.selectedConversationId === item.conversationId,
        onContextAction: (action: string) => {
          if (action === 'stickTop') {
            this.stickTopConversation(item, true)
          } else if (action === 'unstickTop') {
            this.stickTopConversation(item, false)
          } else if (action === 'mute') {
            this.setConversationMute(item, true)
          } else if (action === 'unmute') {
            this.setConversationMute(item, false)
          } else if (action === 'delete') {
            this.deleteConversation(item)
          }
        },
        onItemClick: () => {
          this.goToChatPage(item)
        },
        onlineState: this.subscriptViewModel.getOnlineState(this.getConversationTargetId(item))
      })
        .onAppear(() => {
          if (item.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
            this.enqueueSubscribeUserStatus(this.getConversationTargetId(item))
            this.activeViewModel().ensureUserAIBotConversation(item)
          }
        })
    }
    .swipeAction({
      end: {
        builder: () => {
          this.endItemBuilder(item, index)
        },
        onAction: () => {
          this.getUIContext()?.animateTo({ duration: 1000 }, async () => {
            this.scroller.closeAllSwipeActions()
          })
        },
        actionAreaDistance: 112
      }
    })
    .backgroundColor(resolveConversationItemBackground(
      this.selectedConversationId === item.conversationId,
      item.stickTop
    ))
  }

  private shouldShowLoadMoreFooter(): boolean {
    const viewModel = this.activeViewModel()
    if (viewModel.data.totalCount() <= 0 || viewModel.isFinished) {
      return false
    }
    return !viewModel.isFinishedSyncLoad || viewModel.isLoadingMoreConversationActive()
  }

  private shouldShowBottomSpacer(): boolean {
    const viewModel = this.activeViewModel()
    return viewModel.data.totalCount() > 0
  }

  @Builder
  titleBuilder() {
    ConversationNavigationView({
      pathStack: this.pathStack,
      onOpenConversation: this.onOpenConversation,
      onOpenDetail: this.onOpenDetail,
      goSearchPage: (pathStack: NavPathStack) => {
        this.openDetail({ name: 'SearchPage' })
      }
    })
  }

  private activeViewModel(): ConversationViewModel {
    if (this.mode === ConversationMode.LOCAL) {
      return this.localViewModel
    }
    return this.cloudViewModel
  }

  private shouldShowAIUserList(): boolean {
    return IMKitConfigCenter.enableAI &&
      this.hasConversationFirstStable === true &&
      this.viewModelAI.isFinishedSyncLoad === true &&
      (this.viewModelAI.aiUsers?.length ?? 0) > 0
  }

  private shouldShowConversationGroupBar(): boolean {
    return this.mode === ConversationMode.CLOUD
  }

  private markConversationFirstStable(count: number): void {
    if (this.hasConversationFirstStable) {
      return
    }
    this.hasConversationFirstStable = true
    this.onConversationFirstStable?.(count)
  }

  private resolveDefaultGroupNames(): ConversationGroupDefaultNames {
    const resourceManager = getContext(this).resourceManager
    return new ConversationGroupDefaultNames(
      resourceManager.getStringSync($r('app.string.conversation_group_default_all').id),
      resourceManager.getStringSync($r('app.string.conversation_group_default_ait').id),
      resourceManager.getStringSync($r('app.string.conversation_group_default_unread').id)
    )
  }

  private refreshAIUsersFromCacheIfReady(): void {
    if (!IMKitConfigCenter.enableAI) {
      this.logPerf('conversation.page.ai_cache.skip_disabled')
      return
    }
    if (!this.hasConversationFirstStable) {
      this.logPerf('conversation.page.ai_cache.defer_first_visible')
      return
    }
    if (!this.activeViewModel().isFinishedSyncLoad) {
      this.logPerf('conversation.page.ai_cache.defer_sync')
      return
    }
    this.logPerf('conversation.page.ai_cache.refresh')
    this.viewModelAI.refreshAIUsersFromCache()
    if (!this.hasRequestedAIUsersOnDemand && (this.viewModelAI.aiUsers?.length ?? 0) <= 0) {
      this.hasRequestedAIUsersOnDemand = true
      this.logPerf('conversation.page.ai_ondemand.load')
      this.viewModelAI.loadAIUsersOnDemand()
    }
  }

  private enqueueSubscribeUserStatus(accountId: string): void {
    if (!accountId) {
      return
    }
    this.pendingSubscribeAccounts.add(accountId)
    if (!this.hasConversationFirstStable) {
      this.logPerf('conversation.page.subscribe.defer', `pending=${this.pendingSubscribeAccounts.size}`)
      return
    }
    this.flushPendingSubscriptionsIfReady()
  }

  private flushPendingSubscriptionsIfReady(): void {
    if (!this.hasConversationFirstStable) {
      this.logPerf('conversation.page.subscribe.defer_first_visible',
        `pending=${this.pendingSubscribeAccounts.size}`)
      return
    }
    if (!this.activeViewModel().isFinishedSyncLoad) {
      this.logPerf('conversation.page.subscribe.defer_sync',
        `pending=${this.pendingSubscribeAccounts.size}`)
      return
    }
    if (this.pendingSubscribeAccounts.size <= 0) {
      this.logPerf('conversation.page.subscribe.skip',
        `pending=${this.pendingSubscribeAccounts.size}`)
      return
    }
    const accountIds = collectPendingSubscriptionAccounts(this.pendingSubscribeAccounts)
    this.logPerf('conversation.page.subscribe.start', `count=${accountIds.length}`)
    this.subscriptViewModel.subscribeUserStatusBatch(accountIds)
  }

  private logPerf(_stage: string, _detail: string = ''): void {
  }

  @Builder
  endItemBuilder(item: ConversationItem, index: number) {
    EndItemView({
      conversationInfo: item,
      deleteItem: async () => {
        await this.deleteConversation(item)
      },
      stickTopItem: async (stickTop: boolean) => {
        await this.stickTopConversation(item, stickTop)
      }
    }).width(140)
      .backgroundColor(item.stickTop ? '#ffF3F5F7' : '#ffffffff')
  }

  /**
   * 会话消息免打扰：单聊走点对点免打扰模式，群聊按群类型走群消息免打扰模式。
   */
  private async setConversationMute(item: ConversationItem, mute: boolean): Promise<void> {
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    const settingService = ChatKitClient.nim.settingService
    const targetId = this.getConversationTargetId(item)
    if (!settingService || targetId.length === 0) {
      return
    }
    try {
      if (item.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        await settingService.setP2PMessageMuteMode(targetId, mute ?
          V2NIMP2PMessageMuteMode.V2NIM_P2P_MESSAGE_MUTE_MODE_ON :
          V2NIMP2PMessageMuteMode.V2NIM_P2P_MESSAGE_MUTE_MODE_OFF)
      } else if (item.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM ||
        item.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_SUPER_TEAM) {
        await settingService.setTeamMessageMuteMode(targetId,
          item.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_SUPER_TEAM ?
            V2NIMTeamType.V2NIM_TEAM_TYPE_SUPER : V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
          mute ? V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_ON :
            V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_OFF)
      }
      this.scroller.closeAllSwipeActions()
    } catch (e) {
      Logger.error('ConversationKit', `setConversationMute failed: ${e}`)
    }
  }

  private async deleteConversation(item: ConversationItem): Promise<void> {
    if (this.activeViewModel().requiresNetworkForDelete() && !ErrorUtils.checkNetworkAndToast()) {
      return
    }
    this.scroller.closeAllSwipeActions()
    await this.activeViewModel().deleteConversation(item.conversationId)
  }

  private async stickTopConversation(item: ConversationItem, stickTop: boolean): Promise<void> {
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    await this.activeViewModel().stickTopConversation(item.conversationId ?? '', stickTop)
    this.scroller.closeAllSwipeActions()
  }

  private async goToChatPage(conversationInfo: ConversationItem): Promise<void> {
    if (conversationInfo?.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      const targetId = ConversationIdUtilRepo.parseConversationTargetId(conversationInfo.conversationId)
      const isUserAIBot = await UserAIBotManager.isUserAIBot(targetId)
      if (isUserAIBot) {
        const cachedBot = UserAIBotManager.getCachedUserAIBot(targetId)
        const displayName = cachedBot?.name ?? conversationInfo.name ?? targetId
        const intent = new ConversationOpenIntent(
          new ConversationRouteKey(ConversationRouteKind.BOT_SUB_SESSION_LIST, conversationInfo.conversationId),
          ConversationOpenSource.CONVERSATION_LIST,
          targetId,
          displayName
        )
        if (this.onOpenConversation) {
          this.onOpenConversation(intent)
        } else {
          this.pathStack.pushPath({
            name: 'ChatBotSubSessionListPage',
            param: [conversationInfo.conversationId, targetId, displayName]
          })
        }
        return
      }
      this.openConversation(new ConversationOpenIntent(
        new ConversationRouteKey(ConversationRouteKind.P2P, conversationInfo.conversationId),
        ConversationOpenSource.CONVERSATION_LIST
      ), 'ChatP2PPage')
    } else if (conversationInfo?.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM ||
      conversationInfo?.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_SUPER_TEAM) {
      const kind = conversationInfo.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_SUPER_TEAM ?
        ConversationRouteKind.SUPER_TEAM : ConversationRouteKind.TEAM
      this.openConversation(new ConversationOpenIntent(
        new ConversationRouteKey(kind, conversationInfo.conversationId),
        ConversationOpenSource.CONVERSATION_LIST
      ), 'ChatTeamPage')
    }
  }

  private goToAIChatPage(aiUser: V2NIMAIUser) {
    if (aiUser.accountId) {
      const aiConversationId: string = ConversationIdUtilRepo.p2pConversationId(aiUser.accountId)
      this.openConversation(new ConversationOpenIntent(
        new ConversationRouteKey(ConversationRouteKind.P2P, aiConversationId),
        ConversationOpenSource.AI_ENTRY
      ), 'ChatP2PPage')
    }
  }

  private openConversation(intent: ConversationOpenIntent, fallbackRouteName: string): void {
    if (this.onOpenConversation) {
      this.onOpenConversation(intent)
      return
    }
    this.pathStack.pushPath({ name: fallbackRouteName, param: intent.key.conversationId })
  }

  private openDetail(info: NavPathInfo): void {
    if (this.onOpenDetail) {
      this.onOpenDetail(info)
      return
    }
    this.pathStack.pushPath(info)
  }

  private conversationItemKey(item: ConversationItem): string {
    const lastMessage = item.lastMessage
    const previewText = (lastMessage?.text ?? '').substring(0, 64)
    return `${item.conversationId}|${item.sortOrder}|${item.unreadCount}|${item.updateTime}|` +
      `${item.mute ? 1 : 0}|${item.stickTop ? 1 : 0}|${item.name ?? ''}|${item.avatar ?? ''}|` +
      `${this.activeViewModel().userAIBotConversationList.has(item.conversationId) ? 1 : 0}|` +
      `${this.isAIUserConversation(item) ? 1 : 0}|` +
      `${lastMessage?.messageType ?? ''}|${lastMessage?.subType ?? ''}|` +
      `${lastMessage?.messageRefer?.messageClientId ?? ''}|${lastMessage?.messageRefer?.messageServerId ?? ''}|` +
      `${lastMessage?.messageRefer?.createTime ?? 0}|${lastMessage?.sendingState ?? ''}|${previewText}`
      // 注意：不要把"是否选中"放进 key。选中态只影响行背景色，由 @Param isSelected 驱动重渲染即可；
      // 放进 key 会让切换选中时该行被销毁重建，头像随之重建（先闪名字兜底再淡入图片）。
      // 也不能去掉未读数/预览/时间等内容字段：这些更新大量走 reloadData，key 不变时行不会重新构建，
      // 会出现"进了会话出来未读数不变"的错误。
  }

  private getConversationTargetId(item: ConversationItem): string {
    return ConversationIdUtilRepo.parseConversationTargetId(item.conversationId)
  }

  private isAIUserConversation(item: ConversationItem): boolean {
    return item.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P &&
      this.viewModelAI.aiUserAccountIds.includes(this.getConversationTargetId(item))
  }
}

@ComponentV2
export struct ConversationPage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined
  @Param onConversationFirstReady?: (count: number) => void = undefined
  @Param onConversationFirstStable?: (count: number) => void = undefined
  @Param onOpenConversation?: (intent: ConversationOpenIntent) => void = undefined
  @Param onOpenDetail?: (info: NavPathInfo) => void = undefined
  @Param selectedConversationId: string = ''

  build() {
    ConversationPageContent({
      pathStack: this.pathStack,
      onUreadMessageChange: this.onUreadMessageChange,
      onConversationFirstReady: this.onConversationFirstReady,
      onConversationFirstStable: this.onConversationFirstStable,
      onOpenConversation: this.onOpenConversation,
      onOpenDetail: this.onOpenDetail,
      selectedConversationId: this.selectedConversationId,
      mode: ConversationMode.CLOUD
    })
  }
}

@ComponentV2
export struct LocalConversationPage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined
  @Param onConversationFirstReady?: (count: number) => void = undefined
  @Param onConversationFirstStable?: (count: number) => void = undefined
  @Param onOpenConversation?: (intent: ConversationOpenIntent) => void = undefined
  @Param onOpenDetail?: (info: NavPathInfo) => void = undefined
  @Param selectedConversationId: string = ''

  build() {
    ConversationPageContent({
      pathStack: this.pathStack,
      onUreadMessageChange: this.onUreadMessageChange,
      onConversationFirstReady: this.onConversationFirstReady,
      onConversationFirstStable: this.onConversationFirstStable,
      onOpenConversation: this.onOpenConversation,
      onOpenDetail: this.onOpenDetail,
      selectedConversationId: this.selectedConversationId,
      mode: ConversationMode.LOCAL
    })
  }
}

@Builder
export function ConversationPageBuilder() {
  ConversationPage()
}

@Builder
export function LocalConversationPageBuilder() {
  LocalConversationPage()
}
