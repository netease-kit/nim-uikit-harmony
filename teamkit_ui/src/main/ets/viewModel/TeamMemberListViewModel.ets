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
  V2NIMTeamType
} from '@nimsdk/base'

@ObservedV2
export class TeamMemberListViewModel {
  //群Id
  teamId?: string
  //是否结束
  isFinish: boolean = false
  //下次请求所需token
  nextToken?: string | undefined
  //每次请求的条数限制
  teamMemberLimit = 100
  @Trace memberList: TeamMemberWithUser[] = []
  //自己的群身份
  @Trace mineTeamMember: V2NIMTeamMember | undefined = undefined

  init(teamId: string) {
    this.teamId = teamId
    this.initMemberChangeListener()
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
          memberInfo.teamMember = m
          this.memberList.splice(index, 0, memberInfo)
          if (m.accountId === ChatKitClient.getLoginUserId()) {
            this.mineTeamMember = m
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
      let accIds: string[] = members.map(m => m.accountId)
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
    ChatKitClient.nim.teamService?.on('onTeamMemberLeft', this.onTeamMemberLeft.bind(this))
    ChatKitClient.nim.teamService?.on('onTeamMemberKicked', this.onTeamMemberKicked.bind(this))

    ChatKitClient.nim.teamService?.on('onTeamMemberJoined', this.onTeamMemberJoined.bind(this))
  }

  /**
   * 踢除群成员
   * @param accId
   */
  kickTeamMember(kickMemberId?: string) {
    if (this.teamId && kickMemberId) {
      TeamRepo.kickMember(
        this.teamId,
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        [kickMemberId]
      ).then(() => {
        this.memberList = this.memberList.filter(member => member.getAccId() !== kickMemberId)
      })
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
            limit: this.teamMemberLimit,
            nextToken: this.nextToken,
            direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
          })
        if (result) {
          this.isFinish = result.finished
          this.nextToken = result.nextToken
          this.memberList.push(...result.memberList)
          this.memberList.sort((a, b) => this.sortTeamMember(a, b))
          if (first) {
            let mineMember = result.memberList.find(member => member.getAccId() === ChatKitClient.getLoginUserId())
            if (mineMember) {
              this.mineTeamMember = mineMember.teamMember
            } else {
              this.mineTeamMember = (await TeamRepo.getTeamMembersByIds(
                this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, [ChatKitClient.getLoginUserId()]
              )
              ).find(m => m.getAccId() === ChatKitClient.getLoginUserId())?.teamMember
            }
          }
        }
      } catch (e) {

      }

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

    ChatKitClient.nim.teamService?.off('onTeamMemberJoined', this.onTeamMemberJoined)
  }
}