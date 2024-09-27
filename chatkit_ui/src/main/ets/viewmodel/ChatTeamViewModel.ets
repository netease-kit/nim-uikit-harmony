/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatTeamInfo } from '../model/ChatTeamInfo';
import { ChatBaseViewModel } from './ChatBaseViewModel';
import { ChatKitClient, ContactRepo, TeamRepo } from '@nimkit/chatkit';
import {
  V2NIMMessage,
  V2NIMMessageNotificationAttachment,
  V2NIMMessageType,
  V2NIMTeam,
  V2NIMTeamMember,
  V2NIMTeamType
} from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { HashSet } from '@kit.ArkTS';

export class ChatTeamViewModel extends ChatBaseViewModel {
  chatTeamInfo: ChatTeamInfo | undefined;
  dialogToExit?: () => void

  //初始化，获取会话ID和页面UI需要群相关信息ChatTeamInfo
  init(conversationId: string, chatInfo: ChatTeamInfo): void {
    super.init(conversationId, chatInfo);
    this.chatTeamInfo = chatInfo;
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', this.teamUpdateFun)
    ChatKitClient.nim.teamService?.on('onTeamMemberJoined', this.onTeamMemberJoinedFun)
    ChatKitClient.nim.teamService?.on('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdatedFun)
    //群解散
    ChatKitClient.nim.teamService?.on('onTeamDismissed', this.onTeamDismissedFun)
    //退出群
    ChatKitClient.nim.teamService?.on('onTeamLeft', this.onTeamLeftFun)
  }

  teamUpdateFun = (team: V2NIMTeam) => {
    if (team.teamId === ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId)) {
      this.chatTeamInfo?.setTeam(team)
    }
  }
  onTeamMemberJoinedFun = (teamMembers: V2NIMTeamMember[]) => {
    this.getTeamMemberUserInfo(teamMembers)
  }
  onTeamMemberInfoUpdatedFun = (teamMembers: V2NIMTeamMember[]) => {
    this.chatTeamInfo?.addTeamMember(teamMembers)
  }
  onTeamDismissedFun = (team: V2NIMTeam) => {
    if (team.teamId === this.chatTeamInfo?.team?.teamId) {
      if (!ChatKitClient.selfLeaveTeam && this.dialogToExit) {
        this.dialogToExit()
      }

    }
  }
  onTeamLeftFun = (team: V2NIMTeam) => {
    if (team.teamId === this.chatTeamInfo?.team?.teamId) {
      if (!ChatKitClient.selfLeaveTeam && this.dialogToExit) {
        this.dialogToExit()
      }
    }
  }

  toHandleReceiveMessage(message: NIMMessageInfo[]) {
    this.getTeamMemberInfoWithMessage(message)
  }

  //添加群退出的提示弹框
  setTeamExitListener(showDialogToExit: () => void) {
    this.dialogToExit = showDialogToExit
  }

  //获取群信息
  async getTeamInfo(): Promise<V2NIMTeam | undefined> {
    let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId);
    const teamInfo = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL);
    this.chatTeamInfo?.setTeam(teamInfo)
    ChatKitClient.selfLeaveTeam = false
    return teamInfo
  }


  //获取群信息和群成员信息，包括群成员信息、用户信息
  async getTeamMemberListInfo(accountList: string[]) {
    let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId);
    const teamMemberList =
      await TeamRepo.getTeamMemberListByIds(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, accountList);
    const teamUserInfo = await ContactRepo.getUserList(accountList);
    this.chatTeamInfo?.addTeamMember(teamMemberList)
    this.chatTeamInfo?.addTeamUser(teamUserInfo)
  }

  //获取群信息和群成员信息，包括群成员信息、用户信息
  async getTeamMemberUserInfo(teamMembers: V2NIMTeamMember[]) {
    this.chatTeamInfo?.addTeamMember(teamMembers)
    let accountList: string[] = [];
    teamMembers.forEach((member) => {
      accountList.push(member.accountId)
    })
    const teamUserInfo = await ContactRepo.getUserList(accountList);
    this.chatTeamInfo?.addTeamUser(teamUserInfo)
  }

  // 获取群成员信息，包括群成员信息、用户信息
  async getTeamMemberInfoWithMessage(msgList: NIMMessageInfo[]) {
    let senderList = new HashSet<string>();
    if (msgList.length < 1) {
      return
    }
    msgList.forEach((item, index, msgList) => {
      senderList.add(item.message.senderId)
      if (item.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION) {
        let attachment = item.message.attachment as V2NIMMessageNotificationAttachment
        attachment.targetIds?.forEach(account => {
          senderList.add(account)
        })

      }
    })
    let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId);
    let requestAccountList: string[] = [];
    senderList.forEach(account => {
      if (account !== undefined && !this.chatTeamInfo?.teamMemberMap.has(account)) {
        requestAccountList.push(account)
      }
    })
    if (requestAccountList.length > 0) {
      const teamMemberList =
        await TeamRepo.getTeamMemberListByIds(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, requestAccountList);
      const teamUserInfo = await ContactRepo.getUserList(requestAccountList);

      this.chatTeamInfo?.addTeamMember(teamMemberList)
      this.chatTeamInfo?.addTeamUser(teamUserInfo)
    }
  }

  onDestroy(): void {
    super.onDestroy()
    ChatKitClient.nim.teamService?.off('onTeamInfoUpdated', this.teamUpdateFun)
    ChatKitClient.nim.teamService?.on('onTeamMemberJoined', this.onTeamMemberJoinedFun)
    ChatKitClient.nim.teamService?.on('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdatedFun)
    ChatKitClient.nim.teamService?.on('onTeamDismissed', this.onTeamDismissedFun)
    ChatKitClient.nim.teamService?.on('onTeamLeft', this.onTeamLeftFun)
  }
}