/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, TeamRepo } from '@nimkit/chatkit'
import { AvatarColorUntil, AvatarItem, CommonAvatar, NavigationBackBuilder } from '@nimkit/common'
import { TeamMemberWithUser } from '@nimkit/chatkit/src/main/ets/model/TeamMemberWithUser'
import { V2NIMTeamMemberRole, V2NIMTeamType } from '@nimsdk/base'

@Component
struct TeamMemberListPage {
  pathStack: NavPathStack = new NavPathStack()
  //群Id
  teamId?: string
  //是否结束
  isFinish: boolean = false
  //下次请求所需token
  nextToken?: string | undefined
  //每次请求的条数限制
  teamMemberLimit = 100
  @State memberList: TeamMemberWithUser[] = []

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
        ForEach(this.memberList, (member: TeamMemberWithUser) => {
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
                .width(member.isOwner() ? '70%' : '100%')

              if (member.isOwner()) {
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
      }
      .listDirection(Axis.Vertical)
      .onReachEnd(() => {
        if (!this.isFinish &&
          this.memberList.length > 0) {
          this.getTeamMemberList()
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
      this.teamId = context.pathStack.getParamByName('TeamMemberListPage')[0] as string
      this.getTeamMemberList(true)
    })
  }

  /**
   * 拉取群成员列表
   * @param first
   */
  async getTeamMemberList(first?: boolean) {
    if (first === true) {
      this.isFinish = false
      this.nextToken = undefined
    }
    if (this.isFinish) {
      return
    }
    if (this.teamId) {
      try {
        let result = await TeamRepo.getTeamMembers(this.teamId,
          V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, this.teamMemberLimit, this.nextToken)
        if (result) {
          this.isFinish = result.finished
          this.nextToken = result.nextToken
          this.memberList.push(...result.memberList)
          this.memberList.sort((a, b) => this.sortTeamMember(a, b))
        }
      } catch (e) {

      }

    }

  }

  //群成员排序
  sortTeamMember(a: TeamMemberWithUser, b: TeamMemberWithUser): number {
    if (a.teamMember.memberRole === b.teamMember.memberRole) {
      return b.teamMember.joinTime - a.teamMember.joinTime
    }
    if (a.teamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER) {
      return -1
    }
    if (b.teamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER) {
      return 1
    }
    if (a.teamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER) {
      return -1
    }
    if (b.teamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER) {
      return 1
    }
    return b.teamMember.joinTime - a.teamMember.joinTime
  }
}

@Builder
export function TeamMemberListPageBuilder() {
  TeamMemberListPage()
}