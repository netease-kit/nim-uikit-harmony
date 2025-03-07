/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  ChatKitClient,
  ChatRepo,
  ContactRepo,
  ConversationRepo,
  IMKitConfigCenter,
  LocalConversationRepo,
  SettingRepo
} from '@nimkit/chatkit';
import {
  V2NIMFriend,
  V2NIMFriendDeletionType,
  V2NIMMessage,
  V2NIMP2PMessageMuteMode,
  V2NIMP2PMessageReadReceipt,
  V2NIMUser
} from '@nimsdk/base';
import { ChatUserInfo } from '../model/ChatUserInfo';
import { ChatBaseViewModel } from './ChatBaseViewModel';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { ChatKitConfig } from '../ChatKitConfig';

@ObservedV2
export class ChatP2PViewModel extends ChatBaseViewModel {
  chatUserInfo: ChatUserInfo | undefined = undefined;
  //是否消息通知
  @Trace isMessageNotify: boolean = true
  //是否置顶
  @Trace isStickTop: boolean = false
  receiptMessage: NIMMessageInfo | undefined = undefined

  init(conversationId: string, chatInfo: ChatUserInfo): void {
    super.init(conversationId, chatInfo)
    this.chatUserInfo = chatInfo
    this.getConversationInfo()
    ChatRepo.onP2PMessageReadReceipts(this.onReceiveP2PMessageReadReceiptFun)
    ChatKitClient.nim.userService?.on('onUserProfileChanged', this.onUserProfileChangedFun)
    ChatKitClient.nim.friendService?.on('onFriendInfoChanged', this.onFriendInfoChangedFun)
    ChatKitClient.nim.friendService?.on('onFriendDeleted',
      async (accountId: string, deletionType: V2NIMFriendDeletionType) => {
        this.onFriendInfoDeleteFun(accountId)
      })
  }

  onReceiveP2PMessageReadReceiptFun = (readReceipts: V2NIMP2PMessageReadReceipt[]) => {
    let receipt: V2NIMP2PMessageReadReceipt = readReceipts[0]
    readReceipts.forEach((item, index, readReceipts) => {
      console.debug('netease onReceiveP2PMessageReadReceiptFun item:', item.timestamp, ',index:', index)
      if (item.timestamp > receipt.timestamp) {
        receipt = item
      }
    })
    this.chatUserInfo?.setMessageReadReceipt(receipt)
  }
  onUserProfileChangedFun = (user: V2NIMUser[]) => {
    user.forEach((item) => {
      if (item.accountId == this.chatUserInfo?.currentUser?.accountId) {
        this.chatUserInfo?.setCurrentUser(item)
      } else if (item.accountId == this.chatUserInfo?.chatUser?.accountId) {
        this.chatUserInfo?.setChatUser(item)
      }
    })
  }
  onFriendInfoChangedFun = (friendInfo: V2NIMFriend) => {
    if (friendInfo.accountId == this.chatUserInfo?.targetId) {
      this.chatUserInfo?.updateConversationName()
      this.chatUserInfo?.setChatFriend(friendInfo)
    }
  }
  onFriendInfoDeleteFun = (accountId: String) => {
    if (accountId == this.chatUserInfo?.targetId) {
      this.chatUserInfo?.updateConversationName()
      this.chatUserInfo?.setChatFriend(undefined)
    }
  }

  loadData() {
    this.getMessageList()
    this.getUserInfo()
    this.getMessageReceipt()
    this.getPinList()
  }

  reloadMessageList() {
    this.getMessageList()
    this.setAnchorMessage(undefined)
    this.hasNew = false
  }

  toHandleReceiveMessage(messages: NIMMessageInfo[]): void {
    this.toHandleReceiptMessage(messages)
  }

  toHandleQueryMessage(messages: NIMMessageInfo[], originMsg: V2NIMMessage[]): void {
    this.toHandleReceiptMessage(messages)
  }

  toHandleDataSyncFinished(): void {
    this.getUserInfo()
    this.getPinList()
    this.getMessageReceipt()
  }

  toHandleReceiptMessage(messages: NIMMessageInfo[]) {
    // 发送已读回执
    let receiveMsg: NIMMessageInfo | undefined = undefined
    // 如果已读回执消息，大于当前列表中最后一条消息，则发送已读回执
    if (this.receiptMessage !== undefined &&
      this.receiptMessage.getCreateTime() > messages[messages.length - 1].getCreateTime()) {
      return
    }
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isReceiveMessage()) {
        receiveMsg = messages[i]
        break
      }
    }
    if (this.receiptMessage == undefined || this.receiptMessage.getCreateTime() < (receiveMsg?.getCreateTime() ?? 0)) {
      this.sendMessageReceipt(receiveMsg)
      this.receiptMessage = receiveMsg
    }
  }

  async getUserInfo() {
    const userList = await ContactRepo.getUserList([this.targetId, ChatKitClient.getLoginUserId()]);
    if (userList.length > 1) {
      let currentUser = userList[0].accountId == this.targetId ? userList[1] : userList[0];
      let chatUser = userList[0].accountId == this.targetId ? userList[0] : userList[1];
      this.chatUserInfo?.setCurrentUser(currentUser);
      this.chatUserInfo?.setChatUser(chatUser);
    } else if (userList.length == 1) {
      let currentUser = userList[0].accountId == this.targetId ? undefined : userList[0];
      let chatUser = userList[0].accountId == this.targetId ? userList[0] : undefined;
      this.chatUserInfo?.setCurrentUser(currentUser);
      this.chatUserInfo?.setChatUser(chatUser);
    }
  }

  /**
   * 获取是否置顶和通知
   */
  getConversationInfo() {
    if (IMKitConfigCenter.enableLocalConversation) {
      LocalConversationRepo.getConversation(this.conversationId).then((conversation) => {
        this.isStickTop = conversation?.stickTop ?? false
        this.isMessageNotify = !(conversation?.mute ?? false)
      })
    } else {
      ConversationRepo.getConversation(this.conversationId).then((conversation) => {
        this.isStickTop = conversation?.stickTop ?? false
        this.isMessageNotify = !(conversation?.mute ?? false)
      })
    }

  }

  /**
   * 置顶或者取消置顶会话
   * @param stickTop 是否置顶
   */
  async stickTopConversation(stickTop: boolean) {
    try {
      if (IMKitConfigCenter.enableLocalConversation) {
        await LocalConversationRepo.stickTopConversation(this.conversationId, stickTop)
      } else {
        await ConversationRepo.stickTopConversation(this.conversationId, stickTop)
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
  async setP2PNotify(isOn: boolean) {
    try {
      await SettingRepo.setP2PMessageMuteMode(this.targetId,
        isOn ? V2NIMP2PMessageMuteMode.V2NIM_P2P_MESSAGE_MUTE_MODE_OFF :
        V2NIMP2PMessageMuteMode.V2NIM_P2P_MESSAGE_MUTE_MODE_ON)
      this.isMessageNotify = isOn
    } catch (e) {
      this.isMessageNotify = !isOn
    }
  }

  /**
   * 获取消息已读未读状态
   */
  async getMessageReceipt() {
    if (ChatKitConfig.messageReadState) {
      ChatRepo.getP2PMessageReceipt(this.conversationId).then((receipt) => {
        this.chatUserInfo?.setMessageReadReceipt(receipt)
      })
    }
  }

  /**
   * 发送消息已读回执
   * @param message
   */
  sendMessageReceipt(msg: NIMMessageInfo | undefined): void {
    if (msg && ChatKitConfig.messageReadState) {
      ChatRepo.sendP2PMessageReceipt(msg.message)
    }
  }

  /**
   * 退出页面，清理
   */
  onDestroy() {
    super.onDestroy()
    ChatRepo.offP2PMessageReadReceipts(this.onReceiveP2PMessageReadReceiptFun)
    ChatKitClient.nim.userService?.off('onUserProfileChanged', this.onUserProfileChangedFun)
    ChatKitClient.nim.friendService?.off('onFriendInfoChanged', this.onFriendInfoChangedFun)
    ChatKitClient.nim.friendService?.off('onFriendDeleted', this.onFriendInfoDeleteFun)
  }
}