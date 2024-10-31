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
export class TeamMemberSelectorViewModel {
  //群Id
  teamId?: string
  //现有管理员数量
  managerCount: number = 0
  //是否结束
  isFinish: boolean = false
  //下次请求所需token
  nextToken?: string | undefined
  //每次请求的条数限制
  teamMemberLimit = 100
  @Trace memberList: TeamMemberWithUser[] = []
  //选中的成员
  @Trace selectedMembers: Set<string> = new Set()

  init(teamId: string, managerCount: number) {
    this.teamId = teamId
    this.managerCount = managerCount
    this.initMemberChangeListener()
  }


  /**
   * 选择切换
   */
  onMemberItemClick(accountId: string) {
    if (this.selectedMembers.has(accountId)) {
      this.selectedMembers.delete(accountId)
    } else {
      this.selectedMembers.add(accountId)
    }
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
          V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, {
            roleQueryType: V2NIMTeamMemberRoleQueryType.V2NIM_TEAM_MEMBER_ROLE_QUERY_TYPE_NORMAL,
            limit: this.teamMemberLimit,
            nextToken: this.nextToken,
            direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
          })
        if (result) {
          this.isFinish = result.finished
          this.nextToken = result.nextToken
          this.memberList.push(...result.memberList)
        }
      } catch (e) {

      }

    }

  }

  onFriendInfoChanged(friend: V2NIMFriend) {
    let index = this.memberList.findIndex((member) => {
      return member.getAccId() === friend.accountId
    })
    if (index >= 0) {
      let memberInfo = this.memberList[index]
      this.memberList.splice(index, 1)
      memberInfo.friendInfo = friend
      this.memberList.splice(index, 0, memberInfo)
    }
  }

  onTeamMemberInfoUpdated(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      members.forEach((m) => {
        let index = this.memberList.findIndex((member) => {
          return member.getAccId() === m.accountId
        })
        if (index >= 0) {
          let memberInfo = this.memberList[index]
          this.memberList.splice(index, 1)
          //是普通成员再添加
          if (m.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL) {
            memberInfo.teamMember = m
            this.memberList.splice(index, 0, memberInfo)
          }

        }
      })
    }
  }

  onTeamMemberLeft(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.memberList = this.memberList.filter(m =>!removeIds.includes(m.getAccId()))
    }
  }

  onTeamMemberKicked(accId: string, members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.memberList = this.memberList.filter(m =>!removeIds.includes(m.getAccId()))
    }
  }

  onTeamMemberJoined(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let accIds = members.map(m => m.accountId)
      TeamRepo.getTeamMembersByIds(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        accIds).then((newMembers) => {
        this.memberList.push(...newMembers)
      })
    }
  }

  /**
   * 初始化成员信息变化回调
   */
  initMemberChangeListener() {
    ChatKitClient.nim.friendService?.on("onFriendInfoChanged", this.onFriendInfoChanged.bind(this))
    //群成员信息变更
    ChatKitClient.nim.teamService?.on('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated.bind(this))
    //群成员离开
    ChatKitClient.nim.teamService?.on('onTeamMemberLeft', this.onTeamMemberLeft.bind(this))
    ChatKitClient.nim.teamService?.on('onTeamMemberKicked', this.onTeamMemberKicked.bind(this))

    ChatKitClient.nim.teamService?.on('onTeamMemberJoined', this.onTeamMemberJoined.bind(this))
  }

  onDestroy() {
    ChatKitClient.nim.friendService?.off("onFriendInfoChanged", this.onFriendInfoChanged)
    //群成员信息变更
    ChatKitClient.nim.teamService?.off('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated)
    //群成员离开
    ChatKitClient.nim.teamService?.off('onTeamMemberLeft', this.onTeamMemberLeft)
    ChatKitClient.nim.teamService?.off('onTeamMemberKicked', this.onTeamMemberKicked)

    ChatKitClient.nim.teamService?.off('onTeamMemberJoined', this.onTeamMemberJoined)
  }
}