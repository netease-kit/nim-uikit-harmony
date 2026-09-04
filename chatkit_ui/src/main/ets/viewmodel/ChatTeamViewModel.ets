/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatTeamInfo } from '../model/ChatTeamInfo';
import { ChatBaseViewModel } from './ChatBaseViewModel';
import {
  ChatKitClient,
  ChatRepo,
  ContactRepo,
  DisposableBag,
  FriendEventRepo,
  AIUserManager,
  ErrorUtils,
  IMKitConfigCenter,
  keyExtensionLastOptType,
  keyExtensionSticky,
  keyExtensionTopSticky,
  NEFriendUserCache,
  TeamEventRepo,
  TeamMemberCache,
  TeamRepo,
  UserEventRepo,
  typeExtensionStickyAdd,
  typeExtensionStickyRemove
} from '@nimkit/chatkit';
import {
  V2NIMConversationType,
  V2NIMErrorCode,
  V2NIMFriend,
  V2NIMFriendDeletionType,
  V2NIMMessage,
  V2NIMMessageDeletedNotification,
  V2NIMMessageNotificationAttachment,
  V2NIMMessageRevokeNotification,
  V2NIMMessageRefer,
  V2NIMMessageType,
  V2NIMTeam,
  V2NIMTeamChatBannedMode,
  V2NIMTeamMember,
  V2NIMTeamMemberRole,
  V2NIMTeamMessageReadReceipt,
  V2NIMTeamType,
  V2NIMUpdateTeamInfoParams,
  V2NIMUser
} from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { BusinessError } from '@kit.BasicServicesKit';
import { ChatKitConfig } from '../ChatKitConfig';
import { TopStickyMessage } from '../model/TopStickyMessage';
import { havePermissionForTopSticky } from '../common/ChatUtils';
import { extractAitAccountIds } from '../common/MessageHelper';
import { isTopMessageDeleted, isTopMessageRevoked } from '../utils/TopMessageBarUtils';
import { NECommonUtils } from '@nimkit/common';

class InvalidTeamResolution {
  teamInfo?: V2NIMTeam
  shouldShowExitWarning: boolean

  constructor(teamInfo: V2NIMTeam | undefined, shouldShowExitWarning: boolean) {
    this.teamInfo = teamInfo
    this.shouldShowExitWarning = shouldShowExitWarning
  }
}

@ObservedV2
export class ChatTeamViewModel extends ChatBaseViewModel {
  @Trace chatTeamInfo: ChatTeamInfo | undefined
  /** 当前置顶消息 */
  @Trace topMessage: NIMMessageInfo | undefined = undefined
  /** 当前用户是否有置顶操作权限 */
  @Trace hasTopPermission: boolean = false
  @Trace shouldShowTeamExitWarning: boolean = false
  dialogToExit?: () => void
  private needUserMessageList: NIMMessageInfo[] = []
  private eventDisposers: DisposableBag = new DisposableBag()
  private teamSessionId: number = 0

  supportsMessageReaction(): boolean {
    return true
  }

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
    this.teamSessionId += 1
    super.init(conversationId, chatInfo);
    this.chatTeamInfo = chatInfo;
    ChatRepo.onDeleteMessage(this.onTopMessageDeleteFun)
    ChatRepo.onRevokeMessage(this.onTopMessageRevokeFun)
    this.eventDisposers.dispose()
    this.eventDisposers.addAll([
      FriendEventRepo.onFriendInfoChanged(this.onFriendInfoChangedFun),
      FriendEventRepo.onFriendDeleted(this.onFriendInfoDeleteFun),
      UserEventRepo.onUserProfileChanged(this.onUserProfileChangedFun),
      TeamEventRepo.onTeamInfoUpdated(this.teamUpdateFun),
      TeamEventRepo.onTeamJoined(this.onTeamJoinedFun),
      TeamEventRepo.onTeamMemberJoined(this.onTeamMemberJoinedFun),
      TeamEventRepo.onTeamMemberInfoUpdated(this.onTeamMemberInfoUpdatedFun),
      TeamEventRepo.onTeamDismissed(this.onTeamDismissedFun),
      TeamEventRepo.onTeamLeft(this.onTeamLeftFun),
      TeamEventRepo.onTeamSyncFinished(this.onTeamSyncFinishedFun)
    ])
    //群消息已读回执
    if (ChatKitConfig.messageReadState) {
      ChatRepo.onReceiveTeamMessageReadReceipts(this.onReceiveMessageReadReceiptFun)
    }
    let teamMemberCache = TeamMemberCache.getInstance()
    let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    teamMemberCache.intTeamInfo(teamId, chatInfo.team)
  }

  onFriendInfoChangedFun = (friendInfo: V2NIMFriend) => {
    if (this.chatTeamInfo?.teamUserMap.has(friendInfo.accountId)) {
      NEFriendUserCache.getInstance().updateFriendInfo({ friend: friendInfo })
      this.chatTeamInfo.addTeamFriend(friendInfo)
      this.chatTeamInfo.msgList.notifyDataReload()
    }

  }
  onFriendInfoDeleteFun = (accountId: string, _deletionType?: V2NIMFriendDeletionType) => {
    const friendCache = NEFriendUserCache.getInstance()
    const hadFriend = this.chatTeamInfo?.teamUserFriendMap.has(accountId) || friendCache.getFriendById(accountId) !== undefined
    friendCache.removeFriendInfo(accountId)
    if (this.chatTeamInfo?.teamUserFriendMap.has(accountId)) {
      this.chatTeamInfo.removeTeamFriend(accountId)
    }
    if (hadFriend) {
      this.chatTeamInfo?.msgList.notifyDataReload()
    }
  }
  onUserProfileChangedFun = (user: V2NIMUser[]) => {
    let updateUser: V2NIMUser[] = []
    user.forEach((item) => {
      if (item.accountId == ChatKitClient.getLoginUserId() || this.chatTeamInfo?.teamUserMap.has(item.accountId)) {
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
      if (team.isValidTeam) {
        this.shouldShowTeamExitWarning = false
      }
      this.chatTeamInfo?.setTeam(team)
      if (!IMKitConfigCenter.enableTopMessage) {
        this.topMessage = undefined
      } else if (team.serverExtension) {
        this.handleTopMessage(team.serverExtension)
      }
      // 处理置顶消息和权限变更
      if (team.serverExtension) {
        this.handleTopMessagePermission(team.serverExtension)
      }
    }
  }
  onTeamJoinedFun = async (team: V2NIMTeam): Promise<void> => {
    if (team.teamId === this.targetId) {
      const currentTeamSessionId = this.teamSessionId
      ChatKitClient.selfLeaveTeam = false
      this.shouldShowTeamExitWarning = false
      this.chatTeamInfo?.setTeam(team)
      await this.getTeamMemberListInfo([ChatKitClient.getLoginUserId()])
      // 成员信息同步完成后再刷新历史标记状态
      if (currentTeamSessionId === this.teamSessionId) {
        this.getPinList()
      }
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
      this.chatTeamInfo?.addTeamMember(currentTeamMember)
      this.updateTopPermission()
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

  private onTopMessageDeleteFun = (messages: V2NIMMessageDeletedNotification[]) => {
    const currentTopMessage = this.topMessage
    if (!currentTopMessage) {
      return
    }

    for (const message of messages) {
      if (message.messageRefer.conversationId !== this.conversationId) {
        continue
      }

      if (isTopMessageDeleted(
        currentTopMessage.message.messageClientId,
        currentTopMessage.message.messageServerId,
        message.messageRefer.messageClientId,
        message.messageRefer.messageServerId
      )) {
        this.topMessage = undefined
        break
      }
    }
  }

  private onTopMessageRevokeFun = (messages: V2NIMMessageRevokeNotification[]) => {
    const currentTopMessage = this.topMessage
    if (!currentTopMessage) {
      return
    }

    for (const message of messages) {
      if (message.messageRefer.conversationId !== this.conversationId) {
        continue
      }

      if (isTopMessageRevoked(
        currentTopMessage.message.messageClientId,
        currentTopMessage.message.messageServerId,
        message.messageRefer.messageClientId,
        message.messageRefer.messageServerId
      )) {
        this.topMessage = undefined
        break
      }
    }
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
  }

  /**
   * 消息发送成功后的处理，获取该消息的已读回执
   * @param message 发送成功的消息
   */
  toHandleSendMessageSuccess(message: V2NIMMessage): void {
    // 发送成功后，立即获取该消息的已读回执（解决单人群聊不显示已读状态的问题）
    const msgInfo = this.chatTeamInfo?.getMessage(message.messageClientId)
    if (msgInfo) {
      this.getAndSendMessageReceipts([msgInfo])
    }
  }

  toHandleQueryMessage(messages: NIMMessageInfo[], originMsg: V2NIMMessage[]) {
    if (this.networkBroken) {
      messages.forEach((item, index, msgList) => {
        this.needUserMessageList.push(item)
      })
    }
    this.getTeamMemberInfoWithMessage(messages)
  }

  toHandleDataSyncFinished(): void {
    if (this.hasLoadData) {
      if ((this.chatTeamInfo?.msgList.totalCount() ?? 0) === 0) {
        this.getMessageList()
      }
      if (this.needUserMessageList.length > 0) {
        this.getTeamMemberInfoWithMessage(this.needUserMessageList)
        this.needUserMessageList = []
      }
      this.getPinList()
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
      // receiptMessage 拉取消息已读回执，一次执行最多 50 个
      for (let i = 0; i < receiptMessage.length; i += 50) {
        ChatRepo.getTeamMessageReceipts(receiptMessage.slice(i, i + 50))
          .then((messageReadReceipt: V2NIMTeamMessageReadReceipt[] | undefined) => {
            if (messageReadReceipt !== undefined) {
              this.chatTeamInfo?.setTeamReadReadReceipt(messageReadReceipt)
            }
          })
          .catch((error: Error) => {
            Logger.error('ChatKitUI', error.name)
          })
      }

      // sendReceiptMessage 发送消息已读回执，一次执行最多 50 个
      // 只有在页面可见时才发送已读回执
      if (this.isPageVisible) {
        for (let i = 0; i < sendReceiptMessage.length; i += 50) {
          ChatRepo.sendTeamMessageReceipt(sendReceiptMessage.slice(i, i + 50))
        }
      }
    }
  }

  //添加群退出的提示弹框
  setTeamExitListener(showDialogToExit: () => void) {
    this.dialogToExit = showDialogToExit
  }

  //获取群信息
  async getTeamInfo(): Promise<V2NIMTeam | undefined> {
    const currentTeamSessionId = this.teamSessionId
    let teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId);
    let teamInfo = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL);
    ChatKitClient.selfLeaveTeam = false
    const invalidTeamResolution = await this.resolveInvalidTeam(teamId, teamInfo)
    if (currentTeamSessionId !== this.teamSessionId) {
      return undefined
    }
    teamInfo = invalidTeamResolution.teamInfo
    this.shouldShowTeamExitWarning = invalidTeamResolution.shouldShowExitWarning
    if (!invalidTeamResolution.shouldShowExitWarning && teamInfo) {
      this.getTeamMemberListInfo([ChatKitClient.getLoginUserId()])
    }
    this.chatTeamInfo?.setTeam(teamInfo)
    if (teamInfo && currentTeamSessionId === this.teamSessionId) {
      const teamMemberCache = TeamMemberCache.getInstance()
      teamMemberCache.intTeamInfo(teamId, teamInfo)
    }
    if (!IMKitConfigCenter.enableTopMessage) {
      this.topMessage = undefined
    } else if (teamInfo?.serverExtension) {
      // 进入群聊时加载置顶消息
      this.handleTopMessage(teamInfo.serverExtension)
    }
    // 权限取决于 team 类型 + 当前成员角色，不能只在 serverExtension 存在时刷新
    this.updateTopPermission()
    return teamInfo
  }

  private async resolveInvalidTeam(teamId: string,
    teamInfo?: V2NIMTeam): Promise<InvalidTeamResolution> {
    if (!teamInfo || teamInfo.isValidTeam === true) {
      return new InvalidTeamResolution(teamInfo, false)
    }

    const selfInTeam = await this.isCurrentUserStillInTeam(teamId)
    if (!selfInTeam) {
      return new InvalidTeamResolution(teamInfo, true)
    }

    try {
      const refreshedTeam = await TeamRepo.getTeamInfoFromCloud(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
      return new InvalidTeamResolution(refreshedTeam ?? teamInfo, false)
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatTeamViewModel resolveInvalidTeam getTeamInfoFromCloud error', err)
      return new InvalidTeamResolution(teamInfo, false)
    }
  }

  private async isCurrentUserStillInTeam(teamId: string): Promise<boolean> {
    try {
      const teamMembers = await TeamRepo.getTeamMemberListByIds(teamId,
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        [ChatKitClient.getLoginUserId()])
      const selfMember = teamMembers.find(member => member.accountId === ChatKitClient.getLoginUserId())
      if (selfMember === undefined) {
        return true
      }
      return selfMember.inTeam !== false
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatTeamViewModel isCurrentUserStillInTeam error', err)
      return true
    }
  }

  //获取群信息和群成员信息，包括群成员信息、用户信息
  async getTeamMemberListInfo(accountList: string[]): Promise<void> {
    const teamMemberPromise = TeamRepo.getTeamMemberListByIds(
      this.targetId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, accountList
    )
      .then((teamMemberList: V2NIMTeamMember[]) => {
        this.chatTeamInfo?.addTeamMember(teamMemberList)
        this.updateTopPermission()
      })
      .catch((error: Error) => {
        Logger.error('ChatKitUI', 'netease getTeamMemberListInfo:getUserList ', error.name)
      });
    const userPromise = ContactRepo.getUserList(accountList).then((users) => {
      this.chatTeamInfo?.addTeamUser(users)

    }).catch((error: Error) => {
      Logger.error('ChatKitUI', 'netease getTeamMemberListInfo:getUserList ', error.name)
    });
    await Promise.all([teamMemberPromise, userPromise])
  }

  //获取群信息和群成员信息，包括群成员信息、用户信息
  async getTeamMemberUserInfo(teamMembers: V2NIMTeamMember[]) {
    this.chatTeamInfo?.addTeamMember(teamMembers)
    this.updateTopPermission()
    let accountList: string[] = [];
    teamMembers.forEach((member) => {
      accountList.push(member.accountId)
    })
    const teamUserInfo = await ContactRepo.getUserList(accountList);
    this.chatTeamInfo?.addTeamUser(teamUserInfo)
  }

  // 获取群成员信息，包括群成员信息、用户信息
  async getTeamMemberInfoWithMessage(msgList: NIMMessageInfo[]) {
    let senderList = new Set<string>();
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
      extractAitAccountIds(item.message.serverExtension).forEach((accountId) => {
        senderList.add(accountId)
      })
    })
    let requestAccountList: string[] = [];
    let requestUserAccountList: string[] = [];
    let requestFriendAccountList: string[] = [];
    let hasCachedFriendAdded = false
    senderList.forEach(account => {
      if (account !== undefined && !AIUserManager.isAIUser(account) && !this.chatTeamInfo?.teamMemberMap.has(account)) {
        requestAccountList.push(account)
      }
      if (account !== undefined && !AIUserManager.isAIUser(account) && !this.chatTeamInfo?.teamUserMap.has(account)) {
        requestUserAccountList.push(account)
      }
      if (account !== undefined && !AIUserManager.isAIUser(account)) {
        const cachedFriend = NEFriendUserCache.getInstance().getFriendById(account)?.friend
        if (cachedFriend) {
          if (!this.chatTeamInfo?.teamUserFriendMap.has(account)) {
            this.chatTeamInfo?.addTeamFriend(cachedFriend)
            hasCachedFriendAdded = true
          }
        } else if (!this.chatTeamInfo?.teamUserFriendMap.has(account)) {
          requestFriendAccountList.push(account)
        }
      }
    })
    if (hasCachedFriendAdded) {
      this.chatTeamInfo?.msgList.notifyDataReload()
    }
    if (requestAccountList.length > 0) {
      TeamRepo.getTeamMemberListByIds(this.targetId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, requestAccountList)
        .then((teamMemberList: V2NIMTeamMember[]) => {
          if (teamMemberList) {
            this.chatTeamInfo?.addTeamMember(teamMemberList)
          }
        })
        .catch((error: Error) => {
          Logger.error('ChatKitUI', 'netease getTeamMemberInfoWithMessage:getTeamMemberListByIds', error.name)
        });
    }
    if (requestUserAccountList.length > 0) {
      // 使用 getUserListFromCloud 从云端获取用户信息，确保能获取到已退群用户的信息
      ContactRepo.getUserListFromCloud(requestUserAccountList).then((teamUserInfo: V2NIMUser[]) => {
        this.chatTeamInfo?.addTeamUser(teamUserInfo)
      }).catch((error: Error) => {
        Logger.error('ChatKitUI', 'netease getTeamMemberInfoWithMessage:getUserListFromCloud ', error.name)
      })
    }
    if (requestFriendAccountList.length > 0) {
      ContactRepo.getFriendByIds(requestFriendAccountList).then((teamFriendInfo: V2NIMFriend[]) => {
        teamFriendInfo.forEach((friend) => {
          NEFriendUserCache.getInstance().updateFriendInfo({ friend: friend })
          this.chatTeamInfo?.addTeamFriend(friend)
        })
        if (teamFriendInfo.length > 0) {
          this.chatTeamInfo?.msgList.notifyDataReload()
        }
      }).catch((error: Error) => {
        Logger.error('ChatKitUI', 'netease getTeamMemberInfoWithMessage:getFriendByIds ', error.name)
      })
    }
  }

  // ========== 置顶消息相关方法 ==========

  /**
   * 解析 serverExtension 中的置顶消息信息
   * operation=0 时获取完整消息并展示，operation=1 时隐藏
   */
  handleTopMessage(serverExtension: string): void {
    if (!IMKitConfigCenter.enableTopMessage) {
      this.topMessage = undefined
      return
    }
    try {
      const ext = JSON.parse(serverExtension) as object
      const topJson = ext?.[keyExtensionSticky] as object
      if (!topJson) {
        return
      }
      const topStickyMsg = TopStickyMessage.fromJson(topJson)
      if (topStickyMsg.operation === typeExtensionStickyAdd) {
        // 添加置顶：通过消息引用获取完整消息
        this.getTopStickyMessage(topStickyMsg)
      } else if (topStickyMsg.operation === typeExtensionStickyRemove) {
        // 移除置顶
        this.topMessage = undefined
      }
    } catch (_e) {
      ChatKitClient.logger?.debug('handleTopMessage parse error')
    }
  }

  /**
   * 根据置顶消息引用获取完整消息内容
   */
  private async getTopStickyMessage(topStickyMsg: TopStickyMessage): Promise<void> {
    try {
      const refer: V2NIMMessageRefer = {
        senderId: topStickyMsg.from,
        receiverId: topStickyMsg.receiverId,
        messageClientId: topStickyMsg.idClient,
        messageServerId: topStickyMsg.idServer,
        createTime: topStickyMsg.time,
        conversationType: V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM,
        conversationId: this.conversationId
      }
      const messages = await ChatRepo.getMessageListByRefers([refer])
      if (messages && messages.length > 0) {
        this.topMessage = new NIMMessageInfo(messages[0])
      } else {
        // 消息已被删除，隐藏横幅
        this.topMessage = undefined
      }
    } catch (_e) {
      ChatKitClient.logger?.debug('getTopStickyMessage error')
      this.topMessage = undefined
    }
  }

  /**
   * 添加置顶消息
   * @param message 要置顶的消息
   */
  async addStickyMessage(message: NIMMessageInfo): Promise<void> {
    const team = this.chatTeamInfo?.team
    if (!team) {
      return
    }
    if (ChatKitClient.connectBroken()) {
      this.showTopStickyNetworkError()
      return
    }

    const topMsg = new TopStickyMessage()
    topMsg.idClient = message.message.messageClientId
    topMsg.scene = 1 // 群聊
    topMsg.from = message.message.senderId
    topMsg.to = this.conversationId
    topMsg.idServer = message.message.messageServerId
    topMsg.time = message.message.createTime
    topMsg.operator = ChatKitClient.getLoginUserId()
    topMsg.operation = typeExtensionStickyAdd
    topMsg.receiverId = this.targetId

    let extension = team.serverExtension ?? '{}'
    try {
      const extObj = JSON.parse(extension) as Record<string, Object>
      extObj[keyExtensionSticky] = topMsg.toJson()
      extObj[keyExtensionLastOptType] = keyExtensionSticky
      extension = JSON.stringify(extObj)
    } catch (_e) {
      const jsonObj: Record<string, Object> = {}
      jsonObj[keyExtensionSticky] = topMsg.toJson()
      jsonObj[keyExtensionLastOptType] = keyExtensionSticky
      extension = JSON.stringify(jsonObj)
    }

    const param: V2NIMUpdateTeamInfoParams = {
      serverExtension: extension
    }
    try {
      await TeamRepo.updateTeamInfo(team.teamId, team.teamType, param)
    } catch (error) {
      this.handleTopStickyActionError(error as BusinessError)
    }
  }

  /**
   * 移除置顶消息
   */
  async removeStickyMessage(): Promise<void> {
    const team = this.chatTeamInfo?.team
    if (!team || !this.topMessage) {
      return
    }
    if (ChatKitClient.connectBroken()) {
      this.showTopStickyNetworkError()
      return
    }

    const topMsg = new TopStickyMessage()
    topMsg.idClient = this.topMessage.message.messageClientId
    topMsg.operator = ChatKitClient.getLoginUserId()
    topMsg.operation = typeExtensionStickyRemove

    let extension = team.serverExtension ?? '{}'
    try {
      const extObj = JSON.parse(extension) as Record<string, Object>
      extObj[keyExtensionSticky] = topMsg.toRemoveJson()
      extObj[keyExtensionLastOptType] = keyExtensionSticky
      extension = JSON.stringify(extObj)
    } catch (_e) {
      const jsonObj: Record<string, Object> = {}
      jsonObj[keyExtensionSticky] = topMsg.toRemoveJson()
      jsonObj[keyExtensionLastOptType] = keyExtensionSticky
      extension = JSON.stringify(jsonObj)
    }

    const param: V2NIMUpdateTeamInfoParams = {
      serverExtension: extension
    }
    try {
      await TeamRepo.updateTeamInfo(team.teamId, team.teamType, param)
    } catch (error) {
      this.handleTopStickyActionError(error as BusinessError)
    }
  }

  private handleTopStickyActionError(error: BusinessError): void {
    if (ChatKitClient.connectBroken() || error.code === V2NIMErrorCode.V2NIM_ERROR_CODE_ILLEGAL_STATE) {
      this.showTopStickyNetworkError()
      return
    }
    ErrorUtils.handleErrorToast(error.code)
  }

  private showTopStickyNetworkError(): void {
    NECommonUtils.showToast($r('app.string.chat_network_error_tips'))
  }

  /**
   * 处理置顶权限变更（当 lastOpt == "yxAllowTop" 时触发）
   */
  handleTopMessagePermission(serverExtension: string): void {
    try {
      const ext = JSON.parse(serverExtension) as object
      const lastOpt = ext?.[keyExtensionLastOptType] as string
      if (lastOpt === keyExtensionTopSticky) {
        this.updateTopPermission()
      }
    } catch (_e) {
      // ignore
    }
  }

  /**
   * 更新当前用户的置顶权限状态
   */
  private updateTopPermission(): void {
    this.hasTopPermission = havePermissionForTopSticky(
      this.chatTeamInfo?.team,
      this.chatTeamInfo?.getCurrentUserTeamMember()?.memberRole
    )
  }

  onDestroy(): void {
    this.teamSessionId += 1
    super.onDestroy()
    ChatRepo.offDeleteMessage(this.onTopMessageDeleteFun)
    ChatRepo.offRevokeMessage(this.onTopMessageRevokeFun)
    this.eventDisposers.dispose()

    if (ChatKitConfig.messageReadState) {
      ChatRepo.offReceiveTeamMessageReadReceipts(this.onReceiveMessageReadReceiptFun)
    }
  }
}
