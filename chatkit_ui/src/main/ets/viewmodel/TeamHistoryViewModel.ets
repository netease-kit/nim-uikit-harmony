/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatKitClient, ChatRepo, TeamMemberWithUser, TeamRepo } from '@nimkit/chatkit'
import { V2NIMMessage, V2NIMMessageType, V2NIMTeamMember, V2NIMTeamType } from '@nimsdk/base'

@ObservedV2
export class TeamHistoryModel {
  keyword: string
  message: V2NIMMessage
  @Trace teamMember?: TeamMemberWithUser

  constructor(keyword: string,
    message: V2NIMMessage,
    teamMember?: TeamMemberWithUser) {
    this.keyword = keyword
    this.message = message
    this.teamMember = teamMember
  }
}

@ObservedV2
export class TeamHistoryViewModel {
  teamId: string
  teamType: V2NIMTeamType = V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL
  mineTeamMember?: V2NIMTeamMember
  teamMemberList: TeamMemberWithUser[] = []
  @Trace historyList: TeamHistoryModel[] = []

  constructor(teamId: string) {
    this.teamId = teamId
  }

  async searchHistoryMessages(keyword: string) {
    this.clearHistoryMessages()
    try {
      const messages = await ChatRepo.searchCloudMessages({
        keyword: keyword,
        senderAccountIds: [],
        messageTypes: [V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT],
        teamIds: [this.teamId]
      })

      const accountList = messages.map(msg => msg.senderId)
      await this.getTeamMemberByIds(accountList)

      for (const message of messages) {
        const member = this.teamMemberList.find(member => member.getAccId() === message.senderId)
        const model = new TeamHistoryModel(keyword, message, member)
        this.historyList.push(model)
      }
    } catch (err) {
      console.error(err)
    }
  }

  clearHistoryMessages() {
    this.historyList = []
  }

  /**
   * 获取群成员，附带用户信息
   * @returns
   */
  async getTeamMemberByIds(accountList: string[]) {
    const loadedAccountList = this.teamMemberList.map(member => member.teamMember.accountId)
    const fetchAccountIds = accountList.filter(account =>!loadedAccountList.includes(account))
    try {
      let teamMemberList = await TeamRepo.getTeamMembersByIds(this.teamId, this.teamType, fetchAccountIds)
      this.teamMemberList.push(...teamMemberList)

      let mine = teamMemberList.find(member => member.getAccId() === ChatKitClient.getLoginUserId())?.teamMember
      if (mine) {
        this.mineTeamMember = mine
      } else {
        this.getMineTeamMember()
      }
    } catch (err) {
      console.error(err)
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
}