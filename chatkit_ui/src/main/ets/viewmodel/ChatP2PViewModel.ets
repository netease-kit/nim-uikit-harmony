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
  V2NIMConversationType,
  V2NIMCustomNotification,
  V2NIMFriend,
  V2NIMFriendDeletionType,
  V2NIMMessage,
  V2NIMP2PMessageMuteMode,
  V2NIMP2PMessageReadReceipt,
  V2NIMSendCustomNotificationParams,
  V2NIMUser
} from '@nimsdk/base';
import { ChatUserInfo } from '../model/ChatUserInfo';
import { ChatBaseViewModel } from './ChatBaseViewModel';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { ChatKitConfig } from '../ChatKitConfig';

// 正在输入状态通知内容常量（与 Android 端对齐）
const TYPING_CONTENT_START = '{"typing":1}'
const TYPING_CONTENT_STOP = '{"typing":0}'
// 正在输入状态超时时间（毫秒）
const TYPING_TIMEOUT_MS = 3000
// 发送"正在输入"通知的最小间隔（毫秒），用于节流
const TYPING_SEND_INTERVAL_MS = 2000

@ObservedV2
export class ChatP2PViewModel extends ChatBaseViewModel {
  chatUserInfo: ChatUserInfo | undefined = undefined;
  //是否消息通知
  @Trace isMessageNotify: boolean = true
  //是否置顶
  @Trace isStickTop: boolean = false
  receiptMessage: NIMMessageInfo | undefined = undefined
  // 对方是否正在输入（接收侧状态）
  @Trace isRemoteTyping: boolean = false
  // 正在输入状态超时定时器 ID
  private typingTimeoutId: number | undefined = undefined
  // 上一次发送"正在输入"通知的时间戳（用于节流）
  private lastTypingSentTime: number = 0

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
    // 注册自定义通知监听（用于接收对方的"正在输入"状态）
    if (IMKitConfigCenter.enableTypingStatus) {
      ChatRepo.onReceiveCustomNotifications(this.onReceiveCustomNotificationsFun)
    }
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
    if (this.hasLoadData && (this.chatInfo?.msgList.totalCount() ?? 0) === 0) {
      this.getMessageList()
    }
  }

  toHandleReceiptMessage(messages: NIMMessageInfo[]) {
    if (!messages || messages.length == 0) {
      return
    }
    // 只有在页面可见时才处理已读回执
    if (!this.isPageVisible) {
      return
    }
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
    // 只有在页面可见时才发送已读回执
    if (msg && ChatKitConfig.messageReadState && this.isPageVisible) {
      ChatRepo.sendP2PMessageReceipt(msg.message)
    }
  }

  /**
   * 接收自定义通知的回调函数（用于处理对方的"正在输入"状态）
   * 与 Android 端 V2NIMNotificationListener.onReceiveCustomNotifications 对齐
   */
  onReceiveCustomNotificationsFun = (notifications: V2NIMCustomNotification[]) => {
    if (!IMKitConfigCenter.enableTypingStatus) {
      return
    }
    for (const notification of notifications) {
      // 校验：仅处理 P2P 会话类型
      if (notification.conversationType !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        continue
      }
      // 校验：发送者是当前聊天对象
      if (notification.senderId !== this.targetId) {
        continue
      }
      // 解析 JSON 获取 typing 字段
      try {
        const typing: number = JSON.parse(notification.content || '{}')['typing']
        if (typing === 1) {
          this.setRemoteTyping(true)
        } else if (typing === 0) {
          this.setRemoteTyping(false)
        }
      } catch (e) {
        console.debug('netease onReceiveCustomNotificationsFun parse error:', e)
      }
    }
  }

  /**
   * 设置对方正在输入状态，并管理 3 秒超时定时器
   * @param isTyping 是否正在输入
   */
  private setRemoteTyping(isTyping: boolean): void {
    // 先清除旧的定时器
    if (this.typingTimeoutId !== undefined) {
      clearTimeout(this.typingTimeoutId)
      this.typingTimeoutId = undefined
    }
    this.isRemoteTyping = isTyping
    // 如果是正在输入，启动 3 秒超时定时器
    if (isTyping) {
      this.typingTimeoutId = setTimeout(() => {
        this.isRemoteTyping = false
        this.typingTimeoutId = undefined
      }, TYPING_TIMEOUT_MS)
    }
  }

  /**
   * 发送输入状态通知（发送侧）
   * 当输入框内容变化时调用，与 Android 端 ChatP2PViewModel.sendInputNotification 对齐
   * @param isTyping true 表示正在输入，false 表示停止输入
   */
  sendInputNotification(isTyping: boolean): void {
    // 检查开关
    if (!IMKitConfigCenter.enableTypingStatus) {
      return
    }

    const now = Date.now()

    if (isTyping) {
      // 正在输入：使用节流，每 2 秒最多发送一次，确保对方的 3 秒定时器能持续刷新
      if (now - this.lastTypingSentTime < TYPING_SEND_INTERVAL_MS) {
        return
      }
      this.lastTypingSentTime = now
    } else {
      // 停止输入：只有在之前发送过"正在输入"时才发送
      if (this.lastTypingSentTime === 0) {
        return
      }
      this.lastTypingSentTime = 0
    }

    const content = isTyping ? TYPING_CONTENT_START : TYPING_CONTENT_STOP
    // 配置：不推送、不计未读、不存离线、不路由（与 Android 端对齐）
    const params: V2NIMSendCustomNotificationParams = {
      notificationConfig: {
        offlineEnabled: false,
        unreadEnabled: false
      },
      pushConfig: {
        pushEnabled: false,
        pushNickEnabled: false,
        pushContent: '',
        pushPayload: '',
        forcePush: false,
        forcePushContent: '',
        forcePushAccountIds: []
      },
      routeConfig: {
        routeEnabled: false,
        routeEnvironment: ''
      }
    }
    ChatRepo.sendCustomNotification(this.conversationId, content, params)
      .catch((err: Error) => {
        console.debug('netease sendInputNotification error:', err)
      })
  }

  /**
   * 在会话中插入本地提示消息（仅本地可见，不发送到服务器）
   * @param tipResource 提示文本资源
   */
  insertLocalTipMessage(tipResource: Resource): void {
    const tipText: string = getContext(this).resourceManager.getStringSync(tipResource.id)
    const tipMessage: V2NIMMessage = ChatRepo.createTipsMessage(tipText)
    ChatRepo.insertMessageToLocal(tipMessage, this.conversationId)
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
    // 清理"正在输入"相关资源
    ChatRepo.offReceiveCustomNotifications(this.onReceiveCustomNotificationsFun)
    if (this.typingTimeoutId !== undefined) {
      clearTimeout(this.typingTimeoutId)
      this.typingTimeoutId = undefined
    }
    // 退出时发送停止输入通知
    if (this.lastTypingSentTime > 0) {
      this.sendInputNotification(false)
    }
  }
}
