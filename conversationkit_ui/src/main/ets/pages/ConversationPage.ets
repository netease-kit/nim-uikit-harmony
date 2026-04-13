/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  ChatKitClient,
  ChatRepo,
  ConversationIdUtilRepo,
  ErrorUtils,
  IMKitConfigCenter,
  NEUserWithFriend,
  PersonSelectParam,
  TeamRepo
} from '@nimkit/chatkit';
import { CommonEmptyResult, NECommonUtils, NetworkBrokenBuilder } from '@nimkit/common';
import { V2NIMAIUser, V2NIMConversation, V2NIMConversationType, V2NIMUserAIBot } from '@nimsdk/base';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { AitServer } from '../service/ait/AitService';
import { ConversationAIUserViewItem } from '../view/ConversationAIUserViewItem';
import { ConversationViewItem } from '../view/ConversationViewItem';
import { EndItemView } from '../view/EndItemView';
import { FraudTipView } from '../view/FraudTipView';
import { ConversationAIViewModel } from '../viewmodel/ConversationAIViewModel';
import { ConversationViewModel } from '../viewmodel/ConversationViewModel';
import { SubscriptionViewModel } from '../viewmodel/SubscriptionViewModel';

@ComponentV2
export struct ConversationPage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined
  private viewModel: ConversationViewModel = new ConversationViewModel()
  private subscriptViewModel: SubscriptionViewModel = new SubscriptionViewModel()
  private viewModelAI: ConversationAIViewModel = new ConversationAIViewModel()
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

      // AI 数字人列表
      if (IMKitConfigCenter.enableAI && this.viewModelAI.isFinishedSyncLoad) {
        // 置顶数字人列表，可横向滑动
        List() {
          ForEach(this.viewModelAI.aiUsers, (item: V2NIMAIUser) => {
            ListItem() {
              ConversationAIUserViewItem({
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
        // .onReachEnd(() => { // 不需要拉取更多数据
        //   if (this.viewModelAI.conversationList &&
        //     this.viewModelAI.conversationList.length > 0 &&
        //     !this.viewModelAI.isFinished) {
        //     this.viewModelAI.loadConversation()
        //   }
        // })
        .scrollBar(BarState.Off)
        .width('100%')
        .height('13%')
        .backgroundColor('#ffFFFFFF')

        // ai 数字人分割线
        Row()
          .width('100%')
          .height(1)
          .backgroundColor("#E9EFF5")
      }

      if (this.viewModel.isFinishedSyncLoad && this.viewModel.data.totalCount() <= 0) {
        CommonEmptyResult({
          tips: $r('app.string.conversation_empty')
        }).margin({
          top: 80
        })
      } else {
        // 会话列表
        List({ scroller: this.scroller }) {
          LazyForEach(this.viewModel.data, (item: V2NIMConversation, index: number) => {
            ListItem() {
              ConversationViewItem({
                conversationInfo: item,
                haveBeanAit: this.viewModel.aitConversationList.has(item.conversationId),
                onItemClick: () => {
                  this.goToChatPage(item)
                },
                onlineState: this.subscriptViewModel.onlineStateMap.get(ConversationIdUtilRepo.parseConversationTargetId(item.conversationId))
              })
                .onAppear(() => {
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
          }, (item: V2NIMConversation) => JSON.stringify(item))

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
        .height(IMKitConfigCenter.enableAI ? '87%' : '100%')
        .backgroundColor('#ffFFFFFF')
      }
    }
    .title(this.titleBuilder)
    .backgroundColor(Color.White)
  }

  @Builder
  titleBuilder() {
    ConversationNavigationTitleBar({
      pathStack: this.pathStack
    })
  }

  @Builder
  endItemBuilder(item: V2NIMConversation, index: number) {
    EndItemView({
      conversationInfo: item,
      deleteItem: async () => {
        if (ErrorUtils.checkNetworkAndToast()) {
          await this.viewModel.deleteConversation(item.conversationId)
          this.scroller.closeAllSwipeActions();
        }
      },
      stickTopItem: async (stickTop: boolean) => {
        if (ErrorUtils.checkNetworkAndToast()) {
          await this.viewModel.stickTopConversation(item.conversationId ?? '', stickTop)
          this.scroller.closeAllSwipeActions();
        }
      }
    }).width(140)
      .backgroundColor(item.stickTop ? '#ffF3F5F7' : '#ffffffff')
  }

  /**
   * 跳转到聊天页面
   */
  goToChatPage(conversationInfo: V2NIMConversation) {
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
}

@ComponentV2
struct ConversationNavigationTitleBar {
  @Local conversationPopupShowed: boolean = false
  @Param pathStack: NavPathStack = new NavPathStack()

  build() {
    Column({ space: 10 }) {
      Row() {
        //标题栏左侧图标
        Image($r('app.media.brand'))
          .margin({ left: 20 })
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
        //标题栏左侧文字
        Text($r('app.string.conversation_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .height(32)
          .width('100%')
          .margin({ left: 12, right: 12 })
          .layoutWeight(2)
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })


        Row()
          .height(1)
          .layoutWeight(1)

        //标题栏右侧搜索图标
        Image($r('app.media.nav_search'))
          .width(32)
          .height(32)
          .padding({
            left: 3,
            right: 3,
            top: 3,
            bottom: 3
          })
          .margin({ right: 10 })
          .onClick(() => {
            //点击去搜索
            this.goSearchPage(this.pathStack)
          })

        //标题栏右侧更多按钮图标
        Image($r('app.media.nav_add'))
          .width(32)
          .height(32)
          .padding({
            left: 3,
            right: 3,
            top: 3,
            bottom: 3
          })
          .margin({ right: 20 })
          .onClick(() => {
            this.conversationPopupShowed = !this.conversationPopupShowed
          })
          .bindPopup(this.conversationPopupShowed,
            //右侧更多操作弹框
            {
              targetSpace: 'popupLocation',
              builder: this.popupBuilder,
              placement: Placement.Bottom,
              mask: true,
              popupColor: Color.White,
              enableArrow: false,
              showInSubWindow: false,
              autoCancel: true,
              onStateChange: (e) => {
                if (!e.isVisible) {
                  this.conversationPopupShowed = false
                }
              }
            })

      }
      .height(55)
      .alignSelf(ItemAlign.Start)

      Row()
        .width('100%')
        .height(1)
        .backgroundColor("#E9EFF5")
    }
    .height('100%')
    .width('100%')
  }

  @Builder
  popupBuilder() {
    Column({ space: 16 }) {
      //添加好友
      Row() {
        Image($r('app.media.friend_add'))
          .width(14)
          .height(14)
        Text($r('app.string.add_friend'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }.onClick(() => {
        if (this.conversationPopupShowed) {
          this.conversationPopupShowed = false
          this.goAddFriend(this.pathStack)
        }
      })

      //创建讨论组
      Row() {
        Image($r('app.media.team_discuss'))
          .width(14)
          .height(14)
        Text($r('app.string.create_discuss_team'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }.onClick(() => {
        if (this.conversationPopupShowed) {
          this.conversationPopupShowed = false
          this.goToPersonSelectPage(this.pathStack, true)
        }
      })

      //创建高级群
      Row() {
        Image($r("app.media.team_advance"))
          .width(14)
          .height(14)
        Text($r('app.string.create_advance_team'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }.onClick(() => {
        if (this.conversationPopupShowed) {
          this.conversationPopupShowed = false
          this.goToPersonSelectPage(this.pathStack, false)
        }
      })

      //扫一扫
      Row() {
        Image($r('app.media.nav_scan'))
          .width(14)
          .height(14)
        Text('扫一扫')
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }.onClick(() => {
        if (this.conversationPopupShowed) {
          this.conversationPopupShowed = false
          this.doScan()
        }
      })
    }
    .width(122)
    .padding({
      top: 16,
      left: 16,
      bottom: 16
    })
    .alignItems(HorizontalAlign.Start)
    .borderRadius(8)
    .backgroundColor('#ffFFFFFF')
  }

  private async doScan(): Promise<void> {
    try {
      const result = await scanBarcode.startScanForResult(getContext(this), {
        scanTypes: [scanCore.ScanType.ALL]
      })
      const rawValue = result.originalValue ?? ''
      let qrcode = ''
      let expireAt: number = 0
      try {
        const parsed = JSON.parse(rawValue) as Record<string, string | number>
        qrcode = (parsed['qrCode'] as string) ?? ''
        expireAt = (parsed['expireAt'] as number) ?? 0
      } catch {
        // 非 JSON 格式的二维码不是合法的 Bot 二维码
        NECommonUtils.showToast($r('app.string.bot_scan_invalid_qr'))
        return
      }
      if (qrcode.length <= 0) {
        NECommonUtils.showToast($r('app.string.bot_scan_invalid_qr'))
        return
      }
      if (expireAt > 0 && Date.now() > expireAt) {
        AlertDialog.show({
          title: $r('app.string.bot_qr_expired_title'),
          message: $r('app.string.bot_qr_expired_message'),
          autoCancel: true,
          buttons: [{ value: $r('app.string.bot_qr_expired_btn'), fontColor: '#337EFF', action: () => {} }]
        })
        return
      }
      this.pathStack.pushPath({
        name: 'BindBotPage',
        param: qrcode,
        onPop: (popInfo: PopInfo) => {
          const bot = popInfo.result as V2NIMUserAIBot | undefined
          if (bot && bot.accid) {
            this.pathStack.pushPath({ name: 'BotInfoPage', param: bot })
          }
        }
      })
    } catch (scanErr) {
      console.error('[ConversationPage] scan error: ' + JSON.stringify(scanErr))
    }
  }

  /**
   * 搜索页面
   */
  goSearchPage(pathStack: NavPathStack) {
    pathStack.pushPath({ name: "SearchPage" })
  }

  /**
   * 添加好友
   */
  goAddFriend(pathStack: NavPathStack) {
    pathStack.pushPath({ name: "AddFriendPage" })
  }

  // 创建讨论组的人选选择器返回
  groupSelectorCallback = async (selectedList: NEUserWithFriend[]) => {
    try {
      this.pathStack.pop()
      let invitees = selectedList.map(user => user.user?.accountId ?? '')
      this.createGroupTeam(invitees)
    } catch (err) {
      console.log(err)
    }
  }
  // 创建高级群的人选选择器返回
  teamSelectorCallback = async (selectedList: NEUserWithFriend[]) => {
    try {
      this.pathStack.pop()
      let invitees = selectedList.map(user => user.user?.accountId ?? '')
      this.createAdvanceTeam(invitees)
    } catch (err) {
      console.log(err)
    }
  }

  /**
   * 跳转到人员选择器
   * @param pathStack
   * @param isGroup
   */
  goToPersonSelectPage(pathStack: NavPathStack, isGroup: boolean) {
    if (isGroup) {
      pathStack.pushPath({
        name: "PersonSelectPage",
        param: new PersonSelectParam(this.groupSelectorCallback)
      })
    } else {
      pathStack.pushPath({
        name: "PersonSelectPage",
        param: new PersonSelectParam(this.teamSelectorCallback)
      })
    }

  }

  /**
   * 创建讨论组
   */
  createGroupTeam(invitees: string[]) {
    TeamRepo.createGroupTeam(invitees).then((result) => {
      if (result) {
        // 跳转到聊天页面
        this.pathStack.pushPath({
          name: "ChatTeamPage",
          param: ChatKitClient.nim.conversationIdUtil.teamConversationId(result.team.teamId)
        })
      }
    })
  }

  /**
   * 创建高级群
   */
  createAdvanceTeam(invitees: string[]) {
    TeamRepo.createAdvanceTeam(invitees).then((result) => {
      if (result) {
        //1，本地保存一条消息
        const message = ChatKitClient.nim.messageCreator.createTipsMessage(
          getContext(this).resourceManager.getStringSync($r('app.string.createAdvancedTeamSuccess'))
        )
        ChatRepo.saveLocalMessage(message,
          ChatKitClient.nim.conversationIdUtil.teamConversationId(result.team.teamId),
          ChatKitClient.getLoginUserId(),
          (new Date()).valueOf() - 500
        )
        // 2 跳转到聊天页面
        this.pathStack.pushPath({
          name: "ChatTeamPage",
          param: ChatKitClient.nim.conversationIdUtil.teamConversationId(result.team.teamId)
        })
      }
    })

  }
}

// 跳转页面入口函数
@Builder
export function ConversationPageBuilder() {
  ConversationPage()
}