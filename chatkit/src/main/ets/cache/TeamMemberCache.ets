/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { Logger } from '@nimkit/common';
import {
  V2NIMError,
  V2NIMFriend,
  V2NIMQueryDirection,
  V2NIMTeam,
  V2NIMTeamMember,
  V2NIMTeamMemberRole,
  V2NIMTeamType,
  V2NIMUser
} from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';
import { TeamMemberWithUser } from '../model/TeamMemberWithUser';
import { NEFriendUserCache } from '../NEFriendUserCache';
import { FriendEventRepo } from '../repo/FriendEventRepo';
import { TeamRepo } from '../repo/TeamRepo';
import { TeamEventRepo } from '../repo/TeamEventRepo';
import { UserEventRepo } from '../repo/UserEventRepo';
import { DisposableBag } from '../utils/DisposableBag';

@ObservedV2
export class TeamMemberCache {
  static logTag = 'TeamMemberCache'
  //全成员列表
  @Trace membersMap: Map<string, TeamMemberWithUser> = new Map()
  //自己的群身份
  @Trace mineTeamMember: V2NIMTeamMember | undefined = undefined
  //群组Id
  teamId: string = ''
  //群组
  team?: V2NIMTeam = undefined
  //下次拉去的token
  nextToken = ''
  //是否拉完了
  isFinish = false
  // 当前群加载代次，切群或清理时使旧请求失效
  private generation: number = 0
  private pageLoadingPromise?: Promise<boolean> = undefined
  private loadAllPromise?: Promise<boolean> = undefined
  private static instance: TeamMemberCache
  private disposableBag: DisposableBag = new DisposableBag()

  private constructor() {

  }

  public static getInstance(): TeamMemberCache {
    if (!TeamMemberCache.instance) {
      TeamMemberCache.instance = new TeamMemberCache()
    }
    return TeamMemberCache.instance
  }

  /**
   * 初始化信息
   * @param teamId
   * @param team
   */
  intTeamInfo(teamId: string, team?: V2NIMTeam) {
    if (this.teamId !== teamId) {
      this.generation += 1
      this.clearMemberChangeListener()
      this.membersMap.clear()
      this.mineTeamMember = undefined
      this.teamId = teamId
      this.team = team
      this.nextToken = ''
      this.isFinish = false
      this.pageLoadingPromise = undefined
      this.loadAllPromise = undefined
      this.initMemberChangeListener()
    } else if (team) {
      this.team = team
      if (this.isFinish && this.membersMap.size < team.memberCount) {
        this.isFinish = false
        this.nextToken = ''
      }
    }
  }

  /**
   * 是否为空
   * @returns
   */
  isEmpty(): boolean {
    return this.membersMap.size <= 0
  }

  /**
   * 是否需要拉取
   * @returns
   */
  needFetchMember(expectedTeamId?: string): boolean {
    if (expectedTeamId !== undefined && expectedTeamId !== this.teamId) {
      return false
    }
    if (this.membersMap.size <= 0) {
      return true
    }
    if (this.membersMap.size < 100 && this.isFinish === false) {
      return true
    }
    return false
  }

  /**
   * 好友信息变更
   * @param friend
   */
  onFriendInfoChanged = (friend: V2NIMFriend): void => {
    let member = this.membersMap.get(friend.accountId)
    if (member) {
      member.friendInfo = friend
      this.membersMap.set(friend.accountId, member)
    }
  }


  /**
   * 群乘以信息变更
   * @param members
   */
  onTeamMemberInfoUpdated = (members: V2NIMTeamMember[]): void => {
    if (members[0].teamId === this.teamId) {
      members.forEach((m) => {
        let member = this.membersMap.get(m.accountId)
        if (member) {
          member.teamMember = m
          this.membersMap.set(m.accountId, member)
          if (m.accountId === ChatKitClient.getLoginUserId()) {
            this.mineTeamMember = m
          }
        }
      })
    }
  }

  /**
   * 离开群
   * @param members
   */
  onTeamMemberLeft = (members: V2NIMTeamMember[]): void => {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      removeIds.forEach((e) => {
        this.membersMap.delete(e)
      })
      this.isFinish = false
      this.nextToken = ''
    }
  }

  /**
   * 踢人
   * @param accId
   * @param members
   */
  onTeamMemberKicked = (accId: string, members: V2NIMTeamMember[]): void => {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      removeIds.forEach((e) => {
        this.membersMap.delete(e)
      })
      this.isFinish = false
      this.nextToken = ''
    }
  }

  /**
   * 成员加入
   * @param members
   */
  onTeamMemberJoined = (members: V2NIMTeamMember[]): void => {
    if (members[0].teamId === this.teamId) {
      const currentGeneration = this.generation
      const currentTeamId = this.teamId
      let accIds = members.map(m => m.accountId)
      TeamRepo.getTeamMembersByIds(currentTeamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        accIds).then((newMembers) => {
        if (!this.isCurrentTeam(currentTeamId, currentGeneration)) {
          return
        }
        newMembers.forEach((m) => {
          this.membersMap.set(m.getAccId(), m)
        })
      })
    }
  }

  /**
   * 获取所有成员的accId
   * @returns
   */
  getAllMemberAccounts(): string[] {
    return Array.from(this.membersMap.keys())
  }

  /**
   * 获取所有的成员列表
   * @returns
   */
  getAllMembers(expectedTeamId?: string): TeamMemberWithUser[] {
    if (expectedTeamId !== undefined && expectedTeamId !== this.teamId) {
      return []
    }
    return Array.from(this.membersMap.values()).sort((a, b) => this.sortTeamMember(a, b))
  }

  // 群更新
  onTeamInfoUpdated = (team: V2NIMTeam): void => {
    if (team.teamId === this.teamId) {
      this.team = team
    }
  }
  /**
   * 刷新群信息
   */
  onSyncFinished = (): void => {
    if (this.teamId) {
      const currentGeneration = this.generation
      const currentTeamId = this.teamId
      TeamRepo.getTeamInfo(currentTeamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
        .then((team) => {
          if (this.isCurrentTeam(currentTeamId, currentGeneration)) {
            this.team = team
          }
        })
      TeamRepo.getTeamMembersByIds(
        currentTeamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, [ChatKitClient.getLoginUserId()]
      )
        .then((members: TeamMemberWithUser[]) => {
          if (members.length > 0 && this.isCurrentTeam(currentTeamId, currentGeneration)) {
            this.mineTeamMember = members[0].teamMember
          }
        })
    }

  }

  /**
   * 用户信息变更
   * @param users
   */
  onUserProfileChanged = (users: V2NIMUser[]): void => {
    users.forEach((user) => {
      let member = this.membersMap.get(user.accountId)
      if (member) {
        member.userInfo = user
        this.membersMap.set(user.accountId, member)
      }
    })
  }


  /**
   * 初始化成员信息变化回调
   */
  initMemberChangeListener() {
    this.clearMemberChangeListener()
    this.disposableBag.addAll([
      UserEventRepo.onUserProfileChanged(this.onUserProfileChanged),
      FriendEventRepo.onFriendInfoChanged(this.onFriendInfoChanged),
      TeamEventRepo.onTeamMemberInfoUpdated(this.onTeamMemberInfoUpdated),
      TeamEventRepo.onTeamMemberLeft(this.onTeamMemberLeft),
      TeamEventRepo.onTeamMemberKicked(this.onTeamMemberKicked),
      TeamEventRepo.onTeamMemberJoined(this.onTeamMemberJoined),
      TeamEventRepo.onTeamInfoUpdated(this.onTeamInfoUpdated),
      TeamEventRepo.onTeamSyncFinished(this.onSyncFinished)
    ])
  }

  clearMemberChangeListener() {
    this.disposableBag.dispose()
  }

  /**
   * 初始化群信息
   */
  async getTeam(expectedTeamId?: string): Promise<V2NIMTeam | undefined> {
    if (expectedTeamId !== undefined && expectedTeamId !== this.teamId) {
      return undefined
    }
    if (!this.team) {
      const currentGeneration = this.generation
      const currentTeamId = this.teamId
      const team = await TeamRepo.getTeamInfo(currentTeamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
      if (this.isCurrentTeam(currentTeamId, currentGeneration)) {
        this.team = team
        return team
      }
      return undefined
    }
    return this.team
  }

  /**
   * 拉取全量成员
   */
  async loadAllTeamMember(): Promise<boolean> {
    if (!this.teamId) {
      return false
    }
    if (this.isFinish) {
      return this.haveLoadAllMember(this.teamId)
    }
    if (this.loadAllPromise) {
      return await this.loadAllPromise
    }

    const currentGeneration = this.generation
    const currentTeamId = this.teamId
    const loadingPromise = (async (): Promise<boolean> => {
      while (this.isCurrentTeam(currentTeamId, currentGeneration) && !this.isFinish) {
        const pageLoaded = await this.getMemberList()
        if (!pageLoaded) {
          return false
        }
      }
      return this.isCurrentTeam(currentTeamId, currentGeneration) &&
        this.haveLoadAllMember(currentTeamId)
    })()
    this.loadAllPromise = loadingPromise
    try {
      return await loadingPromise
    } finally {
      if (this.loadAllPromise === loadingPromise) {
        this.loadAllPromise = undefined
      }
    }
  }

  async getMoreMemberList(): Promise<boolean> {
    if (!this.isFinish) {
      return await this.getMemberList()
    }
    return this.haveLoadAllMember(this.teamId)
  }

  async getMemberList(): Promise<boolean> {
    if (!this.teamId || this.isFinish) {
      return this.haveLoadAllMember(this.teamId)
    }
    if (this.pageLoadingPromise) {
      return await this.pageLoadingPromise
    }

    const currentGeneration = this.generation
    const currentTeamId = this.teamId
    const currentNextToken = this.nextToken
    const loadingPromise = (async (): Promise<boolean> => {
      let result = await TeamRepo.getTeamMembers(currentTeamId,
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, {
          nextToken: currentNextToken,
          direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
        }).catch((e: V2NIMError) => {
        Logger.debug('ChatKit', `${TeamMemberCache.logTag} getTeamMembers error code = ${e.code}`)
      })
      if (!result || !this.isCurrentTeam(currentTeamId, currentGeneration)) {
        return false
      }
      if (!result.finished && result.nextToken === currentNextToken) {
        Logger.debug('ChatKit', `${TeamMemberCache.logTag} next token did not advance`)
        return false
      }

      this.isFinish = result.finished
      this.nextToken = result.nextToken
      result.memberList.forEach((member: TeamMemberWithUser) => {
        this.membersMap.set(member.getAccId(), member)
      })
      let mineMember = result.memberList.find(member => member.getAccId() === ChatKitClient.getLoginUserId())
      if (mineMember) {
        this.mineTeamMember = mineMember.teamMember
      }
      return true
    })()
    this.pageLoadingPromise = loadingPromise
    try {
      return await loadingPromise
    } finally {
      if (this.pageLoadingPromise === loadingPromise) {
        this.pageLoadingPromise = undefined
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

  /**
   * 获取自己的成员信息
   * @returns
   */
  async getMineMember(expectedTeamId?: string): Promise<V2NIMTeamMember | undefined> {
    if (expectedTeamId !== undefined && expectedTeamId !== this.teamId) {
      return undefined
    }
    if (!this.mineTeamMember) {
      const currentGeneration = this.generation
      const currentTeamId = this.teamId
      if (!currentTeamId) {
        return undefined
      }
      let mineMember = (await TeamRepo.getTeamMembersByIds(
        currentTeamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, [ChatKitClient.getLoginUserId()]
      )
      ).find(m => m.getAccId() === ChatKitClient.getLoginUserId())
      if (!this.isCurrentTeam(currentTeamId, currentGeneration)) {
        return undefined
      }
      if (mineMember) {
        this.membersMap.set(mineMember.getAccId(), mineMember)
        this.mineTeamMember = mineMember.teamMember
      }
    }
    return this.mineTeamMember
  }

  /**
   * 根据accId 获取具体的成员
   * @param account
   * @returns
   */
  async getMemberById(account: string): Promise<TeamMemberWithUser | undefined> {
    let member = this.membersMap.get(account)
    if (member) {
      return member
    } else {
      const currentGeneration = this.generation
      const currentTeamId = this.teamId
      let result = (await TeamRepo.getTeamMembersByIds(
        currentTeamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, [account]
      ))
      if (result.length > 0 && this.isCurrentTeam(currentTeamId, currentGeneration)) {
        const m = result[0]
        this.membersMap.set(m.getAccId(), m)
        return m
      }
    }
    return undefined
  }

  clear() {
    this.generation += 1
    this.clearMemberChangeListener()
    this.membersMap.clear()
    this.mineTeamMember = undefined
    this.teamId = ''
    this.team = undefined
    this.isFinish = false
    this.nextToken = ''
    this.pageLoadingPromise = undefined
    this.loadAllPromise = undefined
  }

  /**
   * 是否已经加载了所有成员
   * @returns
   */
  haveLoadAllMember(expectedTeamId?: string): boolean {
    if ((expectedTeamId !== undefined && expectedTeamId !== this.teamId) || !this.isFinish) {
      return false
    }
    return !this.team || this.membersMap.size >= this.team.memberCount
  }

  private isCurrentTeam(teamId: string, generation: number): boolean {
    return this.teamId === teamId && this.generation === generation
  }
}
