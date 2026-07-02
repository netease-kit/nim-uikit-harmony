/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationIdUtilRepo, ErrorUtils, IMKitConfigCenter, UserAIBotManager } from '@nimkit/chatkit'
import { CommonEmptyResult, NetworkBrokenBuilder } from '@nimkit/common'
import { V2NIMAIUser, V2NIMConversationType } from '@nimsdk/base'
import { AitServer } from '../service/ait/AitService'
import {
  CloudConversationStrategy,
  ConversationItem,
  ConversationMode,
  LocalConversationStrategy
} from '../strategy/ConversationStrategy'
import { ConversationAIUserViewItem } from '../view/ConversationAIUserViewItem'
import { ConversationNavigationView } from '../view/ConversationNavigationView'
import { ConversationViewItem } from '../view/ConversationViewItem'
import { EndItemView } from '../view/EndItemView'
import { FraudTipView } from '../view/FraudTipView'
import { ConversationAIViewModel } from '../viewmodel/ConversationAIViewModel'
import { collectPendingSubscriptionAccounts } from '../viewmodel/ConversationUpdateUtils'
import { ConversationViewModel } from '../viewmodel/ConversationViewModel'
import { SubscriptionViewModel } from '../viewmodel/SubscriptionViewModel'

@ComponentV2
struct ConversationPageContent {
  @Param mode: ConversationMode = ConversationMode.CLOUD
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined
  @Param onConversationFirstReady?: (count: number) => void = undefined
  @Param onConversationFirstStable?: (count: number) => void = undefined
  private readonly cloudStrategy: CloudConversationStrategy = new CloudConversationStrategy()
  private readonly localStrategy: LocalConversationStrategy = new LocalConversationStrategy()
  @Local cloudViewModel: ConversationViewModel = new ConversationViewModel(this.cloudStrategy)
  @Local localViewModel: ConversationViewModel = new ConversationViewModel(this.localStrategy)
  @Local subscriptViewModel: SubscriptionViewModel = new SubscriptionViewModel()
  @Local viewModelAI: ConversationAIViewModel = new ConversationAIViewModel()
  @Local hasConversationFirstStable: boolean = false
  private scroller: ListScroller = new ListScroller()
  private pendingSubscribeAccounts: Set<string> = new Set()
  private hasRequestedAIUsersOnDemand: boolean = false

  aboutToAppear(): void {
    this.logPerf('conversation.page.appear.start')
    this.activeViewModel().onUreadMessageChange = this.onUreadMessageChange
    this.activeViewModel().onConversationFirstReady = (count: number) => {
      this.logPerf('conversation.page.first_ready_callback', `count=${count}`)
      this.onConversationFirstReady?.(count)
    }
    this.activeViewModel().onConversationListCountChange = (count: number) => {
      if (count > 0) {
        this.logPerf('conversation.page.first_visible_callback', `count=${count}`)
        this.hasConversationFirstStable = true
        this.onConversationFirstStable?.(count)
        this.refreshAIUsersFromCacheIfReady()
        this.flushPendingSubscriptionsIfReady()
      }
    }
    this.activeViewModel().onConversationSyncFinished = () => {
      this.logPerf('conversation.page.sync_finished_callback')
      this.refreshAIUsersFromCacheIfReady()
      this.flushPendingSubscriptionsIfReady()
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
    this.activeViewModel().onDestroy()
    this.viewModelAI.onDestroy()
  }

  build() {
    NavDestination() {
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

      if (this.shouldShowAIUserList()) {
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
        .height('13%')
        .backgroundColor('#ffFFFFFF')

        Row()
          .width('100%')
          .height(1)
          .backgroundColor('#E9EFF5')
      }

      if (this.activeViewModel().isFinishedSyncLoad && this.activeViewModel().data.totalCount() <= 0) {
        CommonEmptyResult({
          tips: $r('app.string.conversation_empty')
        })
          .margin({
            top: 80
          })
      } else {
        List({ scroller: this.scroller }) {
          LazyForEach(this.activeViewModel().data, (item: ConversationItem, index: number) => {
            ListItem() {
              ConversationViewItem({
                conversationInfo: item,
                haveBeanAit: this.activeViewModel().aitConversationList.has(item.conversationId),
                isUserAIBot: this.activeViewModel().userAIBotConversationList.has(item.conversationId),
                isAIUser: this.isAIUserConversation(item),
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
            .backgroundColor(item.stickTop ? '#ffF3F5F7' : '#ffffffff')
          }, (item: ConversationItem) => this.conversationItemKey(item))

          ListItem() {
            Row()
              .width('100%')
              .height('30%')
          }
        }
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
        .height(this.shouldShowAIUserList() ? '87%' : '100%')
        .backgroundColor('#ffFFFFFF')
      }
    }
    .title(this.titleBuilder)
    .backgroundColor(Color.White)
  }

  @Builder
  titleBuilder() {
    ConversationNavigationView({
      pathStack: this.pathStack,
      goSearchPage: (pathStack: NavPathStack) => {
        pathStack.pushPath({ name: 'SearchPage' })
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
        if (this.activeViewModel().requiresNetworkForDelete() && !ErrorUtils.checkNetworkAndToast()) {
          return
        }
        this.scroller.closeAllSwipeActions()
        await this.activeViewModel().deleteConversation(item.conversationId)
      },
      stickTopItem: async (stickTop: boolean) => {
        if (ErrorUtils.checkNetworkAndToast()) {
          await this.activeViewModel().stickTopConversation(item.conversationId ?? '', stickTop)
          this.scroller.closeAllSwipeActions()
        }
      }
    }).width(140)
      .backgroundColor(item.stickTop ? '#ffF3F5F7' : '#ffffffff')
  }

  private async goToChatPage(conversationInfo: ConversationItem): Promise<void> {
    if (conversationInfo?.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      const targetId = ConversationIdUtilRepo.parseConversationTargetId(conversationInfo.conversationId)
      const isUserAIBot = await UserAIBotManager.isUserAIBot(targetId)
      if (isUserAIBot) {
        const cachedBot = UserAIBotManager.getCachedUserAIBot(targetId)
        const botSubSessionParams: string[] = [
          conversationInfo.conversationId,
          targetId,
          cachedBot?.name ?? conversationInfo.name ?? targetId
        ]
        this.pathStack.pushPath({
          name: 'ChatBotSubSessionListPage',
          param: botSubSessionParams
        })
        return
      }
      this.pathStack.pushPath({ name: 'ChatP2PPage', param: conversationInfo.conversationId })
    } else if (conversationInfo?.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
      this.pathStack.pushPath({ name: 'ChatTeamPage', param: conversationInfo.conversationId })
    }
  }

  private goToAIChatPage(aiUser: V2NIMAIUser) {
    if (aiUser.accountId) {
      const aiConversationId: string = ConversationIdUtilRepo.p2pConversationId(aiUser.accountId)
      this.pathStack.pushPath({ name: 'ChatP2PPage', param: aiConversationId })
    }
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

  build() {
    ConversationPageContent({
      pathStack: this.pathStack,
      onUreadMessageChange: this.onUreadMessageChange,
      onConversationFirstReady: this.onConversationFirstReady,
      onConversationFirstStable: this.onConversationFirstStable,
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

  build() {
    ConversationPageContent({
      pathStack: this.pathStack,
      onUreadMessageChange: this.onUreadMessageChange,
      onConversationFirstReady: this.onConversationFirstReady,
      onConversationFirstStable: this.onConversationFirstStable,
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
