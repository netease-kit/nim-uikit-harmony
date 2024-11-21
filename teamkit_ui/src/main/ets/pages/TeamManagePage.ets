/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
    AitAllPermission,
    ChatKitClient,
    ErrorUtils,
    keyExtensionAtAll,
    TeamRepo,
    typeExtensionAllowAll,
    typeExtensionAllowManager
} from '@nimkit/chatkit'
import { CommonChooseDialog, NavigationBackBuilder, NECommonUtils } from '@nimkit/common'
import {
    V2NIMError,
    V2NIMErrorCode,
    V2NIMTeam,
    V2NIMTeamInviteMode,
    V2NIMTeamType,
    V2NIMTeamUpdateInfoMode,
    V2NIMUpdateTeamInfoParams
} from '@nimsdk/base'
import { TeamManageViewModel } from '../viewModel/TeamManageViewModel'

@ComponentV2
struct TeamManagePage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: TeamManageViewModel = new TeamManageViewModel()
  //编辑群信息选择
  editTeamInfoDialog: CustomDialogController = new CustomDialogController({
    builder: CommonChooseDialog({
      content1: $r('app.string.team_all_member'),
      content2: $r('app.string.team_owner_and_manager'),
      onItemChosen: (index) => {
        if (this.viewModel.teamInfo) {
          //判断网络连接状态
          if (ErrorUtils.checkNetworkAndToast()) {
            const param: V2NIMUpdateTeamInfoParams = {
              updateInfoMode: index === 1 ? V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_ALL :
              V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_MANAGER
            }
            TeamRepo.updateTeamInfo(this.viewModel.teamInfo?.teamId,
              V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, param)
              .catch((e: V2NIMError) => {
                if (e.code === V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_OWNER_OR_MANAGER_OPERATION_PERMISSION_REQUIRED) {
                  NECommonUtils.showToast($r('app.string.team_operate_no_permission_tip'))
                }
              })
          }
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
        if (this.viewModel.teamInfo) {
          //判断网络连接状态
          if (ErrorUtils.checkNetworkAndToast()) {
            const param: V2NIMUpdateTeamInfoParams = {
              inviteMode: index === 1 ? V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_ALL :
              V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_MANAGER
            }
            TeamRepo.updateTeamInfo(this.viewModel.teamInfo?.teamId,
              V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, param)
              .catch((e: V2NIMError) => {
                if (e.code === V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_OWNER_OR_MANAGER_OPERATION_PERMISSION_REQUIRED) {
                  NECommonUtils.showToast($r('app.string.team_operate_no_permission_tip'))
                }
              })
          }
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
  aitAllPermissionDialog: CustomDialogController = new CustomDialogController({
    builder: CommonChooseDialog({
      content1: $r('app.string.team_all_member'),
      content2: $r('app.string.team_owner_and_manager'),
      onItemChosen: (index) => {
        if (this.viewModel.teamInfo) {
          //判断网络连接状态
          if (ErrorUtils.checkNetworkAndToast()) {
            let extension = this.viewModel.teamInfo.serverExtension
            let permission = index === 1 ? typeExtensionAllowAll : typeExtensionAllowManager
            if (extension) {
              let objectExt = JSON.parse(extension) as object
              objectExt[keyExtensionAtAll] = permission
              extension = JSON.stringify(objectExt)
            } else {
              let jsonObject: AitAllPermission = {
                yxAllowAt: permission,
                lastOpt: keyExtensionAtAll
              }
              extension = JSON.stringify(jsonObject)
            }
            const param: V2NIMUpdateTeamInfoParams = {
              serverExtension: extension
            }
            TeamRepo.updateTeamInfo(this.viewModel.teamInfo?.teamId,
              V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, param)
              .catch((e: V2NIMError) => {
                if (e.code === V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_OWNER_OR_MANAGER_OPERATION_PERMISSION_REQUIRED) {
                  NECommonUtils.showToast($r('app.string.team_operate_no_permission_tip'))
                }
              })
          }
        }
      }
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    height: 140,
  })

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.team_manage'),
        backgroundColor: '#ffEFF1F4',
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })
      if (this.viewModel.teamInfo) {

        //群主才能管理管理员
        if (this.viewModel.teamInfo?.ownerAccountId === ChatKitClient.getLoginUserId()) {
          Row() {
            Text($r('app.string.team_manage_manager'))
              .fontSize(16)
              .fontColor('#ff333333')


            Blank().layoutWeight(1)
            if (this.viewModel.managerCount !== undefined) {
              Text(this.viewModel.managerCount + '')
                .fontSize(16)
                .fontColor('#ff999999')
                .margin({
                  right: 10
                })
            }

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
          .backgroundColor(Color.White)
          .margin({
            left: 16,
            right: 16,
            top: 12
          })
          .borderRadius(8)
          .onClick(() => {
            this.pathStack.pushPath({
              name: 'TeamManagerListPage',
              param: this.viewModel.teamInfo?.teamId,
              onPop: (popInfo: PopInfo) => {
                let managerSize = popInfo.result as number | undefined
                if (managerSize !== undefined) {
                  this.viewModel.managerCount = managerSize
                }
              }
            })
          })
        }

        Column() {

          Row() {
            Column() {
              Text($r('app.string.team_edit_team_info'))
                .fontSize(16)
                .fontColor('#ff333333')
                .margin({
                  bottom: 6
                })

              Text(this.viewModel.teamInfo.updateInfoMode === V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_ALL ?
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
              Text($r('app.string.team_ait_permission'))
                .fontSize(16)
                .fontColor('#ff333333')
                .margin({
                  bottom: 6
                })

              Text(this.viewModel.getAitAllPermission() === typeExtensionAllowAll ?
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
            this.aitAllPermissionDialog.open()
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

              Text(this.viewModel.teamInfo.inviteMode === V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_ALL ?
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

        }
        .backgroundColor(Color.White)
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
      let teamInfo = context.pathStack.getParamByName('TeamManagePage')[0] as V2NIMTeam
      this.viewModel.init(teamInfo)
      this.viewModel.getTeamManagerCount()
    })
  }

  aboutToDisappear(): void {
    this.editTeamInfoDialog.close()
    this.inviteTeamMemberDialog.close()
    this.aitAllPermissionDialog.close()
    this.viewModel.destroy()
  }
}

@Builder
export function TeamManagePageBuilder() {
  TeamManagePage()
}