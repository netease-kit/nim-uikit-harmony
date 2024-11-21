/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient } from '@nimkit/chatkit'
import { AvatarColorUntil, AvatarItem, CommonAvatar, CommonConfirmDialog, NavigationBackBuilder } from '@nimkit/common'
import { TeamMemberWithUser } from '@nimkit/chatkit/src/main/ets/model/TeamMemberWithUser'
import { TeamMemberListViewModel } from '../viewModel/TeamMemberListViewModel'
import { V2NIMTeamMemberRole } from '@nimsdk/base'

//管理员选择页面参数
export interface MemberListParams {
  //关注身份
  caseRole: boolean,
  teamId: string
}

@ComponentV2
struct TeamMemberListPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: TeamMemberListViewModel = new TeamMemberListViewModel()
  //是否展示踢人按钮
  caseRole: boolean = true
  //踢出群组弹框
  dialogKickMemberDialogController: CustomDialogController = new CustomDialogController({
    builder: CommonConfirmDialog({
      title: $r('app.string.team_remove_member_title'),
      confirmContent: $r('app.string.team_remove_member_content'),
      confirm: () => {
        this.viewModel.kickTeamMember(this.kickMemberId)
      },
    },
    ),
    width: '70%'
  })
  //要踢的成员Id
  kickMemberId?: string

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.team_member'),
        backgroundColor: '#ffffffff',
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })

      List() {
        ForEach(this.viewModel.memberList, (member: TeamMemberWithUser) => {
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
                .width(member.isManager() && this.haveKickPermission(member) ? '50%' : '70%')

              if (this.caseRole && member.isManager()) {
                Blank().layoutWeight(1)

                Text($r('app.string.manager'))
                  .fontColor('#ff337EFF')
                  .fontSize(12)
                  .borderWidth(1)
                  .borderRadius(4)
                  .borderColor('#ffB9D3FF')
                  .backgroundColor('#ffE0ECFF')
                  .padding({
                    top: 4,
                    bottom: 6,
                    left: 12,
                    right: 12
                  })
              }
              if (this.caseRole && member.isOwner()) {
                Blank().layoutWeight(1)

                Text($r('app.string.team_owner'))
                  .fontColor('#ff337EFF')
                  .fontSize(12)
                  .borderWidth(1)
                  .borderRadius(4)
                  .borderColor('#ffB9D3FF')
                  .backgroundColor('#ffE0ECFF')
                  .padding({
                    top: 4,
                    bottom: 6,
                    left: 12,
                    right: 12
                  })
              }

              if (this.haveKickPermission(member)) {
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
                    this.kickMemberId = member.getAccId()
                    this.dialogKickMemberDialogController.open()
                  })
              }

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
      let params = context.pathStack.getParamByName('TeamMemberListPage')[0] as MemberListParams
      this.viewModel.init(params.teamId)
      this.caseRole = params.caseRole
      this.viewModel.getTeamMemberList(true)
    })
  }

  /**
   * 是否有踢人的权力
   * @param member
   * @returns
   */
  haveKickPermission(member: TeamMemberWithUser): boolean {
    if (!this.caseRole) {
      return false
    }
    if (member.isOwner()) {
      return false
    }
    if (member.isManager()) {
      return this.viewModel.mineTeamMember?.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
    }
    if (this.viewModel.mineTeamMember) {
      return this.viewModel.mineTeamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER ||
        this.viewModel.mineTeamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
    }
    return false
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
  }
}

@Builder
export function TeamMemberListPageBuilder() {
  TeamMemberListPage()
}