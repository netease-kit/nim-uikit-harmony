/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  ChatKitClient,
  ContactRepo,
  ConversationRepo,
  IMKitConfigCenter,
  LocalConversationRepo,
  SettingRepo,
  TeamRepo
} from '@nimkit/chatkit';
import {
  V2NIMConversation,
  V2NIMConversationType,
  V2NIMError,
  V2NIMQueryDirection,
  V2NIMTeam,
  V2NIMTeamChatBannedMode,
  V2NIMTeamMember,
  V2NIMTeamMessageMuteMode,
  V2NIMTeamType,
  V2NIMUpdateSelfMemberInfoParams
} from '@nimsdk/base';
import { TeamMemberWithUser } from '@nimkit/chatkit/src/main/ets/model/TeamMemberWithUser';

@ObservedV2
export class TeamSettingViewModel {
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

  /**
   * 获取群成员，附带用户信息
   * @returns
   */
  async getTeamMember() {
    let teamMemberResult = await TeamRepo.getTeamMembers(
      this.teamId,
      this.teamType,
      {
        limit: this.limit,
        nextToken: this.nextToken,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
      }
    )

    let mine =
      teamMemberResult?.memberList?.find(member => member.getAccId() === ChatKitClient.getLoginUserId())?.teamMember

    if (mine) {
      this.mineTeamMember = mine
    } else {
      this.getMineTeamMember()
    }

    if (teamMemberResult) {
      this.teamMemberList.splice(0, this.teamMemberList.length)
      this.teamMemberList.push(...teamMemberResult.memberList)
    }
  }

  //获取自己的群成员信息
  getMineTeamMember() {
    TeamRepo.getTeamMemberListByIds(this.teamId,
      this.teamType, [ChatKitClient.getLoginUserId()]).then((members) => {
      if (members.length > 0) {
        this.mineTeamMember = members[0]
      }
    })
  }

  onSyncFinished() {
    this.getTeamMember()
    this.getTeamInfo()
  }

  onTeamInfoUpdated(team: V2NIMTeam) {
    if (team.teamId === this.teamId) {
      this.team = team
    }
  }

  async onTeamMemberJoined(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let userList = await ContactRepo.getUserWithFriendByIds(members.map(member => member.accountId))
      let memberList: TeamMemberWithUser[] = members.map(e => {
        let user = userList.find((user) => user.user?.accountId === e.accountId)
        return new TeamMemberWithUser(e, user?.friend, user?.user)
      })

      this.teamMemberList.push(...memberList)
    }
  }

  onTeamMemberInfoUpdated(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let mineMember = members.find(member => member.accountId === ChatKitClient.getLoginUserId())
      if (mineMember) {
        this.mineTeamMember = mineMember
      }
    }
  }

  onTeamMemberKicked(accId: string, members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.teamMemberList = this.teamMemberList.filter(m => !removeIds.includes(m.getAccId()))
    }
  }

  onTeamMemberLeft(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.teamMemberList = this.teamMemberList.filter(m => !removeIds.includes(m.getAccId()))
    }
  }

  onConversationChanged(updateList: V2NIMConversation[]) {
    updateList.forEach((conversation) => {
      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM &&
        conversation.conversationId === ChatKitClient.nim.conversationIdUtil.teamConversationId(this.teamId)) {
        this.isMessageNotify = !(conversation.mute ?? false)
        this.isStickTop = conversation.stickTop
      }
    })
  }

  initTeamInfo() {
    this.getTeamInfo();
    this.getConversationInfo();
    this.getTeamMember();
    ChatKitClient.nim.teamService?.on('onSyncFinished', this.onSyncFinished.bind(this))
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', this.onTeamInfoUpdated.bind(this))
    ChatKitClient.nim.teamService?.on('onTeamMemberJoined', this.onTeamMemberJoined.bind(this))

    ChatKitClient.nim.teamService?.on('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated.bind(this))

    ChatKitClient.nim.teamService?.on('onTeamMemberKicked', this.onTeamMemberKicked.bind(this))
    ChatKitClient.nim.teamService?.on('onTeamMemberLeft', this.onTeamMemberLeft.bind(this))

    ChatKitClient.nim.conversationService?.on("onConversationChanged", this.onConversationChanged.bind(this))
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
    if (IMKitConfigCenter.enableLocalConversation) {
      LocalConversationRepo.getConversation(ChatKitClient.nim.conversationIdUtil.teamConversationId(this.teamId))
        .then((conversation) => {
          this.isStickTop = conversation?.stickTop ?? false
          this.isMessageNotify = !(conversation?.mute ?? false)
        })
    } else {
      ConversationRepo.getConversation(ChatKitClient.nim.conversationIdUtil
        .teamConversationId(this.teamId)).then((conversation) => {
        this.isStickTop = conversation?.stickTop ?? false
        this.isMessageNotify = !(conversation?.mute ?? false)
      })
    }
  }

  /**
   * 置顶或者取消置顶会话
   * @param stickTop 是否置顶
   */
  stickTopConversation(stickTop: boolean) {
    try {
      if (IMKitConfigCenter.enableLocalConversation) {
        LocalConversationRepo.stickTopConversation(ChatKitClient.nim.conversationIdUtil.teamConversationId(this.teamId),
          stickTop)
      } else {
        ConversationRepo.stickTopConversation(ChatKitClient.nim.conversationIdUtil
          .teamConversationId(this.teamId), stickTop)
      }
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
      ChatKitClient.logger?.debug(e.desc)
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
      params).then(() => {

    }).catch((e: V2NIMError) => {
      ChatKitClient.logger?.debug(`TeamSettingViewModel updateTeamNick error = ${e.message} `)
    })
  }

  destroy() {
    ChatKitClient.nim.teamService?.off('onSyncFinished', this.onSyncFinished)
    ChatKitClient.nim.teamService?.off('onTeamInfoUpdated', this.onTeamInfoUpdated)
    ChatKitClient.nim.teamService?.off('onTeamMemberJoined', this.onTeamMemberJoined)

    ChatKitClient.nim.teamService?.off('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated)

    ChatKitClient.nim.teamService?.off('onTeamMemberKicked', this.onTeamMemberKicked)
    ChatKitClient.nim.teamService?.off('onTeamMemberLeft', this.onTeamMemberLeft)

    ChatKitClient.nim.conversationService?.off("onConversationChanged", this.onConversationChanged)
  }
}