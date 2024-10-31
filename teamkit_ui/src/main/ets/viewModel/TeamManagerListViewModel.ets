/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatKitClient, TeamMemberWithUser, TeamRepo } from '@nimkit/chatkit'
import {
  V2NIMFriend,
  V2NIMQueryDirection,
  V2NIMTeamMember,
  V2NIMTeamMemberRole,
  V2NIMTeamMemberRoleQueryType,
  V2NIMTeamType
} from '@nimsdk/base'

@ObservedV2
export class TeamMangerListViewModel {
  //群Id
  teamId?: string
  //是否结束
  isFinish: boolean = false
  //下次请求所需token
  nextToken?: string | undefined
  //每次请求的条数限制
  teamMemberLimit = 100
  @Trace managerList: TeamMemberWithUser[] = []
  @Trace haveInitData: boolean = false

  init(teamId: string) {
    this.teamId = teamId
    this.initMemberChangeListener()
  }

  onFriendInfoChanged(friend: V2NIMFriend) {
    let index = this.managerList.findIndex((member) => {
      return member.getAccId() === friend.accountId
    })

    if (index >= 0) {
      let memberInfo = this.managerList[index]
      this.managerList.splice(index, 1)
      memberInfo.friendInfo = friend
      this.managerList.splice(index, 0, memberInfo)
    }
  }

  onTeamMemberInfoUpdated(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let managerMembers = members.filter((e) => {
        let exitManager = this.managerList.find(m => m.getAccId() === e.accountId)
        if (exitManager) {
          return false
        }
        return e.memberRole ===
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER || e.memberRole ===
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
      })

      if (managerMembers.length > 0) {
        let accIds = managerMembers.map((e) => e.accountId)
        this.addNewManager(accIds)
      }

      let normalMembers = members.filter((e) => e.memberRole ===
      V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
        && this.managerList.find((a) => a.teamMember.accountId === e.accountId))

      this.managerList = this.managerList.filter((m) =>!normalMembers.find((e) => e.accountId === m.getAccId()))


    }
  }

  onTeamMemberLeft(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.managerList = this.managerList.filter(m =>!removeIds.includes(m.getAccId()))
    }
  }

  onTeamMemberKicked(accId: string, members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.managerList = this.managerList.filter(m =>!removeIds.includes(m.getAccId()))
    }
  }

  onSyncFinished() {
    this.getTeamManagerList(true)
  }

  /**
   * 初始化成员信息变化回调
   */
  initMemberChangeListener() {
    ChatKitClient.nim.friendService?.on("onFriendInfoChanged", this.onFriendInfoChanged.bind(this))
    //群成员信息变更
    ChatKitClient.nim.teamService?.on('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated.bind(this))
    ChatKitClient.nim.teamService?.on('onTeamMemberLeft', this.onTeamMemberLeft.bind(this))
    ChatKitClient.nim.teamService?.on('onTeamMemberKicked', this.onTeamMemberKicked.bind(this))
    ChatKitClient.nim.teamService?.on('onSyncFinished', this.onSyncFinished.bind(this))
  }

  /**
   * 移除管理员身份
   * @param accId
   */
  removeTeamManager(removeManagerId?: string) {
    if (this.teamId && removeManagerId) {
      TeamRepo.updateTeamMemberRole(
        this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        [removeManagerId], V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
      ).then(() => {
        this.managerList = this.managerList.filter(member => member.getAccId() !== removeManagerId)
      })
    }
  }

  /**
   * 拉取管理员列表
   * @param first
   */
  async getTeamManagerList(first?: boolean) {
    if (first === true) {
      this.isFinish = false
      this.nextToken = undefined
      this.managerList = []
    }
    if (this.isFinish) {
      return
    }
    if (this.teamId) {
      try {
        let result = await TeamRepo.getTeamMembers(this.teamId,
          V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, {
            roleQueryType: V2NIMTeamMemberRoleQueryType.V2NIM_TEAM_MEMBER_ROLE_QUERY_TYPE_MANAGER,
            limit: this.teamMemberLimit,
            nextToken: this.nextToken,
            direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
          })
        if (result) {
          this.isFinish = result.finished
          this.nextToken = result.nextToken
          this.managerList.push(...result.memberList)
          this.managerList = this.managerList.filter((member) =>!member.isOwner())
          this.managerList.sort((a, b) => this.sortTeamMember(a, b))
          this.haveInitData = true
        }
      } catch (e) {

      }
    }
  }

  async addNewManager(memberIds: string[]) {
    if (this.teamId) {
      let members = await TeamRepo.getTeamMembersByIds(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        memberIds)
      this.managerList.push(...members)
      this.managerList.sort((a, b) => this.sortTeamMember(a, b))
    }
  }

  //群成员排序
  sortTeamMember(a: TeamMemberWithUser, b: TeamMemberWithUser): number {
    if (a.teamMember.memberRole === b.teamMember.memberRole) {
      return a.teamMember.joinTime - b.teamMember.joinTime
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
    return a.teamMember.joinTime - b.teamMember.joinTime
  }

  onDestroy() {
    ChatKitClient.nim.friendService?.off("onFriendInfoChanged", this.onFriendInfoChanged)
    //群成员信息变更
    ChatKitClient.nim.teamService?.off('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated)
    ChatKitClient.nim.teamService?.off('onTeamMemberLeft', this.onTeamMemberLeft)
    ChatKitClient.nim.teamService?.off('onTeamMemberKicked', this.onTeamMemberKicked)
    ChatKitClient.nim.teamService?.off('onSyncFinished', this.onSyncFinished)
  }
}
