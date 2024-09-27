/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, TeamRepo } from '@nimkit/chatkit'
import { CommonChooseDialog, NavigationBackBuilder } from '@nimkit/common'
import {
  V2NIMTeam,
  V2NIMTeamInviteMode,
  V2NIMTeamType,
  V2NIMTeamUpdateInfoMode,
  V2NIMUpdateTeamInfoParams
} from '@nimsdk/base'

@Component
struct TeamManagePage {
  pathStack: NavPathStack = new NavPathStack()
  @State teamInfo?: V2NIMTeam = undefined
  //编辑群信息选择
  editTeamInfoDialog: CustomDialogController = new CustomDialogController({
    builder: CommonChooseDialog({
      content1: $r('app.string.team_all_member'),
      content2: $r('app.string.team_owner_and_manager'),
      onItemChosen: (index) => {
        if (this.teamInfo) {
          const param: V2NIMUpdateTeamInfoParams = {
            updateInfoMode: index === 1 ? V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_ALL :
            V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_MANAGER
          }
          TeamRepo.updateTeamInfo(this.teamInfo?.teamId,
            V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, param)
        }

      }
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    height: 140,
  })
  //编辑群信息选择
  inviteTeamMemberDialog: CustomDialogController = new CustomDialogController({
    builder: CommonChooseDialog({
      content1: $r('app.string.team_all_member'),
      content2: $r('app.string.team_owner_and_manager'),
      onItemChosen: (index) => {
        if (this.teamInfo) {
          const param: V2NIMUpdateTeamInfoParams = {
            inviteMode: index === 1 ? V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_ALL :
            V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_MANAGER
          }
          TeamRepo.updateTeamInfo(this.teamInfo?.teamId,
            V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, param)
        }
      }
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    height: 140,
  })

  initTeamInfoListener() {
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', (team) => {
      if (team.teamId === this.teamInfo?.teamId) {
        this.teamInfo = team
      }
    })
  }

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.team_manage'),
        backgroundColor: '#ffEFF1F4',
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })
      if (this.teamInfo) {
        Column() {

          Row() {
            Column() {
              Text($r('app.string.team_edit_team_info'))
                .fontSize(16)
                .fontColor('#ff333333')
                .margin({
                  bottom: 6
                })

              Text(this.teamInfo.updateInfoMode === V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_ALL ?
              $r('app.string.team_all_member') : $r('app.string.team_owner_and_manager'))
                .fontSize(16)
                .fontColor('#ff999999')
            }.alignItems(HorizontalAlign.Start)

            Blank().layoutWeight(1)


            Image($r('app.media.arrow_right'))
              .width(4.92)
              .height(9.54)
          }
          .padding({
            left: 16,
            right: 16,
            top: 16,
            bottom: 16
          })
          .onClick(() => {
            this.editTeamInfoDialog.open()
          })

          Divider()
            .color('#ffF5F8FC').height(1)


          Row() {
            Column() {
              Text($r('app.string.team_add_team_member'))
                .fontSize(16)
                .fontColor('#ff333333')
                .margin({
                  bottom: 6
                })

              Text(this.teamInfo.inviteMode === V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_ALL ?
              $r('app.string.team_all_member') : $r('app.string.team_owner_and_manager'))
                .fontSize(16)
                .fontColor('#ff999999')
            }.alignItems(HorizontalAlign.Start)

            Blank().layoutWeight(1)


            Image($r('app.media.arrow_right'))
              .width(4.92)
              .height(9.54)
          }
          .padding({
            left: 16,
            right: 16,
            top: 16,
            bottom: 16
          })
          .onClick(() => {
            this.inviteTeamMemberDialog.open()
          })

        }.backgroundColor(Color.White)
        .margin({
          left: 16,
          right: 16,
          top: 12
        })
        .borderRadius(8)
      }


    }
    .hideTitleBar(true)
    .backgroundColor('#ffEFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.teamInfo = context.pathStack.getParamByName('TeamManagePage')[0] as V2NIMTeam
      this.initTeamInfoListener()
    })
  }
}

@Builder
export function TeamManagePageBuilder() {
  TeamManagePage()
}