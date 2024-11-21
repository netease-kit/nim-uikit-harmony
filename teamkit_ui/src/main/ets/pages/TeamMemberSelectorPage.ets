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
  NavigationBackBuilder,
  NECommonUtils
} from '@nimkit/common'
import { TeamMemberWithUser } from '@nimkit/chatkit/src/main/ets/model/TeamMemberWithUser'
import { TeamMemberSelectorViewModel } from '../viewModel/TeamMemberSelectorViewModel'

//管理员选择页面参数
export interface ManagerSelectorParams {
  managerCount: number,
  teamId: string
}

//管理员人数限制
export const managerLimit: number = 10

/**
 * 群成员选择器，只有普通成员
 */
@ComponentV2
struct TeamMemberSelectorPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: TeamMemberSelectorViewModel = new TeamMemberSelectorViewModel()

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.team_select_member_title'),
        showDivideLine: true,
        leftButtonTitle: $r('app.string.cancel'),
        leftButtonColor: '#666666',
        leftButtonAction: () => {
          this.pathStack.pop()
        },
        rightButtonTitle: this.viewModel.selectedMembers.size > 0 ?
        $r('app.string.common_sure_count', this.viewModel.selectedMembers.size) : $r('app.string.common_sure'),
        rightButtonColor: '#337EFF',
        rightButtonAction: this.sureButtonClickAction,
        buttonTextWidth: 80
      })

      if (this.viewModel.memberList.length <= 0) {
        CommonEmptyResult({
          tips: $r('app.string.team_add_manager_empty_tip')
        })
          .margin({
            top: 56 + 74,
          })
      }

      List() {
        ForEach(this.viewModel.memberList, (member: TeamMemberWithUser) => {
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

              Text(member.getNickname())
                .fontColor('#ff333333')
                .fontSize(16)
                .width('100%')

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
        })

        ListItem() {
          Column() {
          }
          .height(42)
        }
      }
      .listDirection(Axis.Vertical)
      .onReachEnd(() => {
        if (!this.viewModel.isFinish &&
          this.viewModel.memberList.length > 0) {
          this.viewModel.getTeamMemberList()
        }
      })
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor('#ffFFFFFF')

    }
    .hideTitleBar(true)
    .backgroundColor('#ffffffff')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      let params = context.pathStack.getParamByName('TeamMemberSelectorPage')[0] as ManagerSelectorParams
      let teamId = params.teamId
      let managerCount = params.managerCount
      this.viewModel.init(teamId, managerCount)
      this.viewModel.getTeamMemberList(true)
    })
  }

  sureButtonClickAction = () => {
    if (this.viewModel.selectedMembers.size === 0) {
      NECommonUtils.showToast($r('app.string.team_select_none_member_tip'))
      return
    }

    //限制管理员数量
    if (this.viewModel.selectedMembers.size + this.viewModel.managerCount > managerLimit) {
      NECommonUtils.showToast($r('app.string.team_add_manager_limit_tip', managerLimit))
      return
    }
    //判断网络连接状态
    if (ErrorUtils.checkNetworkAndToast()) {
      let selectIds: string[] = Array.from(this.viewModel.selectedMembers)
      this.pathStack.pop(selectIds)
    }
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
  }
}

@Builder
export function TeamMemberSelectorPageBuilder() {
  TeamMemberSelectorPage()
}