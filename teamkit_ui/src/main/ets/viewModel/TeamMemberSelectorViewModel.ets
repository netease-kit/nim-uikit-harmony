/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { DisposableBag, FriendEventRepo, IMKitConfigCenter, NEAIUserCache, TeamEventRepo, TeamMemberWithUser, TeamRepo } from '@nimkit/chatkit'
import { TeamMemberSelectorMode } from '@nimkit/chatkit'
import { Logger } from '@nimkit/common'
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
  //群成员选择限制
  selectLimit: number = 0
  // 选择器模式
  mode: TeamMemberSelectorMode = TeamMemberSelectorMode.ADD_MANAGER
  //是否结束
  isFinish: boolean = false
  //下次请求所需token
  nextToken?: string | undefined
  //每次请求的条数限制
  teamMemberLimit = 100
  @Trace memberList: TeamMemberWithUser[] = []
  //选中的成员
  @Trace selectedMembers: Set<string> = new Set()
  // 选中成员数量（用于触发 UI 刷新）
  @Trace selectedCount: number = 0
  // 搜索关键字
  @Trace searchKeyword: string = ''
  // 搜索结果列表
  @Trace searchResultList: TeamMemberWithUser[] = []
  // 是否正在搜索
  @Trace isSearching: boolean = false
  private disposableBag: DisposableBag = new DisposableBag()
  private hasLoadedAIUsers: boolean = false
  private aiUsersLoadingPromise: Promise<void> | undefined = undefined
  private selectorSessionId: number = 0

  /**
   * 初始化
   * @param teamId 群ID
   * @param selectLimit 选择数量限制
   * @param mode 选择器模式
   */
  init(teamId: string, selectLimit: number, mode: TeamMemberSelectorMode) {
    this.teamId = teamId
    this.selectLimit = selectLimit
    this.mode = mode
    this.hasLoadedAIUsers = false
    this.aiUsersLoadingPromise = undefined
    this.selectorSessionId += 1
    this.initMemberChangeListener()
  }

  /**
   * 是否显示管理员和群主
   */
  get showManager(): boolean {
    return this.mode === TeamMemberSelectorMode.FTS_SEARCH
  }

  /**
   * 确认时是否需要检查网络
   */
  get needNetwork(): boolean {
    return this.mode === TeamMemberSelectorMode.ADD_MANAGER
  }


  /**
   * 选择切换
   */
  onMemberItemClick(accountId: string) {
    if (this.selectLimit == 1) {
      if (!this.selectedMembers.has(accountId)) {
        this.selectedMembers.clear()
        this.selectedMembers.add(accountId)
      } else {
        this.selectedMembers.clear()
      }
    } else {
      if (this.selectedMembers.has(accountId)) {
        this.selectedMembers.delete(accountId)
      } else {
        this.selectedMembers.add(accountId)
      }
    }
    this.selectedCount = this.selectedMembers.size
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
      const currentSessionId = this.selectorSessionId
      const currentTeamId = this.teamId
      try {
        await this.ensureAIUsersLoaded()
        let result = await TeamRepo.getTeamMembers(currentTeamId,
          V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, {
            roleQueryType: this.showManager ? undefined :
              V2NIMTeamMemberRoleQueryType.V2NIM_TEAM_MEMBER_ROLE_QUERY_TYPE_NORMAL,
            limit: this.teamMemberLimit,
            nextToken: this.nextToken,
            direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
          })
        if (result && this.isCurrentSession(currentSessionId, currentTeamId)) {
          this.isFinish = result.finished
          this.nextToken = result.nextToken
          this.memberList.push(...this.filterVisibleMembers(result.memberList))
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
      const currentSessionId = this.selectorSessionId
      const currentTeamId = this.teamId
      let accIds = members.map(m => m.accountId)
      this.appendJoinedMembers(currentSessionId, currentTeamId, accIds)
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

  onDestroy() {
    this.selectorSessionId += 1
    this.disposableBag.dispose()
  }

  /**
   * 搜索群成员（本地筛选）
   * 在已加载的群成员列表中进行字符串匹配搜索
   * 匹配字段：群昵称、好友备注、用户昵称、accountId
   * @param keyword 搜索关键字
   */
  searchTeamMembers(keyword: string) {
    this.searchKeyword = keyword
    if (!keyword || keyword.length === 0) {
      this.searchResultList = []
      this.isSearching = false
      return
    }

    // 本地筛选，不需要 teamId 检查和网络请求
    const lowerKeyword = keyword.toLowerCase()

    // 在已加载的 memberList 中进行本地筛选
    let filteredList = this.memberList.filter((member: TeamMemberWithUser) => {
      // 匹配群昵称 (teamNick)
      const teamNick = member.teamMember.teamNick?.toLowerCase() ?? ''
      if (teamNick.includes(lowerKeyword)) {
        return true
      }

      // 匹配好友备注 (alias)
      const alias = member.friendInfo?.alias?.toLowerCase() ?? ''
      if (alias.includes(lowerKeyword)) {
        return true
      }

      // 匹配用户昵称 (name)
      const userName = member.userInfo?.name?.toLowerCase() ?? ''
      if (userName.includes(lowerKeyword)) {
        return true
      }

      // 匹配账户ID (accountId)
      const accountId = member.teamMember.accountId.toLowerCase()
      if (accountId.includes(lowerKeyword)) {
        return true
      }

      return false
    })

    // 如果不显示管理员，过滤掉管理员和群主
    if (!this.showManager) {
      this.searchResultList = filteredList.filter((member) => {
        return member.teamMember.memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
      })
    } else {
      this.searchResultList = filteredList
    }

    this.isSearching = false
  }

  /**
   * 清除搜索结果
   */
  clearSearch() {
    this.searchKeyword = ''
    this.searchResultList = []
    this.isSearching = false
  }

  /**
   * 清除选中的成员
   */
  clearSelectedMembers() {
    this.selectedMembers.clear()
    this.selectedCount = 0
  }

  /**
   * 获取当前显示的列表（搜索结果或完整列表）
   */
  getDisplayList(): TeamMemberWithUser[] {
    if (this.searchKeyword.length > 0) {
      return this.searchResultList
    }
    return this.memberList
  }

  private isCurrentSession(sessionId: number, teamId: string): boolean {
    return this.selectorSessionId === sessionId && this.teamId === teamId
  }

  private async appendJoinedMembers(currentSessionId: number, currentTeamId: string, accIds: string[]): Promise<void> {
    try {
      const newMembers = await TeamRepo.getTeamMembersByIds(currentTeamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, accIds)
      await this.ensureAIUsersLoaded()
      if (!this.isCurrentSession(currentSessionId, currentTeamId)) {
        return
      }
      this.memberList.push(...this.filterVisibleMembers(newMembers))
    } catch (e) {
      Logger.error('TeamKit', e)
    }
  }

  private async ensureAIUsersLoaded(): Promise<void> {
    if (this.mode !== TeamMemberSelectorMode.ADD_MANAGER || !IMKitConfigCenter.enableAI || this.hasLoadedAIUsers) {
      return
    }
    if (!this.aiUsersLoadingPromise) {
      const loadingPromise = (async (): Promise<void> => {
        try {
          await NEAIUserCache.getInstance().load()
          this.hasLoadedAIUsers = true
        } catch (e) {
          this.hasLoadedAIUsers = false
          Logger.error('TeamKit', e)
        }
      })()
      this.aiUsersLoadingPromise = loadingPromise.finally(() => {
        this.aiUsersLoadingPromise = undefined
      })
    }
    await this.aiUsersLoadingPromise
  }

  private filterVisibleMembers(members: TeamMemberWithUser[]): TeamMemberWithUser[] {
    if (this.mode !== TeamMemberSelectorMode.ADD_MANAGER || !IMKitConfigCenter.enableAI) {
      return members
    }
    // 加管理员时不展示数字人。
    return members.filter((member: TeamMemberWithUser): boolean =>
      NEAIUserCache.getAIUser(member.getAccId()) === undefined)
  }
}
