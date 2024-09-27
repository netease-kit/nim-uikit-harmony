/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ConversationRepo, SettingRepo, TeamRepo } from '@nimkit/chatkit';
import {
  V2NIMError,
  V2NIMTeam,
  V2NIMTeamChatBannedMode,
  V2NIMTeamMember,
  V2NIMTeamMessageMuteMode,
  V2NIMTeamType,
  V2NIMUpdateSelfMemberInfoParams
} from '@nimsdk/base';
import { TeamMemberWithUser } from '@nimkit/chatkit/src/main/ets/model/TeamMemberWithUser';

@ObservedV2
export class TeamViewModel {
  @Trace team?: V2NIMTeam
  @Trace teamMemberList: TeamMemberWithUser[] = []
  teamId: string
  teamType: V2NIMTeamType = V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL
  @Trace mineTeamMember?: V2NIMTeamMember
  //是否消息通知
  @Trace isMessageNotify: boolean = true
  //是否置顶
  @Trace isStickTop: boolean = false
  limit: number = 100
  nextToken?: string
  isFinished: boolean = false

  constructor(teamId: string) {
    this.teamId = teamId
  }

  initTeamInfo() {
    this.getTeamInfo();
    this.getConversationInfo();
    this.getTeamMember();
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', (team) => {
      if (team.teamId === this.teamId) {
        this.team = team
      }
    })
    ChatKitClient.nim.teamService?.on('onTeamMemberJoined', async (members) => {
      let userList = await ContactRepo.getUserWithFriendByIds(members.map(member => member.accountId))
      let memberList: TeamMemberWithUser[] = members.map(e => {
        let user = userList.find((user) => user.user?.accountId === e.accountId)
        return new TeamMemberWithUser(e, user?.friend, user?.user)
      })

      this.teamMemberList.push(...memberList)
    })

    ChatKitClient.nim.teamService?.on('onTeamMemberInfoUpdated', (members) => {
      let mineMember = members.find(member => member.accountId === ChatKitClient.getLoginUserId())
      if (mineMember) {
        this.mineTeamMember = mineMember
      }
    })

    ChatKitClient.nim.teamService?.on('onTeamMemberKicked', (accId, members) => {
      let removeIds: string[] = members.map(member => member.accountId)
      this.teamMemberList = this.teamMemberList.filter(m =>!removeIds.includes(m.getAccId()))
    })
    ChatKitClient.nim.teamService?.on('onTeamMemberLeft', (members) => {
      let removeIds: string[] = members.map(member => member.accountId)
      this.teamMemberList = this.teamMemberList.filter(m =>!removeIds.includes(m.getAccId()))
    })

  }

  /**
   * 获取群组信息
   * @param teamId
   * @returns
   */
  async getTeamInfo() {
    TeamRepo.getTeamInfo(this.teamId, this.teamType).then((team) => {
      this.team = team
    })
  }

  /**
   * 获取是否置顶和通知
   */
  getConversationInfo() {
    ConversationRepo.getConversation(ChatKitClient.nim.conversationIdUtil
      .teamConversationId(this.teamId)).then((conversation) => {
      this.isStickTop = conversation?.stickTop ?? false
      this.isMessageNotify = !(conversation?.mute ?? false)
    })
  }

  /**
   * 置顶或者取消置顶会话
   * @param stickTop 是否置顶
   */
  stickTopConversation(stickTop: boolean) {
    try {
      ConversationRepo.stickTopConversation(ChatKitClient.nim.conversationIdUtil
        .teamConversationId(this.teamId), stickTop)
      this.isStickTop = stickTop
    } catch (error) {
      this.isStickTop = !stickTop
    }
  }

  /**
   * 设置群消息是否通知
   * @param isOn
   */
  setTeamNotify(isOn: boolean) {
    try {
      SettingRepo.setTeamMessageMuteMode(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        isOn ? V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_OFF :
        V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_ON)
      this.isMessageNotify = isOn
    } catch (e) {
      this.isMessageNotify = !isOn
    }

  }

  /**
   * 设置群禁言
   * @param banned
   */
  bannedTeam(banned: boolean) {
    TeamRepo.setTeamChatBannedMode(
      this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
      banned ? V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_NORMAL :
      V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_UNBAN
    ).catch((e: V2NIMError) => {
      console.log(e.desc)
    })
  }


  /**
   * 更新群昵称
   * @param teamNick
   */
  updateTeamNick(teamNick: string) {
    const params: V2NIMUpdateSelfMemberInfoParams = {
      teamNick: teamNick
    }
    TeamRepo.updateSelfTeamMemberInfo(this.teamId,
      V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
      params)
  }

  /**
   * 获取群成员，附带用户信息
   * @returns
   */
  async getTeamMember() {
    let teamMemberResult = await TeamRepo.getTeamMembers(
      this.teamId,
      this.teamType,
      this.limit,
      this.nextToken
    )

    this.mineTeamMember =
      teamMemberResult?.memberList?.find(member => member.getAccId() === ChatKitClient.getLoginUserId())?.teamMember

    if (teamMemberResult) {
      this.teamMemberList.push(...teamMemberResult.memberList)
    }
  }
}