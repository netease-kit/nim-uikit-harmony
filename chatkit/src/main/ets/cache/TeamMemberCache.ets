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
      this.clearMemberChangeListener()
      this.membersMap.clear()
      this.mineTeamMember = undefined
      this.teamId = teamId
      this.team = team
      this.isFinish = false
      this.initMemberChangeListener()
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
  needFetchMember(): boolean {
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
    }
  }

  /**
   * 成员加入
   * @param members
   */
  onTeamMemberJoined = (members: V2NIMTeamMember[]): void => {
    if (members[0].teamId === this.teamId) {
      let accIds = members.map(m => m.accountId)
      TeamRepo.getTeamMembersByIds(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        accIds).then((newMembers) => {
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
  getAllMembers(): TeamMemberWithUser[] {
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
      TeamRepo.getTeamInfo(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
        .then((team) => {
          this.team = team
        })
      TeamRepo.getTeamMembersByIds(
        this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, [ChatKitClient.getLoginUserId()]
      )
        .then((members: TeamMemberWithUser[]) => {
          if (members.length > 0) {
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
  async getTeam(): Promise<V2NIMTeam | undefined> {
    if (!this.team) {
      this.team = await TeamRepo.getTeamInfo(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
    }
    return this.team
  }

  /**
   * 拉取全量成员
   */
  async loadAllTeamMember() {
    if (this.team) {
      while (!this.isFinish) {
        await this.getMemberList()
      }
    }
  }

  async getMoreMemberList() {
    if (!this.isFinish) {
      await this.getMemberList()
    }
  }

  async getMemberList() {
    let result = await TeamRepo.getTeamMembers(this.teamId,
      V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, {
        nextToken: this.nextToken,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
      }).catch((e: V2NIMError) => {
      Logger.debug('ChatKit', `${TeamMemberCache.logTag} getTeamMembers error code = ${e.code}`)
    })
    if (result) {
      this.isFinish = result.finished
      this.nextToken = result.nextToken
      result.memberList.forEach((e) => {
        this.membersMap.set(e.getAccId(), e)
      })
      let mineMember = result.memberList.find(member => member.getAccId() === ChatKitClient.getLoginUserId())
      if (mineMember) {
        this.mineTeamMember = mineMember.teamMember
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
  async getMineMember(): Promise<V2NIMTeamMember | undefined> {
    if (!this.mineTeamMember) {
      let mineMember = (await TeamRepo.getTeamMembersByIds(
        this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, [ChatKitClient.getLoginUserId()]
      )
      ).find(m => m.getAccId() === ChatKitClient.getLoginUserId())
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
      let result = (await TeamRepo.getTeamMembersByIds(
        this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, [account]
      ))
      if (result.length > 0) {
        const m = result[0]
        this.membersMap.set(m.getAccId(), m)
        return m
      }
    }
    return undefined
  }

  clear() {
    this.clearMemberChangeListener()
    this.membersMap.clear()
    this.mineTeamMember = undefined
    this.teamId = ''
    this.team = undefined
    this.isFinish = false
    this.nextToken = ''
  }

  /**
   * 是否已经加载了所有成员
   * @returns
   */
  haveLoadAllMember(): boolean {
    return this.isFinish
  }
}
