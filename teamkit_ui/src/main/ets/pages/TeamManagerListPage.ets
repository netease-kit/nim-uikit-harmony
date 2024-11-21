/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, TeamRepo } from '@nimkit/chatkit'
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonConfirmDialog,
  CommonEmptyResult,
  NavigationBackBuilder,
  NECommonUtils
} from '@nimkit/common'
import { TeamMemberWithUser } from '@nimkit/chatkit/src/main/ets/model/TeamMemberWithUser'
import { V2NIMTeamMemberRole, V2NIMTeamType } from '@nimsdk/base'
import { ManagerSelectorParams } from './TeamMemberSelectorPage'
import { TeamMangerListViewModel } from '../viewModel/TeamManagerListViewModel'

/**
 * 群管理员列表
 */
@ComponentV2
struct TeamManagerListPage {
  pathStack: NavPathStack = new NavPathStack()
  //群Id
  teamId?: string
  @Local viewModel: TeamMangerListViewModel = new TeamMangerListViewModel()
  //移除管理员弹框
  dialogRemoveManagerDialogController: CustomDialogController = new CustomDialogController({
    builder: CommonConfirmDialog({
      title: $r('app.string.team_remove_member_title'),
      confirmContent: $r('app.string.team_remove_manager_content'),
      confirm: () => {
        this.viewModel.removeTeamManager(this.removeManagerId)
      },
    },
    ),
    width: '70%'
  })
  //移除管理员Id
  removeManagerId?: string

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.team_manager'),
        backgroundColor: '#ffffffff',
        leftButtonAction: () => {
          this.pathStack.pop(
            this.viewModel.managerList.length
          )
        }
      })

      Row() {
        Text($r('app.string.team_add_manager'))
          .fontSize(16)
          .fontColor('#ff333333')
          .margin({
            bottom: 6
          })

        Blank().layoutWeight(1)


        Image($r('app.media.arrow_right'))
          .width(4.92)
          .height(9.54)
      }
      .backgroundColor(Color.White)
      .margin({
        left: 16,
        right: 16,
        top: 12
      })
      .borderRadius(8)
      .onClick(() => {
        let params: ManagerSelectorParams = {
          teamId: this.teamId ?? '',
          managerCount: this.viewModel.managerList.length
        }
        this.pathStack.pushPath({
          name: 'TeamMemberSelectorPage',
          param: params,
          onPop: (popInfo: PopInfo) => {
            let selectList = popInfo.result as string[]
            TeamRepo.updateTeamMemberRole(
              this.teamId,
              V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
              selectList,
              V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
            ).then(() => {
              //使用监听回调，处理多端同步
              // this.viewModel.addNewManager(selectList)
            }).catch((e: Error) => {
              ChatKitClient.logger?.debug(`add manager failed ${e.message}`)
              NECommonUtils.showToast($r('app.string.team_add_manager_failed_tip'))
            })
          }
        })
      })

      if (this.viewModel.haveInitData) {
        if (this.viewModel.managerList.length > 0) {
          List() {
            ForEach(this.viewModel.managerList, (member: TeamMemberWithUser) => {
              ListItem() {
                Row() {
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
                    .width('70%')

                  Blank().layoutWeight(1)

                  Text($r('app.string.team_remove_manager'))
                    .fontColor('#ffE6605C')
                    .fontSize(12)
                    .borderWidth(1)
                    .borderRadius(4)
                    .borderColor('#ffE6605C')
                    .backgroundColor(Color.White)
                    .padding({
                      top: 4,
                      bottom: 6,
                      left: 12,
                      right: 12
                    })
                    .onClick(() => {
                      this.removeManagerId = member.getAccId()
                      this.dialogRemoveManagerDialogController.open()
                    })


                }
                .padding({
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: 10
                })
                .onClick(() => {
                  if (member.teamMember.accountId === ChatKitClient.getLoginUserId()) {
                    this.pathStack.pushPath({
                      name: 'MineInfoPage'
                    })
                  } else {
                    this.pathStack.pushPath({ name: 'PersonInfoPage', param: member.teamMember.accountId })
                  }
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
              this.viewModel.managerList.length > 0) {
              this.viewModel.getTeamManagerList()
            }
          })
          .scrollBar(BarState.Off)
          .width('100%')
          .height('100%')
          .backgroundColor('#ffFFFFFF')
        } else {
          //空
          CommonEmptyResult({
            tips: $r('app.string.team_none_manager')
          }).margin({
            top: 80
          })
        }
      }

    }
    .hideTitleBar(true)
    .backgroundColor('#ffffffff')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.teamId = context.pathStack.getParamByName('TeamManagerListPage')[0] as string
      this.viewModel.init(this.teamId)
      this.viewModel.getTeamManagerList(true)
    })
    .onBackPressed(() => {
      this.pathStack.pop(
        this.viewModel.managerList.length
      )
      return true
    })
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
  }
}

@Builder
export function TeamManagerListPageBuilder() {
  TeamManagerListPage()
}