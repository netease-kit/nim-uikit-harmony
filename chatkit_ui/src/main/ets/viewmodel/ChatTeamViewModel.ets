/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatTeamInfo } from '../model/ChatTeamInfo';
import { ChatBaseViewModel } from './ChatBaseViewModel';
import { ChatKitClient, ChatRepo, ContactRepo, TeamMemberCache, TeamRepo } from '@nimkit/chatkit';
import {
  V2NIMFriend,
  V2NIMMessage,
  V2NIMMessageNotificationAttachment,
  V2NIMMessageType,
  V2NIMTeam,
  V2NIMTeamChatBannedMode,
  V2NIMTeamMember,
  V2NIMTeamMemberRole,
  V2NIMTeamMessageReadReceipt,
  V2NIMTeamType,
  V2NIMUser
} from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { HashSet } from '@kit.ArkTS';
import { ChatKitConfig } from '../ChatKitConfig';

@ObservedV2
export class ChatTeamViewModel extends ChatBaseViewModel {
  @Trace chatTeamInfo: ChatTeamInfo | undefined
  dialogToExit?: () => void
  private needUserMessageList: NIMMessageInfo[] = []
  //拉取全量成员的阈值
  private static allMemberLimit = 500

  /**
   * 是否展示禁言模式
   * @returns
   */
  @Computed
  get isMuteModel(): boolean {
    let isMuteModel = false
    if (this.chatTeamInfo?.getCurrentUserTeamMember()?.memberRole ===
    V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL) {
      isMuteModel = this.chatTeamInfo.team?.chatBannedMode ===
      V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_NORMAL
        || this.chatTeamInfo.team?.chatBannedMode === V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_ALL
    } else {
      isMuteModel =
        this.chatTeamInfo?.team?.chatBannedMode === V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_ALL
    }
    return isMuteModel
  }

  //初始化，获取会话ID和页面UI需要群相关信息ChatTeamInfo
  init(conversationId: string, chatInfo: ChatTeamInfo): void {
    super.init(conversationId, chatInfo);
    this.chatTeamInfo = chatInfo;
    ChatKitClient.nim.friendService?.on('onFriendInfoChanged', this.onFriendInfoChangedFun)
    ChatKitClient.nim.userService?.on('onUserProfileChanged', this.onUserProfileChangedFun)
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', this.teamUpdateFun)
    ChatKitClient.nim.teamService?.on('onTeamMemberJoined', this.onTeamMemberJoinedFun)
    ChatKitClient.nim.teamService?.on('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdatedFun)
    //群解散
    ChatKitClient.nim.teamService?.on('onTeamDismissed', this.onTeamDismissedFun)
    //退出群
    ChatKitClient.nim.teamService?.on('onTeamLeft', this.onTeamLeftFun)

    ChatKitClient.nim.teamService?.on('onSyncFinished', this.onTeamSyncFinishedFun)
    //群消息已读回执
    if (ChatKitConfig.messageReadState) {
      ChatRepo.onReceiveTeamMessageReadReceipts(this.onReceiveMessageReadReceiptFun)
    }
    let teamMemberCache = TeamMemberCache.getInstance()
    let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    teamMemberCache.intTeamInfo(teamId, chatInfo.team)
    if (chatInfo.team && chatInfo.team.memberCount < ChatTeamViewModel.allMemberLimit) {
      teamMemberCache.loadAllTeamMember()
    }
  }

  onFriendInfoChangedFun = (friendInfo: V2NIMFriend) => {
    if (this.chatTeamInfo?.teamUserMap.has(friendInfo.accountId)) {
      this.chatTeamInfo.addTeamFriend(friendInfo)
    }

  }
  onUserProfileChangedFun = (user: V2NIMUser[]) => {
    let updateUser: V2NIMUser[] = []
    user.forEach((item) => {
      if (this.chatTeamInfo?.teamUserMap.has(item.accountId)) {
        updateUser.push(item)
      }
    })
    if (updateUser.length > 0) {
      this.chatTeamInfo?.addTeamUser(updateUser)
    }

  }
  onReceiveMessageReadReceiptFun = (readReceipts: V2NIMTeamMessageReadReceipt[]) => {
    let currentReadReceipt: V2NIMTeamMessageReadReceipt[] = []
    readReceipts.forEach((item) => {
      if (this.conversationId == item.conversationId) {
        currentReadReceipt.push(item)
      }
    })
    if (currentReadReceipt.length > 0) {
      this.chatTeamInfo?.setTeamReadReadReceipt(currentReadReceipt)
    }
  }
  teamUpdateFun = (team: V2NIMTeam) => {
    if (team.teamId === ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId)) {
      this.chatTeamInfo?.setTeam(team)
    }
  }
  onTeamMemberJoinedFun = (teamMembers: V2NIMTeamMember[]) => {
    let currentTeamMember: V2NIMTeamMember[] = []
    teamMembers.forEach((item) => {
      if (this.targetId == item.teamId) {
        currentTeamMember.push(item)
      }
    })
    if (currentTeamMember.length > 0) {
      this.getTeamMemberUserInfo(teamMembers)
    }
  }
  onTeamMemberInfoUpdatedFun = (teamMembers: V2NIMTeamMember[]) => {
    let currentTeamMember: V2NIMTeamMember[] = []
    teamMembers.forEach((item) => {
      if (this.targetId == item.teamId) {
        currentTeamMember.push(item)
      }
    })
    if (currentTeamMember.length > 0) {
      this.chatTeamInfo?.addTeamMember(teamMembers)
    }
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
  onTeamSyncFinishedFun = () => {
    this.getTeamInfo()
  }

  async loadData() {
    this.getPinList()
    this.getMessageList()
    this.getTeamInfo()
  }

  reloadMessageList() {
    this.getMessageList()
    this.setAnchorMessage(undefined)
    this.getTeamInfo()
    this.hasNew = false
  }

  toHandleReceiveMessage(messages: NIMMessageInfo[]) {
    this.getTeamMemberInfoWithMessage(messages)
    this.getAndSendMessageReceipts(messages)

  }

  toHandleQueryMessage(messages: NIMMessageInfo[], originMsg: V2NIMMessage[]) {
    if (this.networkBroken) {
      messages.forEach((item, index, msgList) => {
        this.needUserMessageList.push(item)
      })
    }
    this.getTeamMemberInfoWithMessage(messages)
    this.getAndSendMessageReceipts(messages)
  }

  toHandleDataSyncFinished(): void {
    if (this.hasLoadData) {
      if (this.needUserMessageList.length > 0) {
        this.getTeamMemberInfoWithMessage(this.needUserMessageList)
        this.needUserMessageList = []
      }
      this.getPinList()
      if (this.chatTeamInfo?.msgList.getMessageList() !== undefined) {
        this.getAndSendMessageReceipts(this.chatTeamInfo?.msgList.getMessageList() ?? [])
      }
    } else {
      this.loadData()
    }

  }

  getAndSendMessageReceipts(messages: NIMMessageInfo[]) {
    if (ChatKitConfig.messageReadState) {
      let receiptMessage: V2NIMMessage[] = []
      let sendReceiptMessage: V2NIMMessage[] = []
      messages.forEach((item) => {
        if (item.configReadReceipt()) {
          if (item.isReceiveMsg) {
            sendReceiptMessage.push(item.message)
          } else {
            receiptMessage.push(item.message)
          }
        }
      })
      // 拉取消息已读回执
      ChatRepo.getTeamMessageReceipts(receiptMessage).then((messageReadReceipt) => {
        if (messageReadReceipt !== undefined) {
          this.chatTeamInfo?.setTeamReadReadReceipt(messageReadReceipt)
        }
      }).catch((error: Error) => {
        console.error(error.name)
      })
      // 发送消息已读回执
      ChatRepo.sendTeamMessageReceipt(sendReceiptMessage)
    }
  }

  //添加群退出的提示弹框
  setTeamExitListener(showDialogToExit: () => void) {
    this.dialogToExit = showDialogToExit
  }

  //获取群信息
  async getTeamInfo(): Promise<V2NIMTeam | undefined> {
    let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId);
    const teamInfo = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL);
    ChatKitClient.selfLeaveTeam = false
    if (teamInfo && teamInfo.isValidTeam !== true) {
      this.onTeamDismissedFun(teamInfo)
    } else {
      this.getTeamMemberListInfo([ChatKitClient.getLoginUserId()])
    }
    this.chatTeamInfo?.setTeam(teamInfo)
    return teamInfo
  }

  //获取群信息和群成员信息，包括群成员信息、用户信息
  getTeamMemberListInfo(accountList: string[]) {
    TeamRepo.getTeamMemberListByIds(this.targetId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, accountList)
      .then((teamMemberList: V2NIMTeamMember[]) => {
        this.chatTeamInfo?.addTeamMember(teamMemberList)
      })
      .catch((error: Error) => {
        console.error('netease getTeamMemberListInfo:getUserList ', error.name)
      });
    ContactRepo.getUserList(accountList).then((users) => {
      this.chatTeamInfo?.addTeamUser(users)

    }).catch((error: Error) => {
      console.error('netease getTeamMemberListInfo:getUserList ', error.name)
    });
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
    let requestAccountList: string[] = [];
    let requestUserAccountList: string[] = [];
    senderList.forEach(account => {
      if (account !== undefined && !this.chatTeamInfo?.teamMemberMap.has(account)) {
        requestAccountList.push(account)
      }
      if (account !== undefined && !this.chatTeamInfo?.teamUserMap.has(account)) {
        requestUserAccountList.push(account)
      }
    })
    if (requestAccountList.length > 0) {
      TeamRepo.getTeamMemberListByIds(this.targetId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, requestAccountList)
        .then((teamMemberList: V2NIMTeamMember[]) => {
          if (teamMemberList) {
            this.chatTeamInfo?.addTeamMember(teamMemberList)
          }
        })
        .catch((error: Error) => {
          console.error('netease getTeamMemberInfoWithMessage:getTeamMemberListByIds', error.name)
        });
    }
    if (requestUserAccountList.length > 0) {
      ContactRepo.getUserList(requestUserAccountList).then((teamUserInfo: V2NIMUser[]) => {
        this.chatTeamInfo?.addTeamUser(teamUserInfo)
      }).catch((error: Error) => {
        console.error('netease getTeamMemberInfoWithMessage:getUserList ', error.name)
      })
    }
  }

  onDestroy(): void {
    super.onDestroy()
    ChatKitClient.nim.teamService?.off('onTeamInfoUpdated', this.teamUpdateFun)
    ChatKitClient.nim.teamService?.off('onTeamMemberJoined', this.onTeamMemberJoinedFun)
    ChatKitClient.nim.teamService?.off('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdatedFun)
    ChatKitClient.nim.teamService?.off('onTeamDismissed', this.onTeamDismissedFun)
    ChatKitClient.nim.teamService?.off('onTeamLeft', this.onTeamLeftFun)
    ChatKitClient.nim.teamService?.off('onSyncFinished', this.onTeamSyncFinishedFun)
    ChatKitClient.nim.userService?.off('onUserProfileChanged', this.onUserProfileChangedFun)
    ChatKitClient.nim.friendService?.off('onFriendInfoChanged', this.onFriendInfoChangedFun)

    if (ChatKitConfig.messageReadState) {
      ChatRepo.offReceiveTeamMessageReadReceipts(this.onReceiveMessageReadReceiptFun)
    }
  }
}