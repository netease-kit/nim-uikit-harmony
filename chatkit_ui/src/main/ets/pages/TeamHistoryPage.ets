/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils } from '@nimkit/chatkit';
import { ChatBaseViewModel } from '../viewmodel/ChatBaseViewModel';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  CommonTextInput,
  MatchSearchText,
  NavigationBackBuilder,
  TailString
} from '@nimkit/common';
import { DateUtil } from '@nimkit/common/src/main/ets/utils/DateUtil';
import { TeamHistoryModel, TeamHistoryViewModel } from '../viewmodel/TeamHistoryViewModel';
import { V2NIMConversationType } from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';

// 跳转页面入口函数
@Builder
export function TeamHistoryPageBuilder() {
  TeamHistoryPage()
}

@ComponentV2
export struct TeamHistoryPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel?: TeamHistoryViewModel
  @Local isEmpty: boolean = false
  @Local searchText: string = ""
  onSubmit = async (enterKey: EnterKeyType, event: SubmitEvent) => {
    this.searchText = event.text
    if (ErrorUtils.checkNetworkAndToast()) {
      if (this.searchText.length > 0) {
        try {
          await this.viewModel?.searchHistoryMessages(event.text)
          this.isEmpty = (this.viewModel?.historyList.length ?? 0) <= 0
        } catch (err) {
          console.error(err)
          this.isEmpty = true
        }
      }
    }
  }
  onTextChange = (value: string, previewText?: PreviewText) => {
    if (value.length === 0) {
      this.viewModel?.clearHistoryMessages()
      this.isEmpty = false
    }
  }

  requestData() {
    const teamId = this.pathStack.getParamByName('TeamHistoryPage')[0] as string
    this.viewModel = new TeamHistoryViewModel(teamId)
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.team_history_record'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        CommonTextInput({
          placeHolderText: $r('app.string.team_history_record_tip'),
          onSubmit: this.onSubmit.bind(this),
          onTextChange: this.onTextChange,
          keepEditableState: false
        })
          .margin({
            top: 16
          })

        if (this.isEmpty) {
          CommonEmptyResult({
            emptyImage: $r('app.media.no_history'),
            tips: $r('app.string.team_history_record_empty_tip')
          })
            .margin({
              top: 74
            })
        }

        List() {
          ForEach(this.viewModel?.historyList, (item: TeamHistoryModel) => {
            ListItem() {
              Row() {
                CommonAvatar({
                  item: new AvatarItem(item.teamMember?.getAvatar(),
                    TailString(item.teamMember?.getAvatarName()),
                    AvatarColorUntil.getBackgroundColorById(item.teamMember?.getAccId() ?? "")),
                  roundRadius: 18
                })
                  .width(36)
                  .height(36)
                  .margin({
                    left: 20
                  })

                Column() {
                  Text(item.teamMember?.getNickname())
                    .fontColor('#333333')

                  MatchSearchText({
                    allText: item.message.text,
                    searchText: this.searchText,
                    normalFontColor: "#999999"
                  })
                    .margin({
                      top: 6
                    })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({
                  left: 12,
                  right: 12
                })

                // 时间
                Text(DateUtil.formatTimestamp(item.message.createTime))
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({
                    right: 20
                  })
              }
            }
            .height(62)
            .onClick(() => {
              if (ChatBaseViewModel.currentViewModel) {
                let msgInfo = new NIMMessageInfo(item.message)
                ChatBaseViewModel.currentViewModel.setAnchorMessage(msgInfo)
              }
              if (item.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
                this.pathStack.popToName('ChatP2PPage')
              } else if (item.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
                this.pathStack.popToName('ChatTeamPage')
              }
            })
          })
        }
        .divider({
          strokeWidth: 1,
          color: "0xDBE0E8",
          startMargin: 20
        })
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }
}
