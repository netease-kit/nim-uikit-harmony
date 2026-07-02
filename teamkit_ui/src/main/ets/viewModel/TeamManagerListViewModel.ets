/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { DisposableBag, FriendEventRepo, TeamEventRepo, TeamMemberWithUser, TeamRepo } from '@nimkit/chatkit'
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
  //是否正在拉取中，避免重复分页
  isLoading: boolean = false
  //下次请求所需token
  nextToken?: string | undefined
  //每次请求的条数限制
  teamMemberLimit = 100
  @Trace managerList: TeamMemberWithUser[] = []
  @Trace haveInitData: boolean = false
  private disposableBag: DisposableBag = new DisposableBag()

  needFillNextPage(): boolean {
    return !this.isFinish && this.managerList.length < this.teamMemberLimit
  }

  appendManagerList(members: TeamMemberWithUser[]) {
    let newMembers = members.filter((member) => !member.isOwner() &&
      !this.managerList.find((item) => item.getAccId() === member.getAccId()))

    if (newMembers.length > 0) {
      this.managerList.push(...newMembers)
      this.managerList.sort((a, b) => this.sortTeamMember(a, b))
    }
  }

  removeManagersFromList(removeIds: string[]) {
    let oldLength = this.managerList.length
    this.managerList = this.managerList.filter((member) => !removeIds.includes(member.getAccId()))
    if (this.managerList.length < oldLength && this.needFillNextPage()) {
      this.getTeamManagerList()
    }
  }

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

      if (normalMembers.length > 0) {
        this.removeManagersFromList(normalMembers.map((member) => member.accountId))
      }


    }
  }

  onTeamMemberLeft(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.removeManagersFromList(removeIds)
    }
  }

  onTeamMemberKicked(accId: string, members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.removeManagersFromList(removeIds)
    }
  }

  onSyncFinished() {
    this.getTeamManagerList(true)
  }

  /**
   * 初始化成员信息变化回调
   */
  initMemberChangeListener() {
    this.onDestroy()
    this.disposableBag.addAll([
      FriendEventRepo.onFriendInfoChanged((friend: V2NIMFriend): void => {
        this.onFriendInfoChanged(friend)
      }),
      TeamEventRepo.onTeamMemberInfoUpdated((members: V2NIMTeamMember[]): void => {
        this.onTeamMemberInfoUpdated(members)
      }),
      TeamEventRepo.onTeamMemberLeft((members: V2NIMTeamMember[]): void => {
        this.onTeamMemberLeft(members)
      }),
      TeamEventRepo.onTeamMemberKicked((accId: string, members: V2NIMTeamMember[]): void => {
        this.onTeamMemberKicked(accId, members)
      }),
      TeamEventRepo.onTeamSyncFinished((): void => {
        this.onSyncFinished()
      })
    ])
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
        this.removeManagersFromList([removeManagerId])
      })
    }
  }

  /**
   * 拉取管理员列表
   * @param first
   */
  async getTeamManagerList(first?: boolean) {
    if (this.isLoading) {
      return
    }
    if (first === true) {
      this.isFinish = false
      this.nextToken = undefined
      this.managerList = []
    }
    if (this.isFinish) {
      return
    }
    if (this.teamId) {
      this.isLoading = true
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
          this.appendManagerList(result.memberList)
          this.haveInitData = true
        }
      } catch (e) {
      } finally {
        this.isLoading = false
      }
    }
  }

  async addNewManager(memberIds: string[]) {
    if (this.teamId) {
      let members = await TeamRepo.getTeamMembersByIds(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        memberIds)
      this.appendManagerList(members)
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
    this.disposableBag.dispose()
  }
}
