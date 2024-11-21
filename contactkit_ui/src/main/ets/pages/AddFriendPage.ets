/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ErrorUtils } from '@nimkit/chatkit';
import { CommonEmptyResult, CommonTextInput, NavigationBackBuilder } from '@nimkit/common';

// 跳转页面入口函数
@Builder
export function AddFriendPageBuilder() {
  AddFriendPage()
}

@ComponentV2
export struct AddFriendPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local isEmpty: boolean = false
  onSubmit = async (enterKey: EnterKeyType, event: SubmitEvent) => {
    // 查询自己
    if (event.text === ChatKitClient.getLoginUserId()) {
      this.pathStack.pushPath({
        name: 'MineInfoPage'
      })
      return
    }

    if (ErrorUtils.checkNetworkAndToast()) {
      try {
        const users = await ContactRepo.getUserWithFriendByIds([event.text])
        this.isEmpty = users.length <= 0
        if (!this.isEmpty) {
          this.pathStack.pushPath({
            name: 'PersonInfoPage',
            param: event.text
          })
        }
      } catch (err) {
        console.error(err)
        this.isEmpty = true
      }
    }
  }
  onTextChange = (value: string, previewText?: PreviewText) => {
    // this.isEmpty = false
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.person_info_add'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        CommonTextInput({
          onSubmit: this.onSubmit,
          onTextChange: this.onTextChange
        })

        if (this.isEmpty) {
          CommonEmptyResult()
            .margin({
              top: 74
            })
        }
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}
