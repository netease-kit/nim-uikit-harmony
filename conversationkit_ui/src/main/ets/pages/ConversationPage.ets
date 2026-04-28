/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationIdUtilRepo, ErrorUtils, IMKitConfigCenter } from '@nimkit/chatkit'
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
import { ConversationViewModel } from '../viewmodel/ConversationViewModel'
import { SubscriptionViewModel } from '../viewmodel/SubscriptionViewModel'

@ComponentV2
struct ConversationPageContent {
  @Param mode: ConversationMode = ConversationMode.CLOUD
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined
  private readonly cloudStrategy: CloudConversationStrategy = new CloudConversationStrategy()
  private readonly localStrategy: LocalConversationStrategy = new LocalConversationStrategy()
  @Local cloudViewModel: ConversationViewModel = new ConversationViewModel(this.cloudStrategy)
  @Local localViewModel: ConversationViewModel = new ConversationViewModel(this.localStrategy)
  @Local subscriptViewModel: SubscriptionViewModel = new SubscriptionViewModel()
  @Local viewModelAI: ConversationAIViewModel = new ConversationAIViewModel()
  private scroller: ListScroller = new ListScroller()

  aboutToAppear(): void {
    this.activeViewModel().onUreadMessageChange = this.onUreadMessageChange
    AitServer.instance.init(this.mode)
    this.activeViewModel().initConversation()
    this.viewModelAI.initAIUsers()
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

      if (IMKitConfigCenter.enableAI && this.viewModelAI.isFinishedSyncLoad) {
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
                onItemClick: () => {
                  this.goToChatPage(item)
                },
                onlineState: this.subscriptViewModel.onlineStateMap.get(ConversationIdUtilRepo.parseConversationTargetId(
                  item.conversationId))
              })
                .onAppear(() => {
                  if (item.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
                    this.subscriptViewModel.subscribeUserStatus(ConversationIdUtilRepo.parseConversationTargetId(
                      item.conversationId))
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
          if (this.activeViewModel().data.totalCount() > 0 && !this.activeViewModel().isFinished) {
            this.activeViewModel().loadMoreConversation()
          }
        })
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(IMKitConfigCenter.enableAI ? '87%' : '100%')
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

  private goToChatPage(conversationInfo: ConversationItem) {
    if (conversationInfo?.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
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
      `${lastMessage?.messageType ?? ''}|${lastMessage?.subType ?? ''}|` +
      `${lastMessage?.messageRefer?.messageClientId ?? ''}|${lastMessage?.messageRefer?.messageServerId ?? ''}|` +
      `${lastMessage?.messageRefer?.createTime ?? 0}|${lastMessage?.sendingState ?? ''}|${previewText}`
  }
}

@ComponentV2
export struct ConversationPage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined

  build() {
    ConversationPageContent({
      pathStack: this.pathStack,
      onUreadMessageChange: this.onUreadMessageChange,
      mode: ConversationMode.CLOUD
    })
  }
}

@ComponentV2
export struct LocalConversationPage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined

  build() {
    ConversationPageContent({
      pathStack: this.pathStack,
      onUreadMessageChange: this.onUreadMessageChange,
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
