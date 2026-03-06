/**
 * LocalConversationPage
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−06-03
 *
 * Copyright © 2025 Netease. All rights reserved.
 */

import { ConversationIdUtilRepo, ErrorUtils, IMKitConfigCenter } from '@nimkit/chatkit'
import { CommonEmptyResult, NetworkBrokenBuilder } from '@nimkit/common'
import { V2NIMAIUser, V2NIMConversationType, V2NIMLocalConversation } from '@nimsdk/base'
import { AitServer } from '../service/ait/AitService'
import { ConversationViewItem } from '../view/ConversationViewItem'
import { EndItemView } from '../view/EndItemView'
import { FraudTipView } from '../view/FraudTipView'
import { LocalConversationAIUserViewItem } from '../view/LocalConversationAIUserViewItem'
import { LocalConversationNavigationView } from '../view/LocalConversationNavigationView'
import { LocalConversationAIViewModel } from '../viewmodel/LocalConversationAIViewModel'
import { LocalConversationViewModel } from '../viewmodel/LocalConversationViewModel'
import { SubscriptionViewModel } from '../viewmodel/SubscriptionViewModel'

@ComponentV2
export struct LocalConversationPage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined
  private viewModel: LocalConversationViewModel = new LocalConversationViewModel()
  private subscriptViewModel: SubscriptionViewModel = new SubscriptionViewModel()
  private viewModelAI: LocalConversationAIViewModel = new LocalConversationAIViewModel()
  private scroller: ListScroller = new ListScroller();

  aboutToAppear(): void {
    this.viewModel.onUreadMessageChange = this.onUreadMessageChange
    //初始化@ 服务
    AitServer.instance.init()
    this.viewModel.initConversation()
    this.viewModelAI.initAIUsers()
  }

  build() {
    NavDestination() {
      // 防诈条和断网条
      Column() {
        // 防诈条
        FraudTipView({
          pathStack: this.pathStack,
          canReport: false,
          canCancel: false
        })

        // 断网条 - 仅在断网时显示
        if (this.viewModel.networkBroken) {
          NetworkBrokenBuilder()
        }
      }
      .width('100%')
      .zIndex(10)

      // ai 数字人列表
      if (IMKitConfigCenter.enableAI && this.viewModelAI.isFinishedSyncLoad) {
        // 置顶数字人列表，可横向滑动
        List() {
          ForEach(this.viewModelAI.aiUsers, (item: V2NIMAIUser) => {
            ListItem() {
              LocalConversationAIUserViewItem({
                aiUserInfo: item,
                onItemClick: () => {
                  // goto ChatPage
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

        // ai 数字人分割线
        Row()
          .width('100%')
          .height(1)
          .backgroundColor('#E9EFF5')
      }

      if (this.viewModel.isFinishedSyncLoad && this.viewModel.data.totalCount() <= 0) {
        CommonEmptyResult({
          tips: $r('app.string.conversation_empty')
        }).margin({
          top: 80
        })
      } else {
        List({ scroller: this.scroller }) {
          LazyForEach(this.viewModel.data, (item: V2NIMLocalConversation, index: number) => {
            ListItem() {
              ConversationViewItem({
                conversationInfo: item,
                haveBeanAit: this.viewModel.aitConversationList.has(item.conversationId),
                onItemClick: () => {
                  this.goToChatPage(item)
                },
                onlineState: this.subscriptViewModel.onlineStateMap.get(ConversationIdUtilRepo.parseConversationTargetId(item.conversationId))
              }).onAppear(() => {
                if (item.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
                  this.subscriptViewModel.subscribeUserStatus(ConversationIdUtilRepo.parseConversationTargetId(item.conversationId))
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
                  });
                },
                actionAreaDistance: 112
              }
            })
            .backgroundColor(item.stickTop ? '#ffF3F5F7' : '#ffffffff')
          }, (item: V2NIMLocalConversation) => JSON.stringify(item))

          // 底部留白，防止最后一个会话被底部tab遮挡
          ListItem() {
            Row()
              .width('100%')
              .height('30%')
          }
        }
        .listDirection(Axis.Vertical)
        .onReachEnd(() => {
          if (this.viewModel.data.totalCount() > 0 && !this.viewModel.isFinished) {
            this.viewModel.loadMoreConversation()
          }
        })
        .cachedCount(5)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(
          (IMKitConfigCenter.enableAI) ? '87%' : '100%')
        .backgroundColor('#ffFFFFFF')
      }
    }
    .title(this.titleBuilder)
    .backgroundColor(Color.White)
  }

  /**
   * 跳转到聊天页面
   */
  goToChatPage(conversationInfo: V2NIMLocalConversation) {
    if (conversationInfo?.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      this.pathStack.pushPath({ name: "ChatP2PPage", param: conversationInfo.conversationId })
    } else if (conversationInfo?.type == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
      this.pathStack.pushPath({ name: "ChatTeamPage", param: conversationInfo.conversationId })
    }
  }

  /**
   * 跳转到 AI 数字人聊天页面
   */
  goToAIChatPage(aiUser: V2NIMAIUser) {
    if (aiUser.accountId) {
      const aiConversationId: string = ConversationIdUtilRepo.p2pConversationId(aiUser.accountId)
      this.pathStack.pushPath({ name: "ChatP2PPage", param: aiConversationId })
    }
  }

  @Builder
  titleBuilder() {
    LocalConversationNavigationView({
      pathStack: this.pathStack,
      goSearchPage: (pathStack: NavPathStack) => {
        pathStack.pushPath({ name: "SearchPage" })
      }
    })
  }

  @Builder
  endItemBuilder(item: V2NIMLocalConversation, index: number) {
    EndItemView({
      conversationInfo: item,
      deleteItem: async () => {
        // 本地会话删除不依赖网络，移除网络检查
        this.scroller.closeAllSwipeActions();
        this.viewModel.deleteConversation(item.conversationId)
      },
      stickTopItem: (stickTop: boolean) => {
        if (ErrorUtils.checkNetworkAndToast()) {
          this.scroller.closeAllSwipeActions();
          this.viewModel.stickTopConversation(item.conversationId ?? '', stickTop)
        }
      }
    }).width(140)
      .backgroundColor(item.stickTop ? '#ffF3F5F7' : '#ffffffff')
  }
}

// 跳转页面入口函数
@Builder
export function LocalConversationPageBuilder() {
  LocalConversationPage()
}