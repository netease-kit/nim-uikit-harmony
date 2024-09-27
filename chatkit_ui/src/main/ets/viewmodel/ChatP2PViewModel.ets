/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ConversationRepo, SettingRepo } from '@nimkit/chatkit';
import { V2NIMP2PMessageMuteMode } from '@nimsdk/base';
import { ChatUserInfo } from '../model/ChatUserInfo';
import { ChatBaseViewModel } from './ChatBaseViewModel';

@ObservedV2
export class ChatP2PViewModel extends ChatBaseViewModel {
  chatUserInfo: ChatUserInfo | undefined = undefined;
  //是否消息通知
  @Trace isMessageNotify: boolean = true
  //是否置顶
  @Trace isStickTop: boolean = false

  init(conversationId: string, chatInfo: ChatUserInfo): void {
    super.init(conversationId, chatInfo);
    this.chatUserInfo = chatInfo;
    this.getConversationInfo()
  }

  async getUserInfo() {
    const userList = await ContactRepo.getUserList([this.accountId, ChatKitClient.getLoginUserId()]);
    if (userList.length > 1) {
      let currentUser = userList[0].accountId == this.accountId ? userList[1] : userList[0];
      let chatUser = userList[0].accountId == this.accountId ? userList[0] : userList[1];
      this.chatUserInfo?.setCurrentUser(currentUser);
      this.chatUserInfo?.setChatUser(chatUser);
    } else if (userList.length == 1) {
      let currentUser = userList[0].accountId == this.accountId ? undefined : userList[0];
      let chatUser = userList[0].accountId == this.accountId ? userList[0] : undefined;
      this.chatUserInfo?.setCurrentUser(currentUser);
      this.chatUserInfo?.setChatUser(chatUser);
    }
  }

  /**
   * 获取是否置顶和通知
   */
  getConversationInfo() {
    ConversationRepo.getConversation(this.conversationId).then((conversation) => {
      this.isStickTop = conversation?.stickTop ?? false
      this.isMessageNotify = !(conversation?.mute ?? false)
    })
  }

  /**
   * 置顶或者取消置顶会话
   * @param stickTop 是否置顶
   */
  async stickTopConversation(stickTop: boolean) {
    try {
      await ConversationRepo.stickTopConversation(this.conversationId, stickTop)
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
      await SettingRepo.setP2PMessageMuteMode(this.accountId,
        isOn ? V2NIMP2PMessageMuteMode.V2NIM_P2P_MESSAGE_MUTE_MODE_OFF :
        V2NIMP2PMessageMuteMode.V2NIM_P2P_MESSAGE_MUTE_MODE_ON)
      this.isMessageNotify = isOn
    } catch (e) {
      this.isMessageNotify = !isOn
    }

  }
}