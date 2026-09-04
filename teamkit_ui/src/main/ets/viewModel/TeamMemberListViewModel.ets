/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import {
  ChatKitClient,
  DisposableBag,
  FriendEventRepo,
  getTeamMemberSearchRenderKey,
  matchesTeamMemberSearchKeyword,
  normalizeSearchKeyword,
  TeamEventRepo,
  TeamMemberCache,
  TeamMemberWithUser,
  TeamRepo,
  UserEventRepo
} from '@nimkit/chatkit'
import {
  V2NIMFriend,
  V2NIMQueryDirection,
  V2NIMTeamMember,
  V2NIMTeamMemberRole,
  V2NIMTeamMemberRoleQueryType,
  V2NIMTeamType,
  V2NIMUser
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
  // 搜索关键字
  @Trace searchKeyword: string = ''
  @Trace isSearching: boolean = false
  @Trace searchLoadFailed: boolean = false
  //自己的群身份
  @Trace mineTeamMember: V2NIMTeamMember | undefined = undefined
  private disposableBag: DisposableBag = new DisposableBag()
  private teamMemberCache: TeamMemberCache = TeamMemberCache.getInstance()
  private visibleMemberLimit: number = 100
  private searchGeneration: number = 0
  private listSessionId: number = 0
  private showManagerRole: boolean = true

  init(teamId: string, showManagerRole: boolean = true) {
    this.teamId = teamId
    this.showManagerRole = showManagerRole
    this.memberList = []
    this.searchKeyword = ''
    this.isSearching = false
    this.searchLoadFailed = false
    this.visibleMemberLimit = this.teamMemberLimit
    this.searchGeneration += 1
    this.listSessionId += 1
    this.teamMemberCache.intTeamInfo(teamId)
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

  /**
   * 用户信息变化回调 - 更新成员列表中的用户信息（如头像、昵称等）
   * @param users 变化的用户信息列表
   */
  onUserProfileChanged(users: V2NIMUser[]) {
    users.forEach((user) => {
      let index = this.memberList.findIndex((member) => {
        return member.getAccId() === user.accountId
      })
      if (index >= 0) {
        let memberInfo = this.memberList[index]
        this.memberList.splice(index, 1)
        memberInfo.userInfo = user
        this.memberList.splice(index, 0, memberInfo)
      }
    })
  }

  onTeamMemberInfoUpdated(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let needResort = false
      members.forEach((m) => {
        let index = this.memberList.findIndex((member) => {
          return member.getAccId() === m.accountId
        })
        if (index >= 0) {
          let memberInfo = this.memberList[index]
          this.memberList.splice(index, 1)
          memberInfo.teamMember = m
          this.memberList.splice(index, 0, memberInfo)
          needResort = true
          if (m.accountId === ChatKitClient.getLoginUserId()) {
            this.mineTeamMember = m
          }
        }
      })
      if (needResort) {
        this.memberList.sort((a, b) => this.sortTeamMember(a, b))
      }
    }
  }

  onTeamMemberLeft(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.memberList = this.memberList.filter(m => !removeIds.includes(m.getAccId()))
    }
  }

  onTeamMemberKicked(accId: string, members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.memberList = this.memberList.filter(m => !removeIds.includes(m.getAccId()))
    }
  }

  onTeamMemberJoined(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      const currentSessionId = this.listSessionId
      const currentTeamId = this.teamId
      let accIds: string[] = members.map(m => m.accountId)
      TeamRepo.getTeamMembersByIds(currentTeamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        accIds).then((newMembers) => {
          if (!currentTeamId || !this.isCurrentSession(currentSessionId, currentTeamId)) {
            return
          }
          this.memberList.push(...newMembers)
          this.memberList.sort((a, b) => this.sortTeamMember(a, b))
        })
    }
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
      UserEventRepo.onUserProfileChanged((users: V2NIMUser[]): void => {
        this.onUserProfileChanged(users)
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
      TeamEventRepo.onTeamMemberJoined((members: V2NIMTeamMember[]): void => {
        this.onTeamMemberJoined(members)
      })
    ])
  }

  /**
   * 踢除群成员
   * @param accId
   */
  kickTeamMember(kickMemberId?: string) {
    if (this.teamId && kickMemberId) {
      const currentSessionId = this.listSessionId
      const currentTeamId = this.teamId
      TeamRepo.kickMember(
        currentTeamId,
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        [kickMemberId]
      ).then(() => {
        if (!this.isCurrentSession(currentSessionId, currentTeamId)) {
          return
        }
        this.memberList = this.memberList.filter(member => member.getAccId() !== kickMemberId)
        if (this.teamMemberCache.teamId === currentTeamId) {
          this.teamMemberCache.membersMap.delete(kickMemberId)
        }
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
      this.visibleMemberLimit = this.teamMemberLimit
    } else {
      this.visibleMemberLimit += this.teamMemberLimit
    }
    if (this.teamId) {
      const currentSessionId = this.listSessionId
      const currentTeamId = this.teamId
      try {
        this.teamMemberCache.intTeamInfo(currentTeamId)
        if (first === true && this.showManagerRole) {
          // 先合并群主和管理员，确保角色排序在分页前生效
          await this.loadManagerMembers(currentTeamId, currentSessionId)
          if (!this.isCurrentSession(currentSessionId, currentTeamId)) {
            return
          }
        }
        const cachedMembers = this.teamMemberCache.getAllMembers(currentTeamId)
        if (cachedMembers.length < this.visibleMemberLimit &&
          !this.teamMemberCache.haveLoadAllMember(currentTeamId)) {
          await this.teamMemberCache.getMoreMemberList()
        }
        if (!this.isCurrentSession(currentSessionId, currentTeamId)) {
          return
        }
        this.syncVisibleMembersFromCache()
        if (first) {
          const mineTeamMember = await this.teamMemberCache.getMineMember(currentTeamId)
          if (!this.isCurrentSession(currentSessionId, currentTeamId)) {
            return
          }
          this.mineTeamMember = mineTeamMember
        }
        if (this.isCurrentSession(currentSessionId, currentTeamId)) {
        }
      } catch (e) {
        // 页面保留当前缓存数据，后续触底或搜索可以再次触发加载。
      }

    }

  }

  /**
   * 搜索当前群完整成员范围。
   */
  async searchTeamMembers(keyword: string): Promise<void> {
    const normalizedKeyword = normalizeSearchKeyword(keyword)
    this.searchKeyword = normalizedKeyword
    this.searchGeneration += 1
    const currentSearchGeneration = this.searchGeneration
    this.searchLoadFailed = false
    if (normalizedKeyword.length === 0) {
      this.isSearching = false
      return
    }

    this.isSearching = true
    let searchSource = this.memberList
    if (this.teamId) {
      const currentTeamId = this.teamId
      this.teamMemberCache.intTeamInfo(currentTeamId)
      const loadedAll = await this.teamMemberCache.loadAllTeamMember()
      if (currentSearchGeneration !== this.searchGeneration || normalizedKeyword !== this.searchKeyword ||
        currentTeamId !== this.teamId) {
        return
      }
      if (!loadedAll) {
        this.isSearching = false
        this.searchLoadFailed = true
        return
      }
      searchSource = this.teamMemberCache.getAllMembers(currentTeamId)
    }
    this.memberList = searchSource
    this.isSearching = false
  }

  clearSearch() {
    this.searchGeneration += 1
    this.searchKeyword = ''
    this.isSearching = false
    this.searchLoadFailed = false
    this.syncVisibleMembersFromCache()
  }

  getDisplayList(): TeamMemberWithUser[] {
    if (this.isSearching || this.searchLoadFailed) {
      return []
    }
    if (this.searchKeyword.length === 0) {
      return this.memberList
    }
    return this.memberList.filter((member: TeamMemberWithUser): boolean =>
      matchesTeamMemberSearchKeyword(member, this.searchKeyword))
  }

  getMemberRenderKey(member: TeamMemberWithUser): string {
    return getTeamMemberSearchRenderKey(member, this.searchKeyword)
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
    this.searchGeneration += 1
    this.listSessionId += 1
    this.disposableBag.dispose()
  }

  private isCurrentSession(sessionId: number, teamId: string): boolean {
    return this.listSessionId === sessionId && this.teamId === teamId
  }

  private async loadManagerMembers(teamId: string, sessionId: number): Promise<void> {
    const result = await TeamRepo.getTeamMembers(teamId,
      V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, {
        roleQueryType: V2NIMTeamMemberRoleQueryType.V2NIM_TEAM_MEMBER_ROLE_QUERY_TYPE_MANAGER,
        limit: this.teamMemberLimit,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
      }).catch(() => undefined)
    if (!result || !this.isCurrentSession(sessionId, teamId)) {
      return
    }
    result.memberList.forEach((member: TeamMemberWithUser) => {
      this.teamMemberCache.membersMap.set(member.getAccId(), member)
    })
  }

  private syncVisibleMembersFromCache(): void {
    if (!this.teamId) {
      return
    }
    const cachedMembers = this.teamMemberCache.getAllMembers(this.teamId)
    this.memberList = cachedMembers.slice(0, this.visibleMemberLimit)
    this.nextToken = this.teamMemberCache.nextToken
    this.isFinish = this.teamMemberCache.haveLoadAllMember(this.teamId) &&
      this.memberList.length >= cachedMembers.length
  }
}
