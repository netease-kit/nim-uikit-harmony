/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, TeamRepo } from '@nimkit/chatkit'
import {
  AvatarColorUntil,
  NavigationBackBuilder,
  NECommonUtils,
  TextEditParams
} from '@nimkit/common'
import {
  V2NIMTeam,
  V2NIMTeamMemberRole,
  V2NIMTeamType,
  V2NIMTeamUpdateInfoMode,
  V2NIMUpdateTeamInfoParams
} from '@nimsdk/base'
import { TeamInfoViewModel } from '../viewModel/TeamInfoViewModel'
import { AvatarEditParams } from './TeamAvatarPage'

export interface TeamInfoPageParam {
  teamInfo: V2NIMTeam
  teamAvatar: string
  onTeamAvatarChanged?: (avatar: string) => void
}

@ComponentV2
struct TeamInfoPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: TeamInfoViewModel = new TeamInfoViewModel()
  onTeamAvatarChanged?: (avatar: string) => void

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.team_info'),
        backgroundColor: '#ffEFF1F4',
        leftButtonAction: () => {
          this.pathStack.pop(this.viewModel.teamAvatar)
        }
      })
      if (this.viewModel.teamInfo) {
        Column() {
          Row() {
            Text($r('app.string.team_avatar'))
              .fontSize(16)
              .fontColor('ff333333')

            Blank().layoutWeight(1)

            if (this.viewModel.teamAvatar) {
              Image(this.viewModel.teamAvatar)
                .width(42)
                .height(42)
                .draggable(false)
                .objectFit(ImageFit.Cover)
                .syncLoad(false)
                .borderRadius(20)
                .margin({
                  right: 12
                })
            } else {
              Stack() {
                Text(this.viewModel.teamInfo.name)
                  .fontSize(14)
                  .fontColor('#ffFFFFFF')
                  .ellipsisMode(EllipsisMode.END)
                  .textAlign(TextAlign.Center)
                  .margin({
                    left: 6,
                    right: 6
                  })
                  .width('100%')
                  .maxLines(1)
              }
              .width(42)
              .height(42)
              .backgroundColor(AvatarColorUntil.getBackgroundColorById(this.viewModel.teamInfo.teamId))
              .borderRadius(20)
              .margin({
                right: 12
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

          if (!TeamRepo.isGroupTeam(this.viewModel.teamInfo)) {
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
      const param = context.pathStack.getParamByName('TeamInfoPage')[0] as TeamInfoPageParam | V2NIMTeam
      if (this.isTeamInfoPageParam(param)) {
        const routeParam = param as TeamInfoPageParam
        this.onTeamAvatarChanged = routeParam.onTeamAvatarChanged
        this.viewModel.initTeamData(routeParam.teamInfo, routeParam.teamAvatar)
      } else {
        // Keep existing callers that pass V2NIMTeam directly working.
        this.viewModel.initTeamData(param as V2NIMTeam)
      }
      this.viewModel.getMineTeamMember()
    })
  }

  private isTeamInfoPageParam(param?: TeamInfoPageParam | V2NIMTeam): boolean {
    // NavPathStack may return a plain object without the original class prototype.
    return !!param && typeof (param as TeamInfoPageParam).teamInfo === 'object'
  }

  //修改群名称
  goToEditTeamName() {
    let params: TextEditParams = {
      content: this.viewModel.teamInfo?.name ?? '',
      title: $r('app.string.team_name'),
      maxLength: 30,
      showSave: this.havePermissionToEditTeamInfo(),
      emptyTextEnable: false
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
            this.viewModel.teamInfo?.teamId,
            V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
            params
          ).catch((e: Error) => {
            ChatKitClient.logger?.debug(`update team info error:${e.message}`)
            NECommonUtils.showToast($r('app.string.common_operate_failed'))
          })
        }
      }
    })
  }

  //修改群介绍
  goToEditTeamDesc() {
    let params: TextEditParams = {
      content: this.viewModel.teamInfo?.intro ?? '',
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
        if (teamDesc !== undefined) {
          let params: V2NIMUpdateTeamInfoParams = {
            intro: teamDesc
          }
          TeamRepo.updateTeamInfo(
            this.viewModel.teamInfo?.teamId,
            V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
            params
          ).catch((e: Error) => {
            ChatKitClient.logger?.debug(`update team info error:${e.message}`)
            NECommonUtils.showToast($r('app.string.common_operate_failed'))
          })
        }
      }
    })
  }

  havePermissionToEditTeamInfo(): boolean {
    if (this.viewModel.teamInfo?.updateInfoMode == V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_ALL) {
      return true
    }
    return this.viewModel.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
      || this.viewModel.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
  }

  //修改群头像
  goToEditTeamAvatar() {
    const param: AvatarEditParams = {
      avatar: this.viewModel.teamAvatar,
      showSave: this.havePermissionToEditTeamInfo()
    }
    this.pathStack.pushPath({
      name: 'TeamAvatarPage',
      param: param,
      onPop: (popInfo: PopInfo) => {
        let teamAvatar = popInfo.result as string | undefined
        if (teamAvatar) {
          const previousAvatar = this.viewModel.teamAvatar
          // Keep the info page showing the new avatar before SDK callback arrives.
          this.applyLocalTeamAvatar(teamAvatar)
          let params: V2NIMUpdateTeamInfoParams = {
            avatar: teamAvatar
          }
          TeamRepo.updateTeamInfo(
            this.viewModel.teamInfo?.teamId,
            this.viewModel.teamInfo?.teamType ?? V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
            params
          ).catch((e: Error) => {
            this.applyLocalTeamAvatar(previousAvatar)
            ChatKitClient.logger?.debug(`update team info error:${e.message}`)
            NECommonUtils.showToast($r('app.string.common_operate_failed'))
          })
        }
      }
    })
  }

  applyLocalTeamAvatar(avatar: string) {
    this.viewModel.applyLocalTeamAvatar(avatar)
    this.onTeamAvatarChanged?.(avatar)
  }

  aboutToDisappear(): void {
    this.viewModel.destroy()
  }
}

@Builder
export function TeamInfoPageBuilder() {
  TeamInfoPage()
}
