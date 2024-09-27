/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, TeamRepo } from '@nimkit/chatkit'
import { AvatarColorUntil, AvatarItem, CommonAvatar, NavigationBackBuilder, TextEditParams } from '@nimkit/common'
import {
  V2NIMTeam,
  V2NIMTeamMember,
  V2NIMTeamMemberRole,
  V2NIMTeamType,
  V2NIMTeamUpdateInfoMode,
  V2NIMUpdateTeamInfoParams
} from '@nimsdk/base'
import { AvatarEditParams } from './TeamAvatarPage'

@Component
struct TeamInfoPage {
  pathStack: NavPathStack = new NavPathStack()
  @State teamInfo?: V2NIMTeam = undefined
  //本人的群成员身份
  mineTeamMember?: V2NIMTeamMember

  initTeamData() {
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', (team) => {
      if (team.teamId === this.teamInfo?.teamId) {
        this.teamInfo = team
      }
    })
    if (this.teamInfo) {
      TeamRepo.getTeamMemberListByIds(
        this.teamInfo.teamId,
        this.teamInfo.teamType,
        [ChatKitClient.getLoginUserId()]
      ).then((result) => {
        this.mineTeamMember = result[0]
      })
    }

  }

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.team_info'),
        backgroundColor: '#ffEFF1F4',
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })
      if (this.teamInfo) {
        Column() {
          Row() {
            Text($r('app.string.team_avatar'))
              .fontSize(16)
              .fontColor('ff333333')

            Blank().layoutWeight(1)

            CommonAvatar({
              item: new AvatarItem(
                this.teamInfo?.avatar,
                this.teamInfo?.name,
                AvatarColorUntil.getBackgroundColorById(this.teamInfo?.teamId)
              )
            })
              .width(42)
              .height(42)
              .margin({
                right: 12
              })

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
            this.goToEditTeamAvatar()
          })

          Row() {
            Text($r('app.string.team_name'))
              .fontSize(16)
              .fontColor('ff333333')

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
            this.goToEditTeamName()
          })

          if (!TeamRepo.isGroupTeam(this.teamInfo)) {
            Row() {
              Text($r('app.string.team_des'))
                .fontSize(16)
                .fontColor('ff333333')

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
              this.goToEditTeamDesc()
            })
          }
        }.backgroundColor(Color.White)
        .borderRadius(8)
      }


    }
    .hideTitleBar(true)
    .backgroundColor('#ffEFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.teamInfo = context.pathStack.getParamByName('TeamInfoPage')[0] as V2NIMTeam
      this.initTeamData()
    })
  }

  //修改群名称
  goToEditTeamName() {
    let params: TextEditParams = {
      content: this.teamInfo?.name ?? '',
      title: $r('app.string.team_name'),
      maxLength: 30,
      showSave: this.havePermissionToEditTeamInfo()
    }
    this.pathStack.pushPath({
      name: 'TextEditPage',
      param: params,
      onPop: (popInfo: PopInfo) => {
        let teamName = popInfo.result as string | undefined
        if (teamName) {
          let params: V2NIMUpdateTeamInfoParams = {
            name: teamName
          }
          TeamRepo.updateTeamInfo(
            this.teamInfo?.teamId,
            V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
            params
          )
        }
      }
    })
  }

  //修改群介绍
  goToEditTeamDesc() {
    let params: TextEditParams = {
      content: this.teamInfo?.intro ?? '',
      title: $r('app.string.team_des'),
      maxLength: 100,
      maxLine: 5,
      height: 110,
      showSave: this.havePermissionToEditTeamInfo()
    }
    this.pathStack.pushPath({
      name: 'TextEditPage',
      param: params,
      onPop: (popInfo: PopInfo) => {
        let teamDesc = popInfo.result as string | undefined
        if (teamDesc) {
          let params: V2NIMUpdateTeamInfoParams = {
            intro: teamDesc
          }
          TeamRepo.updateTeamInfo(
            this.teamInfo?.teamId,
            V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
            params
          )
        }
      }
    })
  }

  havePermissionToEditTeamInfo(): boolean {
    if (this.teamInfo?.updateInfoMode == V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_ALL) {
      return true
    }
    return this.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
      || this.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
  }

  //修改群头像
  goToEditTeamAvatar() {
    const param: AvatarEditParams = {
      avatar: this.teamInfo?.avatar ?? '',
      showSave: this.havePermissionToEditTeamInfo()
    }
    this.pathStack.pushPath({
      name: 'TeamAvatarPage',
      param: param,
      onPop: (popInfo: PopInfo) => {
        let teamAvatar = popInfo.result as string | undefined
        if (teamAvatar) {
          let params: V2NIMUpdateTeamInfoParams = {
            avatar: teamAvatar
          }
          TeamRepo.updateTeamInfo(
            this.teamInfo?.teamId,
            V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
            params
          )
        }
      }
    })
  }
}

@Builder
export function TeamInfoPageBuilder() {
  TeamInfoPage()
}