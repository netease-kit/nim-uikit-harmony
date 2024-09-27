/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMAntispamConfig,
  V2NIMCreateTeamParams,
  V2NIMCreateTeamResult,
  V2NIMQueryDirection,
  V2NIMTeam,
  V2NIMTeamAgreeMode,
  V2NIMTeamChatBannedMode,
  V2NIMTeamInviteMode,
  V2NIMTeamJoinActionInfo,
  V2NIMTeamJoinActionInfoQueryOption,
  V2NIMTeamJoinActionInfoResult,
  V2NIMTeamJoinMode,
  V2NIMTeamMember,
  V2NIMTeamMemberListResult,
  V2NIMTeamMemberQueryOption,
  V2NIMTeamMemberRole,
  V2NIMTeamMemberSearchOption,
  V2NIMTeamMemberSearchResult,
  V2NIMTeamType,
  V2NIMTeamUpdateExtensionMode,
  V2NIMTeamUpdateInfoMode,
  V2NIMUpdateSelfMemberInfoParams,
  V2NIMUpdateTeamInfoParams,
  V2NIMUser
} from '@nimsdk/base'
import { ChatKitClient } from '../ChatKitClient'
import { TeamMemberResult, TeamMemberWithUser } from '../model/TeamMemberWithUser'
import { NEFriendUserCache } from '../NEFriendUserCache'
import { ContactRepo } from './ContactRepo'


interface TeamExtension {
  im_ui_kit_group: boolean
}

export class TeamRepo {
  //默认群头像
  public static teamDefaultIcons = [
    "https://s.netease.im/safe/ABg8YjWQWvcqO6sAAAAAAAAAAAA?_im_url=1",
    "https://s.netease.im/safe/ABg8YjmQWvcqO6sAAAAAAAABAAA?_im_url=1",
    "https://s.netease.im/safe/ABg8YjyQWvcqO6sAAAAAAAABAAA?_im_url=1",
    "https://s.netease.im/safe/ABg8YkCQWvcqO6sAAAAAAAABAAA?_im_url=1",
    "https://s.netease.im/safe/ABg8YkSQWvcqO6sAAAAAAAABAAA?_im_url=1"
  ]

  /**
   * 创建讨论组
   * @param inviteeAccountIds
   * @param postscript
   * @param antispamConfig
   * @returns
   */
  static async createGroupTeam(
    inviteeAccountIds?: string[],
    postscript?: string,
    antispamConfig?: V2NIMAntispamConfig): Promise<V2NIMCreateTeamResult | undefined> {
    let createParams: V2NIMCreateTeamParams = {
      name: TeamRepo.getTeamNameByMemberId(inviteeAccountIds),
      teamType: V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
      joinMode: V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_FREE,
      inviteMode: V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_ALL,
      agreeMode: V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_NO_AUTH,
      updateInfoMode: V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_ALL,
      updateExtensionMode: V2NIMTeamUpdateExtensionMode.V2NIM_TEAM_UPDATE_EXTENSION_MODE_ALL,
      serverExtension: JSON.stringify({ 'im_ui_kit_group': true }),
      avatar: TeamRepo.teamDefaultIcons[Math.floor(Math.random() * 5)]
    }
    return TeamRepo.createTeam(createParams,
      inviteeAccountIds, postscript, antispamConfig)
  }

  /**
   * 判断是否为讨论组
   * @param team
   * @returns
   */
  static isGroupTeam(team: V2NIMTeam) {
    if (team.serverExtension && team.serverExtension.length > 0) {
      let obj: TeamExtension = JSON.parse(team.serverExtension)
      if (obj.im_ui_kit_group === true) {
        return true
      }
    }
    return false
  }

  /**
   * 创建高级群
   * @param inviteeAccountIds
   * @param postscript
   * @param antispamConfig
   * @returns
   */
  static async createAdvanceTeam(
    inviteeAccountIds?: string[],
    postscript?: string,
    antispamConfig?: V2NIMAntispamConfig): Promise<V2NIMCreateTeamResult | undefined> {
    let createParams: V2NIMCreateTeamParams = {
      name: TeamRepo.getTeamNameByMemberId(inviteeAccountIds),
      teamType: V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
      joinMode: V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_FREE,
      inviteMode: V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_MANAGER,
      agreeMode: V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_NO_AUTH,
      updateInfoMode: V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_MANAGER,
      updateExtensionMode: V2NIMTeamUpdateExtensionMode.V2NIM_TEAM_UPDATE_EXTENSION_MODE_MANAGER,
      avatar: TeamRepo.teamDefaultIcons[Math.floor(Math.random() * 5)]
    }
    return TeamRepo.createTeam(createParams,
      inviteeAccountIds, postscript, antispamConfig)
  }

  /**
   * 创建一个群组
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 操作者端（群主）, SDK 抛出: {@link V2NIMTeamListener.onTeamCreated | V2NIMTeamListener.onTeamCreated}
   * - agreeMode 需要被邀请者同意
   *   - 被操作者端, SDK会抛出: {@link V2NIMTeamListener.onReceiveTeamJoinActionInfo | V2NIMTeamListener.onReceiveTeamJoinActionInfo}
   * - agreeMode 不需被邀请者同意
   *   - 被操作者端， SDK会抛出: {@link V2NIMTeamListener.onTeamJoined | V2NIMTeamListener.onTeamJoined}
   *   - 其他成员端， SDK会抛出: {@link V2NIMTeamListener.onTeamMemberJoined | V2NIMTeamListener.onTeamMemberJoined}
   *
   * @param createTeamParams 创建群组参数
   * @param invitorAccountIds 群组创建时，同时邀请加入群的成员列表
   * @param postscript 群组创建时，邀请入群的附言
   * @param antispamConfig 反垃圾参数. 如果开启了安全通，默认采用安全通，该配置不需要配置.
   *                       如果有审核需求，且直接对接易盾，则需要传入该配置
   */
  static async createTeam(createTeamParams: V2NIMCreateTeamParams,
    inviteeAccountIds?: string[],
    postscript?: string,
    antispamConfig?: V2NIMAntispamConfig): Promise<V2NIMCreateTeamResult | undefined> {
    return await ChatKitClient.nim.teamService?.createTeam(createTeamParams, inviteeAccountIds, postscript,
      antispamConfig)
  }

  /**
   * 修改群组信息
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 全员用户端，SDK会抛出: {@link V2NIMTeamListener.onTeamInfoUpdated | V2NIMTeamListener.onTeamInfoUpdated}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param updateTeamInfoParams 更新群组信息参数
   * @param antispamConfig 反垃圾参数. 如果开启了安全通，默认采用安全通，该配置不需要配置.
   *                       如果有审核需求，且直接对接易盾，则需要传入该配置
   */
  static async updateTeamInfo(teamId: string,
    teamType: V2NIMTeamType,
    updateTeamInfoParams: V2NIMUpdateTeamInfoParams,
    antispamConfig?: V2NIMAntispamConfig): Promise<void> {
    await ChatKitClient.nim.teamService?.updateTeamInfo(teamId, teamType, updateTeamInfoParams, antispamConfig)
  }

  /**
   * 退出群组
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 操作者（自己本端），SDK会抛出: {@link V2NIMTeamListener.onTeamLeft | V2NIMTeamListener.onTeamLeft}
   * - 群内其它用户端， SDK会抛出: {@link V2NIMTeamListener.onTeamMemberLeft | V2NIMTeamListener.onTeamMemberLeft}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   */
  static async leaveTeam(teamId: string, teamType: V2NIMTeamType): Promise<void> {
    await ChatKitClient.nim.teamService?.leaveTeam(teamId, teamType)
  }

  /**
   * 获取群组信息
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   */
  static async getTeamInfo(teamId: string, teamType: V2NIMTeamType): Promise<V2NIMTeam | undefined> {
    return await ChatKitClient.nim.teamService?.getTeamInfo(teamId, teamType)
  }

  /**
   * 获取当前已经加入的群组列表
   *
   * 注: 群组有效且自己在群中
   *
   * @param teamTypes 群类型列表. 若不传入这个字段, 代表这个过滤条件不生效, 则查询所有群组
   */
  static async getJoinedTeamList(teamTypes?: V2NIMTeamType[]): Promise<V2NIMTeam[]> {
    return await ChatKitClient.nim.teamService?.getJoinedTeamList(teamTypes) ?? []
  }

  /**
   * 获取当前已经加入的群组数量
   *
   * 注: 群组有效且自己在群中
   *
   * @param teamTypes 群类型列表. 若不传入这个字段, 代表这个过滤条件不生效, 则查询所有群组
   */
  static async getJoinedTeamCount(teamTypes?: V2NIMTeamType[]): Promise<number | undefined> {
    return await ChatKitClient.nim.teamService?.getJoinedTeamCount(teamTypes)
  }

  /**
   * 根据群组ID获取群组信息
   *
   * 每次最多100个群组ID. 先查本地数据，本地缺失再查询云端
   *
   * @param teamIds 群组ID列表
   * @param teamType 群组类型
   */
  static async getTeamInfoByIds(teamIds: string[],
    teamType: V2NIMTeamType): Promise<V2NIMTeam[]> {
    return await ChatKitClient.nim.teamService?.getTeamInfoByIds(teamIds, teamType) ?? []
  }

  /**
   * 解散群组
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 全员, SDK会抛出: {@link V2NIMTeamListener.onTeamDismissed | V2NIMTeamListener.onTeamDismissed}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   */
  static async dismissTeam(teamId: string, teamType: V2NIMTeamType): Promise<void> {
    await ChatKitClient.nim.teamService?.dismissTeam(teamId, teamType)
  }

  /**
   * 邀请成员加入群
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - agreeMode 需要被邀请者同意
   *   - 被操作者端， SDK会抛出: {@link V2NIMTeamListener.onReceiveTeamJoinActionInfo | V2NIMTeamListener.onReceiveTeamJoinActionInfo}
   * - agreeMode 不需要被邀请者同意
   *   - 被操作者端， SDK会抛出: {@link V2NIMTeamListener.onTeamJoined | V2NIMTeamListener.onTeamJoined}
   *   - 其他成员端， SDK会抛出: {@link V2NIMTeamListener.onTeamMemberJoined | V2NIMTeamListener.onTeamMemberJoined}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param inviteeAccountIds 邀请加入群的成员账号列表
   * @param postscript 邀请入群的附言
   * @returns 邀请失败的账号列表
   */
  static async inviteMember(teamId: string,
    teamType: V2NIMTeamType,
    inviteeAccountIds: string[],
    postscript?: string): Promise<string[]> {
    return await ChatKitClient.nim.teamService?.inviteMember(teamId, teamType, inviteeAccountIds, postscript) ?? []
  }

  /**
   * 接受邀请入群
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 操作者（既接受邀请用户）端， SDK会抛出: {@link V2NIMTeamListener.onTeamJoined | V2NIMTeamListener.onTeamJoined}
   * - 其他成员端， SDK会抛出: {@link V2NIMTeamListener.onTeamMemberJoined | V2NIMTeamListener.onTeamMemberJoined}
   *
   * @param invitationInfo 邀请入群的信息
   */
  static async acceptInvitation(invitationInfo: V2NIMTeamJoinActionInfo): Promise<V2NIMTeam | undefined> {
    return await ChatKitClient.nim.teamService?.acceptInvitation(invitationInfo)
  }

  /**
   * 拒绝邀请入群
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 群主或管理员端， SDK会抛出: {@link V2NIMTeamListener.onReceiveTeamJoinActionInfo | V2NIMTeamListener.onReceiveTeamJoinActionInfo}‘
   *
   * @param invitationInfo 邀请入群的信息
   */
  static async rejectInvitation(invitationInfo: V2NIMTeamJoinActionInfo, postscript?: string): Promise<void> {
    await ChatKitClient.nim.teamService?.rejectInvitation(invitationInfo)
  }

  /**
   * 踢出群组成员
   *
   * 注1: 只有群主有权限操作改接口
   *
   * 注2: 操作成功后, 触发事件的规则如下:
   * - 被操作者（既被踢用户），SDK会抛出: {@link V2NIMTeamListener.onTeamLeft | V2NIMTeamListener.onTeamLeft}
   * - 其他成员端，SDK会抛出: {@link V2NIMTeamListener.onTeamMemberKicked | V2NIMTeamListener.onTeamMemberKicked}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param memberAccountIds 踢出群组的成员账号列表
   */
  static async kickMember(teamId: string, teamType: V2NIMTeamType, memberAccountIds: string[]): Promise<void> {
    await ChatKitClient.nim.teamService?.kickMember(teamId, teamType, memberAccountIds)
  }

  /**
   * (用户)申请加入群组
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - joinMode 自由加入
   *   - 操作者端，SDK 会抛出: {@link V2NIMTeamListener.onTeamJoined | V2NIMTeamListener.onTeamJoined}
   *   - 其他成员端， SDK 会抛出: {@link V2NIMTeamListener.onTeamMemberJoined | V2NIMTeamListener.onTeamMemberJoined}
   * - joinMode 群主管理员同意
   *   - 群主或管理员端，SDK 会抛出 {@link V2NIMTeamListener.onReceiveTeamJoinActionInfo | V2NIMTeamListener.onReceiveTeamJoinActionInfo}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param postscript 申请附言
   * @returns 对应的群信息
   */
  static async applyJoinTeam(teamId: string,
    teamType: V2NIMTeamType,
    postscript?: string): Promise<V2NIMTeam | undefined> {
    return await ChatKitClient.nim.teamService?.applyJoinTeam(teamId, teamType, postscript)
  }

  /**
   * (管理员)接受(用户的)入群申请
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 被操作者（既被同意用户），SDK会抛出: {@link V2NIMTeamListener.onTeamJoined | V2NIMTeamListener.onTeamJoined}
   * - 其他成员， SDK会抛出: {@link V2NIMTeamListener.onTeamMemberJoined | V2NIMTeamListener.onTeamMemberJoined}
   *
   * @param applicationInfo 该申请的相关信息
   */
  static async acceptJoinApplication(applicationInfo: V2NIMTeamJoinActionInfo): Promise<void> {
    await ChatKitClient.nim.teamService?.acceptJoinApplication(applicationInfo)
  }

  /**
   * (管理员)拒绝(用户的)入群申请
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 被操作用户（既被拒绝用户）， SDK会抛出: {@link V2NIMTeamListener.onReceiveTeamJoinActionInfo | V2NIMTeamListener.onReceiveTeamJoinActionInfo}
   *
   * @param applicationInfo 该申请的相关信息
   */
  static async rejectJoinApplication(applicationInfo: V2NIMTeamJoinActionInfo, postscript?: string): Promise<void> {
    await ChatKitClient.nim.teamService?.rejectJoinApplication(applicationInfo, postscript)
  }

  /**
   * 设置成员角色
   *
   * 注1: 本操作只有群主可操作, 且只能在普通成员与管理员直接角色切换, 如果成员设置角色与当前角色一致，默认请求成功
   *
   * 注2: 操作成功后, 触发事件的规则如下:
   * - 所有成员，SDK会抛出: @link V2NIMTeamListener.onTeamMemberInfoUpdated | V2NIMTeamListener.onTeamMemberInfoUpdated}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param memberAccountIds 待操作的群组的成员账号列表
   * @param memberRole 新的角色类型
   */
  static async updateTeamMemberRole(teamId: string,
    teamType: V2NIMTeamType,
    memberAccountIds: string[],
    memberRole: V2NIMTeamMemberRole): Promise<void> {
    await ChatKitClient.nim.teamService?.updateTeamMemberRole(teamId, teamType, memberAccountIds, memberRole)
  }

  /**
   * 移交群主
   *
   * 注1: 本操作只有群主可操作
   *
   * 注2: 操作成功后, 触发事件的规则如下:
   * - 所有成员，SDK会抛出: {@link V2NIMTeamListener.onTeamInfoUpdated | V2NIMTeamListener.onTeamInfoUpdated}‘
   * - 若入参 leave 为 true:
   *   - 操作者， SDK会抛出:onTeamLeft
   *   - 其它成员， SDK会抛出:onTeamMemberLeft
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param accountId 新群主的账号 ID
   * @param leave 转让群主后, 操作者是否同时退出该群. 默认为 false
   * @returns 该操作的时间戳
   */
  static async transferTeamOwner(teamId: string,
    teamType: V2NIMTeamType,
    accountId: string,
    leave?: boolean): Promise<void> {
    await ChatKitClient.nim.teamService?.transferTeamOwner(teamId, teamType, accountId, leave)
  }

  /**
   * 修改自己的群成员信息
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 所有成员， SDK会抛出: {@link V2NIMTeamListener.onTeamMemberInfoUpdated | V2NIMTeamListener.onTeamMemberInfoUpdated}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param memberInfoParams 被修改的字段
   */
  static async updateSelfTeamMemberInfo(teamId: string,
    teamType: V2NIMTeamType,
    memberInfoParams: V2NIMUpdateSelfMemberInfoParams): Promise<void> {
    await ChatKitClient.nim.teamService?.updateSelfTeamMemberInfo(teamId, teamType, memberInfoParams)
  }

  /**
   * 修改群成员昵称
   *
   * 注: 只有群主和管理员拥有此权限可操作
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 所有成员，SDK会抛出: {@link V2NIMTeamListener.onTeamMemberInfoUpdated | V2NIMTeamListener.onTeamMemberInfoUpdated}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param accountId 新群主的账号 ID
   * @param nick 昵称
   */
  static async updateTeamMemberNick(teamId: string,
    teamType: V2NIMTeamType,
    accountId: string,
    nick: string): Promise<void> {
    await ChatKitClient.nim.teamService?.updateTeamMemberNick(teamId, teamType, accountId, nick)
  }

  /**
   * 设置群组禁言模式
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 所有成员，SDK会抛出: {@link V2NIMTeamListener.onTeamInfoUpdated | V2NIMTeamListener.onTeamInfoUpdated}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param chatBannedMode 禁言模式
   */
  static async setTeamChatBannedMode(teamId: string,
    teamType: V2NIMTeamType,
    chatBannedMode: V2NIMTeamChatBannedMode): Promise<void> {
    await ChatKitClient.nim.teamService?.setTeamChatBannedMode(teamId, teamType, chatBannedMode)
  }

  /**
   * 设置群组成员聊天禁言状态
   *
   * 注: 操作成功后, 触发事件的规则如下:
   * - 所有成员， SDK会抛出: {@link V2NIMTeamListener.onTeamMemberInfoUpdated | V2NIMTeamListener.onTeamMemberInfoUpdated}
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param accountId 被修改成员的账号
   * @param chatBanned 群组中聊天是否被禁言
   */
  static async setTeamMemberChatBannedStatus(teamId: string, teamType: V2NIMTeamType, accountId: string,
    chatBanned: boolean): Promise<void> {
    await ChatKitClient.nim.teamService?.setTeamMemberChatBannedStatus(teamId, teamType, accountId, chatBanned)
  }

  /**
   * 获取群成员列表
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param memberRoles 成员角色
   * @returns 查询结果
   */
  static async getTeamMemberList(teamId: string,
    teamType: V2NIMTeamType,
    queryOption: V2NIMTeamMemberQueryOption): Promise<V2NIMTeamMemberListResult | undefined> {
    return await ChatKitClient.nim.teamService?.getTeamMemberList(teamId, teamType, queryOption)
  }

  /**
   * 根据账号 ID 列表获取群组成员列表
   *
   * @param teamId 群组id
   * @param teamType 群组类型
   * @param accountIds 成员的账号 ID 列表
   * @returns 成员列表
   */
  static async getTeamMemberListByIds(teamId: string,
    teamType: V2NIMTeamType,
    accountIds: string[]): Promise<V2NIMTeamMember[]> {
    return await ChatKitClient.nim.teamService?.getTeamMemberListByIds(teamId, teamType, accountIds) ?? []
  }

  /**
   * 获取群加入相关信息
   *
   * @param option 查询参数
   */
  static async getTeamJoinActionInfoList(option: V2NIMTeamJoinActionInfoQueryOption): Promise<V2NIMTeamJoinActionInfoResult | undefined> {
    return await ChatKitClient.nim.teamService?.getTeamJoinActionInfoList(option)
  }

  /**
   * 根据关键字搜索群信息
   *  - 混合搜索高级群和超大群，like匹配
   *  - 只搜索群名称
   */
  static async searchTeamByKeyword(keyword: string): Promise<V2NIMTeam[]> {
    // TODO: 等待SDK实现
    // return await ChatKitClient.nim.teamService?.searchTeamByKeyword(keyword) ?? []
    return []
  }

  /**
   *  根据关键字搜索群成员
   *
   * @param searchOption 搜索参数
   * @param success 成功回调
   * @param failure 失败回调
   */
  static async searchTeamMembers(searchOption: V2NIMTeamMemberSearchOption): Promise<V2NIMTeamMemberSearchResult | undefined> {
    // TODO: 等待SDK实现
    // return await ChatKitClient.nim.teamService?.searchTeamMembers(searchOption)
    return undefined
  }

  /**
   * 分页获取群成员列表，包含用户和好友信息
   * @param teamId
   * @param teamType
   * @param limit
   * @param nextToken
   * @returns
   */
  static async getTeamMembers(teamId: string,
    teamType: V2NIMTeamType, limit?: number, nextToken?: string): Promise<TeamMemberResult | undefined> {
    let teamMemberResult = await TeamRepo.getTeamMemberList(
      teamId,
      teamType,
      {
        limit: limit,
        nextToken: nextToken,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
      }
    )

    let teamMembers: TeamMemberWithUser[] | undefined = teamMemberResult?.memberList.map((teamMember) => {
      return new TeamMemberWithUser(teamMember,
        NEFriendUserCache.getInstance().getFriendById(teamMember.accountId)?.friend,
        NEFriendUserCache.getInstance().getFriendById(teamMember.accountId)?.user)
    })

    let noUserAccIdList = teamMembers?.filter((member) => {
      return !member.userInfo
    }).map((teamMember) => {
      return teamMember.teamMember.accountId
    })

    if (noUserAccIdList && noUserAccIdList.length > 0) {
      let userList = await ContactRepo.getUserList(noUserAccIdList)

      let userMap = userList.reduce((acc, cur, _index) => {
        acc.set(cur.accountId, cur)
        return acc
      }, new Map<string, V2NIMUser>())

      teamMembers?.forEach((member) => {
        if (!member.userInfo) {
          member.userInfo = userMap.get(member.teamMember.accountId)
        }
      })
    }
    if (teamMemberResult) {
      let result: TeamMemberResult = {
        finished: teamMemberResult?.finished,
        nextToken: teamMemberResult?.nextToken,
        memberList: teamMembers ?? []
      }
      return result
    }

    return

  }

  /**
   * 根据群成员生成群名
   * @param inviteeAccountIds
   * @returns
   */
  private static getTeamNameByMemberId(inviteeAccountIds?: string[]): string {
    if (inviteeAccountIds) {
      let inviteeUser = NEFriendUserCache.getInstance().getFriendsByIds(inviteeAccountIds)
      let inviteeNames = inviteeUser.map(user => user.user?.name ?? user.user?.accountId)
      let teamName = inviteeNames.slice(0, Math.min(inviteeNames.length, 30)).join('、')
      let mineName = NEFriendUserCache.mineUserCache?.showName(false)
      teamName = mineName + '、' + teamName
      return teamName.slice(0, Math.min(teamName.length, 30))
    }
    return ''

  }
}