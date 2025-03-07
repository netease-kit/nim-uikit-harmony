/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatKitClient, keyExtensionAtAll, TeamRepo, typeExtensionAllowAll } from '@nimkit/chatkit'
import { JSONUtil } from '@nimkit/common'
import { V2NIMTeam, V2NIMTeamMember, V2NIMTeamMemberRole, V2NIMTeamMemberRoleQueryType } from '@nimsdk/base'

@ObservedV2
export class TeamManageViewModel {
  @Trace teamInfo?: V2NIMTeam = undefined
  @Trace managerCount?: number = undefined
  //管理员
  managerList: V2NIMTeamMember[] = []

  init(teamInfo?: V2NIMTeam) {
    this.teamInfo = teamInfo
    this.initTeamListener()
  }

  //获取管理员数量
  getTeamManagerCount() {
    if (this.teamInfo) {
      TeamRepo.getTeamMemberList(
        this.teamInfo.teamId, this.teamInfo.teamType,
        { roleQueryType: V2NIMTeamMemberRoleQueryType.V2NIM_TEAM_MEMBER_ROLE_QUERY_TYPE_MANAGER }
      ).then((result) => {
        if (result !== undefined) {
          this.managerList = result.memberList
          this.managerCount = result.memberList.length - 1
        }
      }).catch((e: Error) => {
        ChatKitClient.logger?.debug(`getTeamManagerCount ${e.message}`)
      })
    }
  }

  /**
   * 更新群信息
   */
  updateTeamInfo() {
    if (this.teamInfo) {
      TeamRepo.getTeamInfo(this.teamInfo.teamId, this.teamInfo.teamType)
        .then((team) => {
          this.teamInfo = team
        })
    }
  }

  onTeamInfoUpdated(team: V2NIMTeam) {
    if (team.teamId === this.teamInfo?.teamId) {
      this.teamInfo = team
    }
  }

  onSyncFinished() {
    this.updateTeamInfo()
    this.getTeamManagerCount()
  }

  onTeamMemberInfoUpdated(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamInfo?.teamId) {
      let managerMembers = members.filter((e) => {
        let exitManager = this.managerList.find(m => m.accountId === e.accountId)
        if (exitManager) {
          return false
        }
        return e.memberRole ===
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER || e.memberRole ===
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
      })

      this.managerList.push(...managerMembers)

      let normalMembers = members.filter((e) => e.memberRole ===
      V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
        && this.managerList.find((a) => a.accountId === e.accountId))

      this.managerList = this.managerList.filter((m) => !normalMembers.find((e) => e.accountId === m.accountId))

      this.managerCount = this.managerList.length - 1;
    }
  }

  /**
   * 获取@所有人的权限
   * @param team
   */
  getAitAllPermission(): string {
    let result = typeExtensionAllowAll
    if (this.teamInfo?.serverExtension) {
      if (JSONUtil.isJSONString(this.teamInfo.serverExtension)) {
        let localObject = JSON.parse(this.teamInfo.serverExtension) as object
        if (localObject?.[keyExtensionAtAll]) {
          result = localObject?.[keyExtensionAtAll]
        }
      }
    }
    return result
  }

  /**
   * 初始化监听
   */
  initTeamListener() {
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', this.onTeamInfoUpdated.bind(this))
    ChatKitClient.nim.teamService?.on('onSyncFinished', this.onSyncFinished.bind(this))
    ChatKitClient.nim?.teamService?.on('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated.bind(this))
  }

  destroy() {
    ChatKitClient.nim.teamService?.off('onTeamInfoUpdated', this.onTeamInfoUpdated)
    ChatKitClient.nim.teamService?.off('onSyncFinished', this.onSyncFinished)
    ChatKitClient.nim?.teamService?.off('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated)
  }
}
