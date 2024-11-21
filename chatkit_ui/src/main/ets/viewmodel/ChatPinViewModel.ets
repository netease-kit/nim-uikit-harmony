/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatTeamInfo } from '../model/ChatTeamInfo';
import { ChatKitClient, ChatRepo, ContactRepo, NEFriendUserCache, TeamRepo } from '@nimkit/chatkit';
import {
  V2NIMConnectStatus,
  V2NIMConversationType,
  V2NIMLoginStatus,
  V2NIMMessage,
  V2NIMMessageConfig,
  V2NIMMessageDeletedNotification,
  V2NIMMessageNotificationAttachment,
  V2NIMMessagePin,
  V2NIMMessagePinNotification,
  V2NIMMessagePinState,
  V2NIMMessageRefer,
  V2NIMMessageType,
  V2NIMSendMessageParams,
  V2NIMTeam,
  V2NIMTeamType
} from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { HashSet } from '@kit.ArkTS';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import { BusinessError } from '@kit.BasicServicesKit';
import { sendMessageFailedTips } from '../common/MessageHelper';

@ObservedV2
export class ChatPinViewModel {
  @Trace pinListEmpty: boolean = false;
  @Trace conversationId: string = "";
  @Trace chatTeamInfo?: ChatTeamInfo;
  @Trace topInsert = false
  networkBroken = false
  onMessagePinNotification = async (notification: V2NIMMessagePinNotification) => {
    switch (notification.pinState) {
      case V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_NOT_PINNED:
        this.chatTeamInfo?.deleteMessage(notification.pin.messageRefer.messageClientId)
        break
      case V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_PINNED:
        let message = this.chatTeamInfo?.getMessage(notification.pin.messageRefer.messageClientId)
        if (!message) {
          const messages = await ChatRepo.getMessageListByRefers([notification.pin.messageRefer])
          if (messages.length > 0) {
            message = new NIMMessageInfo(messages[0]);
          }
          if (message && this.chatTeamInfo) {
            message.isPinMsg = true
            let insert = false
            for (let index = 0; index < this.chatTeamInfo.msgList.totalCount(); index++) {
              if (message.message.createTime > this.chatTeamInfo?.msgList.getData(index).getCreateTime()) {
                if (index === 0) {
                  this.topInsert = true
                }
                this.chatTeamInfo?.msgList.addData(index, message)
                insert = true
                break
              }
            }
            if (!insert) {
              this.chatTeamInfo?.msgList.push(message)
            }
            this.getTeamMemberInfoWithMessage([message])
          }
        }
        break
      default:
        break
    }
    this.pinListEmpty = (this.chatTeamInfo?.msgList?.totalCount() ?? 0) <= 0
  }
  // 登录状态改变
  onLoginStatusFun = async (status: V2NIMLoginStatus) => {
    if (this.networkBroken && status === V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED) {
      try {
        await this.getPinMessageList()
      } catch (err) {
        console.error(err)
      }
    }
  }

  //初始化，获取会话ID和页面UI需要群相关信息ChatTeamInfo
  init(conversationId: string, chatInfo: ChatTeamInfo): void {
    this.chatTeamInfo = chatInfo;
    this.conversationId = conversationId
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', this.teamUpdateFun)
    // 长连接状态变更
    ChatKitClient.nim.loginService?.on('onConnectStatus', this.onConnectStatusFun)
    // 登录状态变更
    ChatKitClient.nim.loginService?.on('onLoginStatus', this.onLoginStatusFun)

    ChatRepo.onMessagePinNotification(this.onMessagePinNotification)
    ChatRepo.onDeleteMessage(this.onDeleteFun)
  }

  // 删除消息
  onDeleteFun = (messages: V2NIMMessageDeletedNotification[]) => {
    messages.forEach((msg) => {
      this.chatTeamInfo?.deleteMessage(msg.messageRefer.messageClientId)
    })
  }
  // 群更新
  teamUpdateFun = (team: V2NIMTeam) => {
    if (team.teamId === ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId)) {
      this.chatTeamInfo?.setTeam(team)
    }
  }
  // 长连接状态改变
  onConnectStatusFun = (status: V2NIMConnectStatus) => {
    if (status === V2NIMConnectStatus.V2NIM_CONNECT_STATUS_WAITING) {
      this.networkBroken = true
    }
  }

  // 获取标记列表
  async getPinMessageList(): Promise<NIMMessageInfo[]> {
    let msgList: NIMMessageInfo[] = [];
    this.chatTeamInfo?.cleanMessage()
    try {
      const pinMessageList: V2NIMMessagePin[] = await ChatRepo.getPinnedMessageList(this.conversationId)
      let fetchMessageReferList: V2NIMMessageRefer[] = pinMessageList.map(pin => pin.messageRefer)
      if (fetchMessageReferList.length > 0) {
        const fetchMessageList: V2NIMMessage[] = await ChatRepo.getMessageListByRefers(fetchMessageReferList)
        fetchMessageList.sort((msg1, msg2) => {
          if (msg1.createTime > msg2.createTime) {
            return -1
          }
          if (msg1.createTime < msg2.createTime) {
            return 1
          }
          return 0
        })
        for (const msg of fetchMessageList) {
          let msgInfo = this.chatTeamInfo?.pushMessage(msg);
          if (msgInfo) {
            msgInfo.isPinMsg = true
            msgList.push(msgInfo);
          }
        }
      }
      this.pinListEmpty = msgList.length <= 0
      const conversationType = ChatKitClient.nim.conversationIdUtil.parseConversationType(this.conversationId)
      if (conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        const targetAccountId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId)
        const targetUser = await ContactRepo.getUserListFromCloud([targetAccountId])
        this.chatTeamInfo?.addTeamUser(targetUser)
        if (NEFriendUserCache.mineUserCache?.user) {
          this.chatTeamInfo?.addTeamUser([NEFriendUserCache.mineUserCache?.user])
        }
      } else {
        this.getTeamMemberInfoWithMessage(msgList)
        this.getTeamInfo()
      }
      return msgList;
    } catch (err) {
      console.log(err)
      return msgList;
    }
  }

  //获取群信息
  async getTeamInfo(): Promise<V2NIMTeam | undefined> {
    let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId);
    const teamInfo = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL);
    this.chatTeamInfo?.setTeam(teamInfo)
    ChatKitClient.selfLeaveTeam = false
    return teamInfo
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


  // 消息发送之前调用，用于配置消息通用参数
  beforeSendMessage(msg: V2NIMMessage): V2NIMMessage {
    let msgConfig: V2NIMMessageConfig = {
      readReceiptEnabled: true
    }
    msg.messageConfig = msgConfig
    return msg
  }

  /**
   * 转发消息
   * @param msg 消息体
   * @param conversationId 转发到某个会话
   * @param params 消息参数
   * @param progress 消息发送进度
   */
  async sendForwardMessage(msg: V2NIMMessage, conversationId: string, params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void) {
    ChatRepo.sendMessage(this.beforeSendMessage(msg), conversationId, params, progress).catch((err: BusinessError) => {
      console.error("net ease send message error", err.code, err.message);
      sendMessageFailedTips(msg, err, conversationId)
    })
  }

  /**
   * 将多个消息转发到多个会话中，并将留言发送到多个会话中
   * @param messages 待转发的消息
   * @param conversationIds 带转发的会话
   * @param leaveText 留言
   */
  forwardMessage(messages: NIMMessageInfo[], conversationIds: ConversationSelectModel[],
    leaveText: string | undefined) {
    conversationIds.forEach((conversation) => {
      messages.forEach((message) => {
        const forwardMsg = ChatRepo.createForwardMessage(message.message)
        try {
          if (forwardMsg && conversation.conversationId) {
            this.sendForwardMessage(forwardMsg, conversation.conversationId)
          }
        } catch (err) {
          console.error(err)
        }
      })

      // 发送留言
      if (leaveText && leaveText.length > 0) {
        const leaveMsg = ChatRepo.createTextMessage(leaveText)
        if (leaveMsg && conversation.conversationId) {
          setTimeout(() => {
            ChatRepo.sendMessage(leaveMsg, conversation.conversationId!)
              .catch((err: BusinessError) => {
                console.error("net ease send message error", err.code, err.message);
                sendMessageFailedTips(leaveMsg, err, conversation.conversationId!)
              })
          }, 200)
        }
      }
    })
  }

  onDestroy(): void {
    ChatKitClient.nim.teamService?.off('onTeamInfoUpdated', this.teamUpdateFun)
    // 长连接状态变更
    ChatKitClient.nim.loginService?.off('onConnectStatus', this.onConnectStatusFun)
    // 登录状态变更
    ChatKitClient.nim.loginService?.off('onLoginStatus', this.onLoginStatusFun)
    ChatRepo.offMessagePinNotification(this.onMessagePinNotification)
    ChatRepo.offDeleteMessage(this.onDeleteFun)
  }
}