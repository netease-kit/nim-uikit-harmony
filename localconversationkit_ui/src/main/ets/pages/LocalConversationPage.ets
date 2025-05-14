/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ChatRepo, NEUserWithFriend, PersonSelectParam, TeamRepo } from '@nimkit/chatkit';
import { CommonEmptyResult, CommonLongLoadingProgress, NetworkBrokenBuilder } from '@nimkit/common';
import { V2NIMConversationType, V2NIMLocalConversation } from '@nimsdk/base';
import { AitServer } from '../service/ait/AitService';
import { ConversationViewItem } from '../view/ConversationViewItem';
import { LocalConversationViewModel } from '../viewmodel/LocalConversationViewModel';

@ComponentV2
export struct LocalConversationPage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUreadMessageChange?: (unreadCount?: number) => void = undefined
  private viewModel: LocalConversationViewModel = new LocalConversationViewModel()

  aboutToAppear(): void {
    this.viewModel.onUreadMessageChange = this.onUreadMessageChange
    //初始化@ 服务
    AitServer.instance.init()
    this.viewModel.initConversation()
  }

  build() {
    NavDestination() {
      if (this.viewModel.conversationList) {
        if (this.viewModel.conversationList.length <= 0 && this.viewModel.isFinishedSyncLoad) {
          CommonEmptyResult({
            tips: $r('app.string.conversation_empty')
          }).margin({
            top: 80
          })
        } else {
          if (this.viewModel.networkBroken) {
            NetworkBrokenBuilder()
          }

          List() {
            ForEach(this.viewModel.conversationList, (item: V2NIMLocalConversation) => {
              ListItem() {
                ConversationViewItem({
                  conversationInfo: item,
                  haveBeanAit: this.viewModel.aitConversationList.has(item.conversationId),
                  onItemClick: () => {
                    //goto ChatPage
                    this.goToChatPage(item)
                  }
                })
              }
            })
          }
          .listDirection(Axis.Vertical)
          .onReachEnd(() => {
            if (this.viewModel.conversationList &&
              this.viewModel.conversationList.length > 0 &&
              !this.viewModel.isFinished) {
              this.viewModel.loadConversation()
            }
          })
          .scrollBar(BarState.Off)
          .width('100%')
          .height('100%')
          .backgroundColor('#ffFFFFFF')
        }

      } else {
        CommonLongLoadingProgress({ contentText: $r('app.string.conversation_loading') })
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
        let message = ChatKitClient.nim.messageCreator.createTipsMessage(
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
export function LocalConversationPageBuilder() {
  LocalConversationPage()
}