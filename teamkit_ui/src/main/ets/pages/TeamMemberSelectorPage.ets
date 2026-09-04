/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils } from '@nimkit/chatkit'
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  CommonTextInput,
  MatchSearchText,
  NavigationBackBuilder,
  NECommonUtils
} from '@nimkit/common'
import {
  resolveTeamMemberSearchTextPresentation,
  SearchTextPresentation,
  TeamMemberWithUser
} from '@nimkit/chatkit'
import { TeamMemberSelectorViewModel } from '../viewModel/TeamMemberSelectorViewModel'
import { ManagerSelectorParams } from '@nimkit/chatkit'


/**
 * 群成员选择器，只有普通成员
 */
@ComponentV2
struct TeamMemberSelectorPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: TeamMemberSelectorViewModel = new TeamMemberSelectorViewModel()

  // 搜索提交
  onSearchSubmit = (_enterKey: EnterKeyType, event: SubmitEvent) => {
    const keyword = event.text.trim()
    if (keyword.length > 0) {
      this.viewModel.searchTeamMembers(keyword)
    }
  }

  // 搜索文本变化 - 实时搜索
  onSearchTextChange = (value: string) => {
    const keyword = value.trim()
    if (keyword.length === 0) {
      this.viewModel.clearSearch()
    } else {
      this.viewModel.searchTeamMembers(keyword)
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.team_select_member_title'),
          showDivideLine: true,
          leftButtonTitle: $r('app.string.cancel'),
          leftButtonColor: '#666666',
          leftButtonAction: () => {
            this.pathStack.pop()
          },
          rightButtonTitle: this.viewModel.selectedCount > 0 ?
          $r('app.string.common_sure_count', this.viewModel.selectedCount) : $r('app.string.common_sure'),
          rightButtonColor: '#337EFF',
          rightButtonAction: this.sureButtonClickAction,
          buttonTextWidth: 80
        })

        // 搜索框
        CommonTextInput({
          placeHolderText: $r('app.string.team_member_search_placeholder'),
          onSubmit: this.onSearchSubmit,
          onTextChange: this.onSearchTextChange,
          keepEditableState: false
        })
          .margin({
            top: 16,
            bottom: 8
          })

        if (this.viewModel.getDisplayList().length <= 0 && !this.viewModel.isSearching) {
          if (!this.viewModel.searchLoadFailed) {
            CommonEmptyResult({
              tips: this.viewModel.searchKeyword.length > 0 ?
                $r('app.string.team_member_search_empty_tip') :
                $r('app.string.team_add_manager_empty_tip')
            })
              .margin({
                top: 56 + 74,
              })
          }
        }

        if (this.viewModel.isSearching) {
          LoadingProgress()
            .width(24)
            .height(24)
            .margin({ top: 56 })
        }

        List() {
          ForEach(this.viewModel.getDisplayList(), (member: TeamMemberWithUser) => {
            ListItem() {
              Row() {

                Toggle({ type: ToggleType.Checkbox, isOn: this.viewModel.selectedMembers.has(member.getAccId()) })
                  .margin({
                    right: 10
                  })
                  .onClick(() => {
                    this.viewModel.onMemberItemClick(member.getAccId())
                  })

                CommonAvatar({
                  item: new AvatarItem(
                    member.getAvatar(),
                    member.getAvatarName(),
                    AvatarColorUntil.getBackgroundColorById(member.getAccId())
                  )
                })
                  .width(42)
                  .height(42)
                  .margin({
                    right: 14
                  })

                this.searchResultTextBuilder(
                  member.getNickname(),
                  resolveTeamMemberSearchTextPresentation(member, this.viewModel.searchKeyword)
                )

              }
              .padding({
                left: 20,
                right: 20,
                top: 10,
                bottom: 10
              })
              .onClick(() => {
                this.viewModel.onMemberItemClick(member.getAccId())
              })
            }
          }, (member: TeamMemberWithUser) => this.viewModel.getMemberRenderKey(member))

          ListItem() {
            Column() {
            }
            .height(42)
          }
        }
        .listDirection(Axis.Vertical)
        .onReachEnd(() => {
          // 只有非搜索状态下才加载更多
          if (this.viewModel.searchKeyword.length === 0 &&
            !this.viewModel.isFinish &&
            this.viewModel.memberList.length > 0) {
            this.viewModel.getTeamMemberList()
          }
        })
        .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#ffFFFFFF')
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor('#ffffffff')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      let params = context.pathStack.getParamByName('TeamMemberSelectorPage')[0] as ManagerSelectorParams
      let teamId = params.teamId
      let selectLimit = params.selectLimit
      let mode = params.mode
      this.viewModel.init(teamId, selectLimit, mode)
      this.viewModel.getTeamMemberList(true)
    })
  }

  sureButtonClickAction = () => {
    if (this.viewModel.selectedMembers.size === 0) {
      NECommonUtils.showToast($r('app.string.team_select_none_member_tip'))
      return
    }

    //限制管理员数量
    if (this.viewModel.selectedMembers.size  > this.viewModel.selectLimit) {
      NECommonUtils.showToast($r('app.string.team_member_select_limit_tip', this.viewModel.selectLimit))
      return
    }
    //判断网络连接状态
    if (!this.viewModel.needNetwork || ErrorUtils.checkNetworkAndToast()) {
      let selectIds: string[] = Array.from(this.viewModel.selectedMembers)
      this.pathStack.pop(selectIds)
    }
  }

  @Builder
  searchResultTextBuilder(primaryText: string, presentation: SearchTextPresentation) {
    Column() {
      if (presentation.primaryMatched) {
        MatchSearchText({
          allText: primaryText,
          searchText: this.viewModel.searchKeyword.trim(),
          fontSize: 16
        })
      } else {
        Text(primaryText)
          .fontColor('#ff333333')
          .fontSize(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (presentation.secondaryText.length > 0) {
        MatchSearchText({
          allText: presentation.secondaryText,
          searchText: this.viewModel.searchKeyword.trim(),
          fontSize: 13,
          normalFontColor: '#999999',
          highlightFontColor: '#337EFF'
        })
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
  }
}

@Builder
export function TeamMemberSelectorPageBuilder() {
  TeamMemberSelectorPage()
}
