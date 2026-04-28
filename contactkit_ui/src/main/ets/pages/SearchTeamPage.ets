/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils, TeamRepo } from '@nimkit/chatkit';
import { CommonEmptyResult, CommonTextInput, NavigationBackBuilder } from '@nimkit/common';
import { V2NIMTeam, V2NIMTeamType } from '@nimsdk/base';

// 跳转页面入口函数
@Builder
export function SearchTeamPageBuilder() {
  SearchTeamPage()
}

@ComponentV2
export struct SearchTeamPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local isEmpty: boolean = false

  onSubmit = async (enterKey: EnterKeyType, event: SubmitEvent) => {
    const teamId = event.text?.trim()
    if (!teamId) {
      return
    }

    if (ErrorUtils.checkNetworkAndToast()) {
      try {
        const team: V2NIMTeam | undefined = await TeamRepo.getTeamInfoFromCloud(teamId,
          V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
        if (team) {
          this.isEmpty = false
          this.pathStack.pushPath({
            name: 'TeamProfilePage',
            param: team
          })
        } else {
          this.isEmpty = true
        }
      } catch (err) {
        console.error('SearchTeamPage search error', err)
        this.isEmpty = true
      }
    }
  }

  onTextChange = (value: string, previewText?: PreviewText) => {
    this.isEmpty = false
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.team_search_title'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        CommonTextInput({
          placeHolderText: $r('app.string.team_search_placeholder'),
          onSubmit: this.onSubmit,
          onTextChange: this.onTextChange
        })

        if (this.isEmpty) {
          CommonEmptyResult({
            tips: $r('app.string.team_not_exist_tip')
          })
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
