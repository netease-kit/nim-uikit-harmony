/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  ChatKitClient,
  ContactRepo,
  NEFriendUserCache,
  NEUserWithFriend,
  PersonSelectParam,
  TeamRepo
} from '@nimkit/chatkit'
import { ChatP2PViewModel } from '../viewmodel/ChatP2PViewModel'
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  NavigationBackBuilder,
  ViewItemArrow,
  ViewItemBuilder,
  ViewItemSwitch
} from '@nimkit/common'

@ComponentV2
export struct UserSettingPage {
  pathStack: NavPathStack = new NavPathStack()
  accountId?: string
  @Local userWithFriend?: NEUserWithFriend
  chatViewModel?: ChatP2PViewModel
  firstItems: ViewItemArrow[] = [
  // {
  //   title: $r("app.string.setting_pin"),
  //   itemHeight: 48,
  //   routerUrl: "",
  //   rightIcon: $r('app.media.arrow_right')
  // }
  ]
  // 设置是否开启消息提醒
  setP2PNotify = async (isOpen: boolean) => {
    try {
      await this.chatViewModel?.setP2PNotify(isOpen)
    } catch (err) {
      console.log(err)
    }
  }
  // 设置是否聊天置顶
  stickTopConversation = async (isOpen: boolean) => {
    try {
      await this.chatViewModel?.stickTopConversation(isOpen)
    } catch (err) {
      console.log(err)
    }
  }
  secondItems: ViewItemSwitch[] = [
    {
      title: $r('app.string.setting_message_notify'),
      itemHeight: 48,
      isOpen: false,
      switchChange: this.setP2PNotify
    },
    {
      title: $r('app.string.setting_message_stick_top'),
      itemHeight: 48,
      isOpen: false,
      switchChange: this.stickTopConversation
    },
  ]
  // 创建讨论组
  createDiscussion = async (selectedList: NEUserWithFriend[]) => {
    const inviteeAccountIds: string[] = []
    selectedList.forEach((userWithFriend) => {
      if (userWithFriend.user?.accountId) {
        inviteeAccountIds.push(userWithFriend.user.accountId)
      }
    })
    if (this.chatViewModel?.accountId) {
      inviteeAccountIds.push(this.chatViewModel?.accountId)
    }

    try {
      const createTeamResult = await TeamRepo.createGroupTeam(inviteeAccountIds)

      // 替换聊天页
      if (createTeamResult?.team) {
        this.pathStack.popToName('ChatP2PPage')
        this.pathStack.replacePathByName('ChatTeamPage',
          ChatKitClient.nim.conversationIdUtil.teamConversationId(createTeamResult.team.teamId))
      }
    } catch (err) {
      console.log(err)
    }
  }

  // 【＋】按钮点击事件
  onAddButtonClick() {
    this.pathStack.pushPath({
      name: 'PersonSelectPage',
      param: new PersonSelectParam(this.createDiscussion,
        [this.chatViewModel?.accountId],
        10)
    })
  }

  async requestData() {
    this.chatViewModel = this.pathStack.getParamByName('UserSettingPage')[0] as ChatP2PViewModel
    this.secondItems[0].isOpen = this.chatViewModel.isMessageNotify
    this.secondItems[1].isOpen = this.chatViewModel.isStickTop
    const accountId = this.chatViewModel.accountId
    if (NEFriendUserCache.getInstance().isFriend(accountId)) {
      this.userWithFriend = NEFriendUserCache.getInstance().getFriendById(accountId)
    } else {
      try {
        const users = await ContactRepo.getUserWithFriendByIds([accountId])
        if (users.length > 0) {
          this.userWithFriend = users[0]
        }
      } catch (err) {
        console.log(err)
      }
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.chat_setting'),
          backgroundColor: '#ffEFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Row() {
          Column() {
            CommonAvatar({
              item: new AvatarItem(this.userWithFriend?.user?.avatar,
                this.userWithFriend?.shortName(),
                AvatarColorUntil.getBackgroundColorById(this.userWithFriend?.user?.accountId ?? "")),
              roundRadius: 21,
              textSize: 16
            })
              .width(42)
              .height(42)

            Text(this.userWithFriend?.showName())
              .width(42)
              .fontSize(12)
              .maxLines(1)
              .textOverflow({
                overflow: TextOverflow.Ellipsis
              })
              .margin({
                top: 6
              })
          }
          .width(42)
          // .alignSelf(ItemAlign.Start)
          .height('100%')

          Image($r('app.media.team_invite'))
            .width(42)
            .height(42)
            .margin({
              left: 16
            })
            .onClick(() => {
              this.onAddButtonClick()
            })
        }
        .width('100%')
        .alignSelf(ItemAlign.Start)
        .alignItems(VerticalAlign.Top)
        .height(86)
        .borderRadius(8)
        .backgroundColor(Color.White)
        .margin({
          left: 20,
          right: 20,
          bottom: 12
        })
        .padding({
          left: 20,
          right: 20,
          top: 12
        })

        List() {
          ForEach(this.firstItems, (item: ViewItemArrow) => {
            ListItem() {
              ViewItemBuilder(item)
            }
            .width('100%')
            .height(item.itemHeight)
            .backgroundColor(item.backgroundColor ?? Color.White)
          })

          ForEach(this.secondItems, (item: ViewItemSwitch) => {
            ListItem() {
              ViewItemBuilder(item)
            }
            .width('100%')
            .height(item.itemHeight)
            .backgroundColor(item.backgroundColor ?? Color.White)
          })
        }
        .borderRadius(8)
        .backgroundColor(Color.White)
        .margin({ left: 20, right: 20, top: 0 })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor('#ffEFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }
}

// 跳转页面入口函数
@Builder
export function UserSettingPageBuilder() {
  UserSettingPage()
}