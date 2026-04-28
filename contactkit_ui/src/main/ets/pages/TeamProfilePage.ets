/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ErrorUtils, TeamRepo } from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  NavigationBackBuilder,
  NECommonUtils
} from '@nimkit/common';
import { V2NIMError, V2NIMErrorCode, V2NIMTeam, V2NIMTeamType, V2NIMUser } from '@nimsdk/base';
import {
  resolveTeamApplyJoinErrorToastType,
  TeamApplyJoinToastType
} from '../utils/TeamProfileUtils';

const TEAM_MEMBER_LIMIT_ERROR_CODE = 801

// 跳转页面入口函数
@Builder
export function TeamProfilePageBuilder() {
  TeamProfilePage()
}

@ComponentV2
export struct TeamProfilePage {
  pathStack: NavPathStack = new NavPathStack()
  @Local team: V2NIMTeam | undefined = undefined
  @Local ownerName: string = ''
  @Local isGroupTeam: boolean = false
  @Local isMember: boolean = false

  onTeamJoinedFun = (team: V2NIMTeam) => {
    if (this.team && team.teamId === this.team.teamId) {
      this.team = team
      this.isMember = true
    }
  }

  async loadOwnerInfo() {
    if (!this.team?.ownerAccountId) {
      return
    }

    const teamType = this.team.teamType

    let user: V2NIMUser | undefined = undefined
    let friendAlias: string | undefined = undefined
    let teamNick: string | undefined = undefined

    // 1. 获取用户基本信息（必须成功）
    try {
      const users: V2NIMUser[] = await ContactRepo.getUserList([this.team.ownerAccountId])
      if (users.length === 0) {
        return
      }
      user = users[0]
    } catch (err) {
      console.error('TeamProfilePage loadOwnerInfo getUserList error', err)
      return
    }

    // 2. 查询好友备注（仅当群主是好友时，失败不影响后续逻辑）
    try {
      const friends = await ContactRepo.getFriendByIds([this.team.ownerAccountId])
      friendAlias = friends.length > 0 ? friends[0].alias : undefined
    } catch (err) {
      console.error('TeamProfilePage loadOwnerInfo getFriendByIds error', err)
    }

    // 3. 查询群成员昵称（失败不影响后续逻辑）
    try {
      const members = await TeamRepo.getTeamMemberListByIds(
        this.team.teamId,
        teamType,
        [this.team.ownerAccountId]
      )
      teamNick = members.length > 0 ? members[0].teamNick : undefined
    } catch (err) {
      console.error('TeamProfilePage loadOwnerInfo getTeamMemberListByIds error', err)
    }

    // 4. 按优先级返回：好友备注 > 群昵称 > 个人昵称 > accountId
    this.ownerName = friendAlias || teamNick || user.name || user.accountId
  }

  /**
   * 查询当前用户是否是该群成员
   * 通过 getTeamMemberListByIds 查询自己的账号，能查到说明是成员
   */
  async checkMembership() {
    if (!this.team) {
      return
    }
    try {
      const myAccountId = ChatKitClient.getLoginUserId()
      const members = await TeamRepo.getTeamMemberListByIds(
        this.team.teamId,
        this.team.teamType,
        [myAccountId]
      )
      this.isMember = members.some(member => member.accountId === myAccountId && member.inTeam !== false)
    } catch (err) {
      // 查询失败说明不是成员
      this.isMember = false
    }
  }

  async applyJoinTeam() {
    if (!this.team) {
      return
    }
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }

    // 检查群人数是否已达上限
    if (this.team.memberCount >= this.team.memberLimit) {
      NECommonUtils.showToast($r('app.string.team_member_limit_tip'))
      return
    }

    try {
      const result: V2NIMTeam | undefined = await TeamRepo.applyJoinTeam(
        this.team.teamId,
        this.team.teamType
      )
      if (result) {
        this.team = result
      }
      this.isMember = result?.isValidTeam ?? false
      if (this.isMember && result) {
        this.goChat(result.teamId, result.teamType)
        return
      }

      if (result) {
        // 未直接加入时，再兜底查询一次本地成员状态，兼容旧返回语义。
        await this.checkMembership()
        if (this.isMember) {
          this.goChat(result.teamId, result.teamType)
        } else {
          NECommonUtils.showToast($r('app.string.team_apply_join_tip'))
        }
      }
    } catch (err) {
      console.error('TeamProfilePage applyJoinTeam error', err)
      const error = err as V2NIMError
      if (error?.code === TEAM_MEMBER_LIMIT_ERROR_CODE) {
        NECommonUtils.showToast($r('app.string.team_member_limit_tip'))
      } else if (error?.code === V2NIMErrorCode.V2NIM_ERROR_CODE_JOINED_TEAM_LIMIT) {
        NECommonUtils.showToast($r('app.string.joined_team_limit_tip'))
      } else if (resolveTeamApplyJoinErrorToastType(error?.code) === TeamApplyJoinToastType.APPLICATION_SENT) {
        NECommonUtils.showToast($r('app.string.team_apply_join_tip'))
      } else {
        NECommonUtils.showToast($r('app.string.team_apply_join_error'))
      }
    }
  }

  goChat(teamId: string, teamType: V2NIMTeamType) {
    const conversationId = teamType === V2NIMTeamType.V2NIM_TEAM_TYPE_SUPER
      ? ChatKitClient.nim.conversationIdUtil.superTeamConversationId(teamId)
      : ChatKitClient.nim.conversationIdUtil.teamConversationId(teamId)
    this.pathStack.pushPath({
      name: 'ChatTeamPage',
      param: conversationId
    })
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.team_profile_title'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        // 群头像和名称
        Row() {
          CommonAvatar({
            item: new AvatarItem(this.team?.avatar,
              this.team?.name?.substring(0, 2) ?? '',
              AvatarColorUntil.getBackgroundColorById(this.team?.teamId ?? '')),
            roundRadius: 30,
            textSize: 22
          })
            .width(60)
            .height(60)
            .margin({ left: 20 })

          Column({ space: 8 }) {
            Text(this.team?.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .margin({ left: 16 })
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20, right: 20 })

        // 群信息列表
        Column() {
          // 群ID
          this.InfoRow($r('app.string.team_profile_id'), this.team?.teamId ?? '')

          // 群主（讨论组隐藏）
          if (!this.isGroupTeam && this.ownerName) {
            this.InfoRow($r('app.string.team_profile_owner'), this.ownerName)
          }

          // 群介绍
          if (this.team?.intro) {
            this.InfoRow($r('app.string.team_profile_intro'), this.team.intro)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        Blank()

        // 底部按钮
        Button(this.isMember ? $r('app.string.team_profile_chat') : $r('app.string.team_profile_join'),
          { type: ButtonType.Normal })
          .width('90%')
          .height(44)
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor('#337EFF')
          .borderRadius(8)
          .margin({ bottom: 40 })
          .onClick(() => {
            if (this.isMember) {
              this.goChat(this.team!.teamId, this.team!.teamType)
            } else {
              this.applyJoinTeam()
            }
          })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.team = this.pathStack.getParamByName('TeamProfilePage')[0] as V2NIMTeam
      if (this.team) {
        this.isGroupTeam = TeamRepo.isGroupTeam(this.team)
        // 仅非讨论组才加载群主信息
        if (!this.isGroupTeam) {
          this.loadOwnerInfo()
        }
        this.checkMembership()
      }
      ChatKitClient.nim.teamService?.on('onTeamJoined', this.onTeamJoinedFun)
    })
    .onDisAppear(() => {
      ChatKitClient.nim.teamService?.off('onTeamJoined', this.onTeamJoinedFun)
    })
  }

  @Builder
  InfoRow(label: ResourceStr, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#999999')
        .width(60)
      Text(value)
        .fontSize(14)
        .fontColor('#333333')
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }
}
