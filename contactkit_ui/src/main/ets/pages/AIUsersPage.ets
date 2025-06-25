/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  AvatarColorUntil,
  AvatarItem,
  CommonEmptyResult,
  CommonTextInput,
  NavigationBackBuilder,
  TailString,
  ViewItemBuilder
} from '@nimkit/common';
import { SearchListModel } from '../model/SearchListModel';
import { AIUsersViewModel, V2NIMAIUserEx } from '../viewmodel/AIUsersViewModel';

@ComponentV2
export struct AIUsersPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: AIUsersViewModel = new AIUsersViewModel()
  @Local searchText: string = ''
  @Local isEmpty: boolean = false
  @Local onlySearch: boolean = false
  onTextChange = (value: string, previewText?: PreviewText) => {
    try {
      if (value) {
        // search mode
        this.onlySearch = true
      } else {
        // total mode
        this.onlySearch = false
      }
      this.searchText = value
      this.viewModel.doSearchAI(value)
      this.isEmpty =
        value.length > 0 && this.viewModel.searchAIUsersData.length === 0
    } catch (err) {
      console.error(err)
    }
  }

  async requestData(): Promise<void> {
    try {
      this.viewModel.loadAIUserCache()
    } catch (err) {
      console.error(err)
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          NavigationBackBuilder({
            title: $r('app.string.contact_ai_users'),
            showDivideLine: false,
            leftButtonAction: () => {
              this.pathStack.pop()
            }
          })

          CommonTextInput({
            placeHolderText: $r('app.string.common_search_ai_users'),
            onTextChange: this.onTextChange,
            keepEditableState: false
          })
            .margin({ top: 5, bottom: 20 }) // 下方距离 List 20，并且下边界线有一条分割线

          Row()
            .width('100%')
            .height(1)
            .backgroundColor('#E9EFF5')

          List() {
            if (this.onlySearch) {
              ForEach(this.viewModel.searchAIUsersData, (item: SearchListModel) => {
                ListItem() {
                  ViewItemBuilder({
                    avatarItem: new AvatarItem(
                      item.userInfo?.user?.avatar,
                      TailString(item.userInfo?.user?.name ?? ''),
                      AvatarColorUntil.getBackgroundColorById(item.userInfo?.user?.accountId ?? '')
                    ),
                    title: item.userInfo?.user?.name,
                    titleIconSize: 36,
                    titleFontSize: 14,
                    itemHeight: 52,
                    showDivideLine: false
                  })
                }
                .onClick(() => {
                  this.pathStack.pushPath({
                    name: 'AIPersonInfoPage',
                    param: item.userInfo?.user?.accountId
                  })
                })
              })
            } else {
              ForEach(this.viewModel.aiUserList, (item: V2NIMAIUserEx) => {
                ListItem() {
                  ViewItemBuilder({
                    avatarItem: new AvatarItem(
                      item.user.avatar,
                      TailString(item.user.name),
                      AvatarColorUntil.getBackgroundColorById(item.user.accountId)
                    ),
                    title: item.user.name,
                    titleIconSize: 36,
                    titleFontSize: 14,
                    itemHeight: 52,
                    showDivideLine: false
                  })
                }
                .onClick(() => {
                  this.pathStack.pushPath({
                    name: 'AIPersonInfoPage',
                    param: item.user?.accountId
                  })
                })
              })
            }
          }
          .width('100%')
          .margin({
            bottom: 56
          })
        }

        if (this.viewModel.aiUserList.length <= 0) {
          CommonEmptyResult({
            tips: $r('app.string.no_ai_user')
          })
            .margin({
              top: 56 + 74
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
export function AIUsersPageBuilder() {
  AIUsersPage()
}