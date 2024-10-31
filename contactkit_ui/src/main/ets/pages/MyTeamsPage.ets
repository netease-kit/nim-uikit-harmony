/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient } from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonEmptyResult,
  NavigationBackBuilder,
  TailString,
  ViewItemBuilder
} from '@nimkit/common';
import { V2NIMConversationType, V2NIMTeam } from '@nimsdk/base';
import { MyTeamsViewModel } from '../viewmodel/MyTeamsViewModel';

@ComponentV2
export struct MyTeamsPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: MyTeamsViewModel = new MyTeamsViewModel()

  async requestData(): Promise<void> {
    try {
      await this.viewModel.getJoinedTeamList()
    } catch (err) {
      console.error(err)
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          NavigationBackBuilder({
            title: $r('app.string.contact_my_teams'),
            showDivideLine: true,
            leftButtonAction: () => {
              this.pathStack.pop()
            }
          })

          List() {
            ForEach(this.viewModel.teamList, (item: V2NIMTeam) => {
              ListItem() {
                ViewItemBuilder({
                  avatarItem: new AvatarItem(item.avatar, TailString(item.name),
                    AvatarColorUntil.getBackgroundColorById(item.teamId)),
                  title: item.name,
                  titleIconSize: 36,
                  titleFontSize: 14,
                  itemHeight: 52,
                  showDivideLine: false
                })
              }
              .onClick(() => {
                this.pathStack.pushPath({
                  name: 'ChatTeamPage',
                  param: ChatKitClient.nim.conversationIdUtil.teamConversationId(item.teamId)
                })
              })
            })
          }
          .width('100%')
          .margin({
            bottom: 56
          })
        }

        if (this.viewModel.teamList.length <= 0) {
          CommonEmptyResult({
            tips: $r('app.string.no_team')
          })
            .margin({
              top: 56 + 74,
            })
        }
      }
      .alignContent(Alignment.Top)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }
}


// 跳转页面入口函数
@Builder
export function MyTeamsPageBuilder() {
  MyTeamsPage()
}