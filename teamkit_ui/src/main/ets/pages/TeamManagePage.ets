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
  IMKitConfigCenter,
  keyExtensionAtAll,
  keyExtensionLastOptType,
  keyExtensionTopSticky,
  TeamRepo,
  typeExtensionAllowAll,
  typeExtensionAllowManager
} from '@nimkit/chatkit'
import { CommonChooseDialog, NavigationBackBuilder, NECommonUtils } from '@nimkit/common'
import {
  V2NIMError,
  V2NIMErrorCode,
  V2NIMTeam,
  V2NIMTeamAgreeMode,
  V2NIMTeamInviteMode,
  V2NIMTeamJoinMode,
  V2NIMTeamType,
  V2NIMTeamUpdateInfoMode,
  V2NIMUpdateTeamInfoParams
} from '@nimsdk/base'
import { getTopStickyUpdateExtensionMode, TeamManageViewModel } from '../viewModel/TeamManageViewModel'

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
  // 消息置顶权限选择
  topStickyPermissionDialog: CustomDialogController = new CustomDialogController({
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
              objectExt[keyExtensionTopSticky] = permission
              objectExt[keyExtensionLastOptType] = keyExtensionTopSticky
              extension = JSON.stringify(objectExt)
            } else {
              let jsonObject: Record<string, string> = {}
              jsonObject[keyExtensionTopSticky] = permission
              jsonObject[keyExtensionLastOptType] = keyExtensionTopSticky
              extension = JSON.stringify(jsonObject)
            }
            const param: V2NIMUpdateTeamInfoParams = {
              serverExtension: extension,
              updateExtensionMode: getTopStickyUpdateExtensionMode(permission)
            }
            TeamRepo.updateTeamInfo(this.viewModel.teamInfo?.teamId,
              this.viewModel.teamInfo.teamType, param)
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
              // 设置 lastOpt 标记，用于通知消息解析时识别这是一个 @权限变更操作
              objectExt[keyExtensionLastOptType] = keyExtensionAtAll
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

          // 消息置顶权限（受 enableTopMessage 控制）
          if (IMKitConfigCenter.enableTopMessage) {
            Divider()
              .color('#ffF5F8FC').height(1)

            Row() {
              Column() {
                Text($r('app.string.team_top_sticky_permission'))
                  .fontSize(16)
                  .fontColor('#ff333333')
                  .margin({
                    bottom: 6
                  })

                Text(this.viewModel.getTopStickyPermission() === typeExtensionAllowAll ?
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
              this.topStickyPermissionDialog.open()
            })
          }

        }
        .backgroundColor(Color.White)
        .margin({
          left: 16,
          right: 16,
          top: 12
        })
        .borderRadius(8)

        // JoinMode / AgreeMode 开关（通过配置项控制是否显示）
        if (IMKitConfigCenter.enableTeamJoinAgreeModelAuth) {

          // 区块标题「进群模式」
          Text($r('app.string.team_join_mode_title'))
            .fontSize(12)
            .fontColor('#ff999999')
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({
              left: 32,
              top: 16,
              bottom: 4
            })

          Column() {
            // 入群邀请需同意
            Row() {
              Column() {
                Text($r('app.string.team_agree_mode'))
                  .fontSize(16)
                  .fontColor('#ff333333')

                Text($r('app.string.team_agree_mode_subscribe'))
                  .fontSize(14)
                  .fontColor('#ff999999')
                  .margin({ top: 6 })
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({
                type: ToggleType.Switch,
                isOn: this.viewModel.agreeModeToggleOn
              })
                .selectedColor('#337EFF')
                .onChange((isOn: boolean) => {
                  this.viewModel.updateAgreeModeToggle(isOn)
                })
            }
            .padding({
              left: 16,
              right: 16,
              top: 8,
              bottom: 8
            })
            .alignItems(VerticalAlign.Top)

            Divider()
              .color('#ffF5F8FC').height(1)

            // 入群审核
            Row() {
              Column() {
                Text($r('app.string.team_join_mode'))
                  .fontSize(16)
                  .fontColor('#ff333333')

                Text($r('app.string.team_join_mode_subscribe'))
                  .fontSize(14)
                  .fontColor('#ff999999')
                  .margin({ top: 6 })
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({
                type: ToggleType.Switch,
                isOn: this.viewModel.joinModeToggleOn
              })
                .selectedColor('#337EFF')
                .onChange((isOn: boolean) => {
                  this.viewModel.updateJoinModeToggle(isOn)
                })
            }
            .padding({
              left: 16,
              right: 16,
              top: 8,
              bottom: 8
            })
            .alignItems(VerticalAlign.Top)
          }
          .backgroundColor(Color.White)
          .margin({
            left: 16,
            right: 16,
            top: 4
          })
          .borderRadius(8)
        }
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
    this.topStickyPermissionDialog.close()
    this.viewModel.destroy()
  }
}

@Builder
export function TeamManagePageBuilder() {
  TeamManagePage()
}
