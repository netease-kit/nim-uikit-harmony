/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  AitModel,
  ChatKitClient,
  ChatRepo,
  collectionTypeOffset,
  ConversationRepo,
  ErrorUtils,
  IMKitConfigCenter,
  LocalConversationRepo,
  StorageRepo,
  YxAitMsg
} from '@nimkit/chatkit';
import fs from '@ohos.file.fs';
import {
  V2NIMAIModelRoleType,
  V2NIMAIUser,
  V2NIMConnectStatus,
  V2NIMDataSyncState,
  V2NIMDataSyncType,
  V2NIMError,
  V2NIMErrorCode,
  V2NIMLoginStatus,
  V2NIMMessage,
  V2NIMMessageAIConfigParams,
  V2NIMMessageAIStatus,
  V2NIMMessageAIStreamStatus,
  V2NIMMessageConfig,
  V2NIMMessageDeletedNotification,
  V2NIMMessageFileAttachment,
  V2NIMMessagePinNotification,
  V2NIMMessagePinState,
  V2NIMMessageRevokeNotification,
  V2NIMMessageSendingState,
  V2NIMMessageType,
  V2NIMQueryDirection,
  V2NIMSendMessageParams
} from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { ChatInfo } from '../model/ChatInfo';
import { ChatConst } from '../constants/ChatConst';
import { BusinessError } from '@kit.BasicServicesKit';
import { DeviceUtils } from '../common/DeviceUtils';
import { image } from '@kit.ImageKit';
import {
  saveLocalRevokeMessage,
  saveLocalRevokeMessageFormOther
} from '@nimkit/chatkit/src/main/ets/utils/MessageUtils';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import { ChatKitConfig } from '../ChatKitConfig';
import { sceneMap } from '@kit.MapKit';
import { clearForwardAtMark, createForwardMessageListFileDetail, sendMessageFailedTips } from '../common/MessageHelper';
import { instanceToPlain } from 'class-transformer';
import { NECommonUtils } from '@nimkit/common';
import { HashMap, JSON } from '@kit.ArkTS';
import { assign } from '@nimsdk/vendor';

@ObservedV2
export class ChatBaseViewModel {
  @Trace static currentViewModel: ChatBaseViewModel | undefined = undefined
  @Trace anchorMsg: NIMMessageInfo | undefined = undefined
  @Trace conversationId: string = ""
  // p2p 会话是对方账号ID，群聊是为群ID teamId
  targetId: string = ""
  @Trace chatInfo: ChatInfo | undefined = undefined
  @Trace selectMsgMap: Map<string, NIMMessageInfo> = new Map()
  @Trace selectMsgCount = 0
  @Trace needScrollToBottom = false
  isLoading = false
  hasMore = false
  hasNew = false
  revokeMsg: NIMMessageInfo | undefined = undefined
  sendingMsgClientId: string = ''
  saveRevokeClientId: string = ''
  hasLoadData = false
  // 网络连接状态
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  // 流式 ing 缓存数据
  private streamingMessageMap: HashMap<string, StreamMessage> = new HashMap();
  // 发送消息
  onSendFun = async (message: V2NIMMessage): Promise<void> => {
    if (message.conversationId === this.conversationId) {
      if (message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
        if (message.messageClientId !== this.sendingMsgClientId) {
          this.sendingMsgClientId = message.messageClientId
          this.chatInfo?.pushMessage(message)
          this.chatInfo?.setReceiveMsg(true)
        }

      } else {
        let result = this.chatInfo?.updateMessageStatus(message)
        if (!result) {
          this.chatInfo?.setReceiveMsg(true)
        }
      }
    }
  }
  private msgDirection: number = 0

  setAnchorMessage(msg: NIMMessageInfo | undefined) {
    this.anchorMsg = msg
  }

  init(conversationId: string, chatInfo: ChatInfo) {
    this.conversationId = conversationId
    this.targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    this.chatInfo = chatInfo;
    // 设置当前会话
    ChatKitClient.setCurrentConversationId(this.conversationId)
    // 注册消息接受监听
    ChatRepo.onReceiverMessage(this.onReceiveFun)
    // 注册消息更新监听
    ChatRepo.onReceiveMessagesModified(this.onModifyFun)
    // 注册消息发送监听
    ChatRepo.onSendMessage(this.onSendFun)
    // 注册消息删除监听
    ChatRepo.onDeleteMessage(this.onDeleteFun)
    // 注册消息撤回监听
    ChatRepo.onRevokeMessage(this.onRevokeFun)
    // 注册消息置顶监听
    ChatRepo.onMessagePinNotification(this.onPinFun)

    // 监听数据同步完成监听
    ChatKitClient.nim.loginService.on('onDataSync', this.onSyncFinishedFun)
    // 长连接状态变更
    ChatKitClient.nim.loginService?.on('onConnectStatus', this.onConnectStatusChange)
    // 登录状态变更
    ChatKitClient.nim.loginService?.on('onLoginStatus', this.onLoginStatusChange)

    ChatBaseViewModel.currentViewModel = this
    // 清理未读数
    this.clearUnreadCount()
  }

  onConnectStatusChange = (status: V2NIMConnectStatus) => {
    if (status !== V2NIMConnectStatus.V2NIM_CONNECT_STATUS_CONNECTED) {
      this.networkBroken = true
    }
  }
  onLoginStatusChange = (status: V2NIMLoginStatus) => {
    if (status === V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED) {
      this.networkBroken = false
    }
  }
  // 处理数据同步完成
  onSyncFinishedFun = (type: V2NIMDataSyncType,
    state: V2NIMDataSyncState,
    error?: V2NIMError) => {
    if (state == V2NIMDataSyncState.V2NIM_DATA_SYNC_STATE_COMPLETED) {
      this.toHandleDataSyncFinished()
    }
  }
  // 接受消息
  onReceiveFun = (messages: V2NIMMessage[]) => {
    if (this.hasNew) {
      return
    }
    let hasNew = false
    let receiveMsg: NIMMessageInfo[] = [];
    for (let i = messages.length - 1; i >= 0; i--) {
      let msg = messages[i];
      if (msg.conversationId == this.conversationId) {
        let msgInfo = this.chatInfo?.pushMessage(msg);
        if (msgInfo !== undefined) {
          receiveMsg.push(msgInfo)
        }
        hasNew = true;
      }
    }
    if (hasNew) {
      this.toHandleReceiveMessage(receiveMsg)
      this.clearUnreadCount()
      this.chatInfo?.setReceiveMsg(true);
    }
  }
  // 更新消息
  onModifyFun = (messages: V2NIMMessage[]) => {
    for (let i = messages.length - 1; i >= 0; i--) {
      let message = messages[i];
      // 流式并且机器人回复消息，走流式展示逻辑
      if (message.aiConfig?.aiStream && message.aiConfig?.aiStatus === V2NIMMessageAIStatus.V2NIM_MESSAGE_AI_STATUS_RESPONSE) {
        this.onModifyFunStream(message)
      } else {
        this.onModifyFunNormal(message)
      }
    }
  }

  private onModifyFunNormal = (message: V2NIMMessage) => {
    if (this.hasNew) {
      return
    }
    let hasNew = false
    let receiveMsg: NIMMessageInfo[] = [];
    if (message.conversationId == this.conversationId) {
      let msgInfo = this.chatInfo?.pushModifyMessage(message);
      if (msgInfo !== undefined) {
        receiveMsg.push(msgInfo)
      }
      hasNew = true;
    }
    if (hasNew) {
      this.toHandleReceiveMessage(receiveMsg)
      // this.clearUnreadCount() // 更新消息不做 clear 动作
      this.chatInfo?.setReceiveMsg(true);
    }
  }

  private onModifyFunStream = async (message: V2NIMMessage) => {
    if (message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING) {
      // 检查新老情况
      const messageClientId: string = message.messageClientId
      const oldStreamMessage: StreamMessage | undefined = this.streamingMessageMap.get(messageClientId) // 老的
      const newStreamMessage: StreamMessage = new StreamMessage(message) // 新的
      this.streamingMessageMap.set(messageClientId, newStreamMessage) // 替换成新的

      // 准备裁切 message.text
      const oldLen = oldStreamMessage?.message?.text?.length ?? 0
      const newLen = newStreamMessage.message?.text?.length ?? 0
      const newStr: string = newStreamMessage.message?.text ?? ''
      const currentIndex: number = newStreamMessage.index

      // 开始裁切
      for (let i = oldLen; i < newLen; i++) {
        const latestStreaming: StreamMessage | undefined = this.streamingMessageMap.get(messageClientId)
        if (latestStreaming.finish || currentIndex !== latestStreaming.index) {
          break; // finish or index 已经发生了变化，不再更新
        }
        const tmpMessage: V2NIMMessage = assign({}, message)
        const tmpStr: string = newStr.substring(0, i + 1);
        tmpMessage.text = tmpStr
        this.onModifyFunNormal(tmpMessage) // 循环 modify
        // 阻塞 20ms，避免循环过快而回调过快
        await new Promise<void>(resolve => {
          setTimeout(resolve, 20); // 例如，这里设置一个 20 毫秒的延迟。还有优化空间
        });
      }
    } else {
      if (message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STOPPED ||
        message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_UPDATED ||
        message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_GENERATED ||
        message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_ABORTED) {
        // finish
        const oldStreaming = this.streamingMessageMap.get(message.messageClientId)
        if (oldStreaming) {
          oldStreaming.finish = true
        } else {
          this.streamingMessageMap.set(message.messageClientId, new StreamMessage(message)) // finished message
        }
      }
      this.onModifyFunNormal(message) // 直接 modify
    }
  }

  // 删除消息
  onDeleteFun = (messages: V2NIMMessageDeletedNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId === this.conversationId) {
        this.removeReplyInfo(msg.messageRefer.messageClientId)
        this.chatInfo?.deleteMessage(msg.messageRefer.messageClientId)
        if (this.selectMsgMap.has(msg.messageRefer.messageClientId)) {
          this.selectMsgMap.delete(msg.messageRefer.messageClientId)
          this.selectMsgCount = this.selectMsgMap.size
        }
      }
    })
    // 等待 1 秒，然后重新拉取一次消息
    if ((this.chatInfo?.msgList.totalCount() ?? 0) <= 0) {
      setTimeout(() => {
        this.getMessageList() // 被删完了消息之后，防止消息空了，重新拉取
      },  1000)
    }
  }
  // 撤回消息
  onRevokeFun = (messages: V2NIMMessageRevokeNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId === this.conversationId) {
        let revokeMsg = this.chatInfo?.getMessage(msg.messageRefer.messageClientId)
        this.removeReplyInfo(msg.messageRefer.messageClientId)
        this.chatInfo?.revokeMessage(msg.messageRefer.messageClientId)
        if (this.selectMsgMap.has(msg.messageRefer.messageClientId)) {
          this.selectMsgMap.delete(msg.messageRefer.messageClientId)
          this.selectMsgCount = this.selectMsgMap.size
        }
        if (this.saveRevokeClientId == revokeMsg?.message.messageServerId) {
          return
        }
        this.saveRevokeClientId = revokeMsg?.message.messageServerId ?? ''
        console.debug('netease viewmodel onRevokeFun revoke message', msg.revokeAccountId,
          msg.messageRefer.messageClientId)
        if (revokeMsg !== undefined && msg.messageRefer.senderId == ChatKitClient.getLoginUserId()) {
          let canEdit =
            !revokeMsg.isReceiveMsg && revokeMsg.message.messageType == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT
          saveLocalRevokeMessage(msg.messageRefer.conversationId, revokeMsg.message, canEdit)
        } else {
          saveLocalRevokeMessageFormOther(msg.messageRefer.conversationId, msg, false)
        }
      }
    })
  }
  // 置顶消息
  onPinFun = ((notification: V2NIMMessagePinNotification) => {
    if (notification.pinState == V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_PINNED) {
      this.chatInfo?.addPinMessage([notification.pin])
      this.needScrollToBottom = true

    } else if (notification.pinState == V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_UPDATED) {
      this.chatInfo?.addPinMessage([notification.pin])
      this.needScrollToBottom = true

    } else if (notification.pinState == V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_NOT_PINNED) {
      this.chatInfo?.removePinMessage([notification.pin])
    }

  })

  loadAnchorMsg(msg: NIMMessageInfo) {
    this.loadMessageListWithAnchor(msg)
  }

  // 拉取历史消息
  async getMessageList(): Promise<NIMMessageInfo[]> {
    let hasError = false
    const messageList: V2NIMMessage[] = await ChatRepo.getMessageList({
      'conversationId': this.conversationId,
      'limit': ChatConst.chatMessagePageSize,
      'direction': this.msgDirection,
      'onlyQueryLocal': false,
      'strictMode': true
    }).catch((err: BusinessError) => {
      hasError = true
      return []
    })
    let result: NIMMessageInfo[] = [];
    if (hasError) {
      return result
    }
    // 拉回的消息数据存在误差
    if (messageList.length >= ChatConst.chatMessagePageSize - 10) {
      this.hasMore = true;
    } else {
      this.hasMore = false;
    }
    this.chatInfo?.cleanMessage()
    this.setAnchorMessage(undefined)
    for (let index = messageList.length - 1; index >= 0; index--) {
      let msgInfo = this.chatInfo?.pushMessage(messageList[index]);
      if (msgInfo != undefined) {
        result.push(msgInfo);
      }
    }
    // 修改接受消息标志，如果有新消息则更新接受消息标志，否则列表滚动到底部
    this.chatInfo?.setReceiveMsg(true)
    this.toHandleQueryMessage(result, messageList)
    this.hasLoadData = true
    return result;
  }

  async loadMessageListWithAnchor(anchorMsg: NIMMessageInfo): Promise<NIMMessageInfo[]> {
    let errorCount = 0
    let result: NIMMessageInfo[] = [];
    const messageBeforList: V2NIMMessage[] = await ChatRepo.getMessageList({
      'conversationId': this.conversationId,
      'anchorMessage': anchorMsg.message,
      'limit': ChatConst.chatMessagePageSize,
      'direction': V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC
    }).catch((err: BusinessError) => {
      errorCount++
      return []
    })
    const messageAfterList: V2NIMMessage[] = await ChatRepo.getMessageList({
      'conversationId': this.conversationId,
      'anchorMessage': anchorMsg.message,
      'limit': ChatConst.chatMessagePageSize,
      'direction': V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
    }).catch((err: BusinessError) => {
      errorCount++
      return []
    })
    if (errorCount > 1) {
      return result
    }
    this.chatInfo?.cleanMessage()
    if (messageBeforList.length > 0) {
      for (let index = messageBeforList.length - 1; index >= 0; index--) {
        let msgInfo = this.chatInfo?.pushMessage(messageBeforList[index])
        if (msgInfo != undefined) {
          result.push(msgInfo);
        }
      }
    }
    this.chatInfo?.pushMessageInfo(anchorMsg)
    let anchorIndex = this.chatInfo?.msgList.totalCount() ?? 1 - 1
    if (messageAfterList.length > 0) {
      for (let index = 0; index < messageAfterList.length; index++) {
        let msgInfo = this.chatInfo?.pushMessage(messageAfterList[index])
        if (msgInfo != undefined) {
          result.push(msgInfo);
        }
      }
    }
    if (messageAfterList.length > ChatConst.chatMessagePageSize - 5 || this.networkBroken) {
      this.hasNew = true
    } else if (!this.networkBroken) {
      this.hasNew = false;
    }
    // // 修改接受消息标志，如果有新消息则更新接受消息标志，否则列表滚动到底部
    // this.chatInfo?.setReceiveMsg(true)
    this.toHandleQueryMessage(result, messageAfterList)
    if (anchorIndex) {
      this.chatInfo?.setScrollIndex(anchorIndex)
    }
    this.hasLoadData = true
    return result;
  }

  // 处理接受消息，用于子类进行特殊业务处理
  toHandleReceiveMessage(messages: NIMMessageInfo[]) {

  }

  // 处理查询消息，用于子类进行特殊业务处理
  toHandleQueryMessage(messages: NIMMessageInfo[], originMsg: V2NIMMessage[]) {

  }

  toHandleDataSyncFinished() {

  }

  // 是否有更多消息，分页加载
  canLoadMore(): boolean {
    return this.hasMore && !this.isLoading;
  }

  // 是否有更多新消息加载，分页加载
  canLoadNext(end: number): boolean {
    return this.hasNew && !this.isLoading && this.chatInfo !== undefined &&
      this.chatInfo.msgList.totalCount() - end < ChatConst.chatMessagePageSize
  }

  // 拉取历史消息
  async getMoreMessageList(): Promise<NIMMessageInfo[]> {
    let anchorMsg = this.chatInfo?.msgList.getData(0)
    if (this.isLoading || anchorMsg == undefined) {
      return []
    }
    this.isLoading = true;
    let result: NIMMessageInfo[] = [];
    await ChatRepo.getMessageList({
      "anchorMessage": anchorMsg.message,
      "conversationId": this.conversationId,
      "limit": ChatConst.chatMessagePageSize,
      "direction": this.msgDirection,
    }).then((messageList: V2NIMMessage[]) => {
      // SDK 返回消息不太稳定，所以按照更小的值判断是否有下一页
      if (messageList.length >= ChatConst.chatMessagePageSize - 5 || this.networkBroken) {
        this.hasMore = true
      } else {
        this.hasMore = false
      }
      if (this.chatInfo) {
        result = this.chatInfo.unshiftMessage(messageList)
      }
      this.toHandleQueryMessage(result, messageList)
      this.isLoading = false
    }).catch((err: BusinessError) => {
      this.isLoading = false
      if (this.networkBroken) {
        this.hasMore = true
      }
    })
    return result
  }

  // 拉取历史消息
  async getNewMessageList(): Promise<NIMMessageInfo[]> {
    if (this.isLoading || !this.hasNew) {
      return []
    }
    let anchorMsg = this.chatInfo?.msgList.getData(this.chatInfo?.msgList.totalCount() - 1)
    if (anchorMsg == undefined) {
      return []
    }
    this.isLoading = true;
    let result: NIMMessageInfo[] = [];
    await ChatRepo.getMessageList({
      "anchorMessage": anchorMsg.message,
      "conversationId": this.conversationId,
      "limit": ChatConst.chatMessagePageSize,
      "direction": V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC,
    }).then((messageList: V2NIMMessage[]) => {
      // SDK 返回消息不太稳定，所以按照更小的值判断是否有下一页
      if (messageList.length >= ChatConst.chatMessagePageSize - 10 || this.networkBroken) {
        this.hasNew = true
      } else {
        this.hasNew = false
      }
      console.debug('netease getNewMessageList,lenght:', messageList.length, 'hasNew:', this.hasNew)

      if (this.chatInfo) {
        for (let index = 0; index < messageList.length; index++) {
          let msgInfo = this.chatInfo.pushMessage(messageList[index])
          result.push(msgInfo)
        }
      }
      this.toHandleQueryMessage(result, messageList)
      this.isLoading = false
    }).catch((err: BusinessError) => {
      this.isLoading = false
      if (this.networkBroken) {
        this.hasNew = true
      } else {
        this.hasNew = false
      }
    })
    return result
  }

  // 拉取PIN信息
  getPinList() {
    ChatRepo.getPinnedMessageList(this.conversationId).then((pinMessageList) => {
      this.chatInfo?.resetPinMessage(pinMessageList)
      this.needScrollToBottom = true
    })
  }

  // 删除消息
  deleteMessage(messages: NIMMessageInfo[]) {
    for (const message of messages) {
      ChatRepo.deleteMessage(message.message, undefined, false).then(() => {
        this.removeReplyInfo(message.message.messageClientId)
      }).catch((err: BusinessError) => {
        ErrorUtils.handleErrorToast(err.code)
      });
    }
  }

  // 批量删除消息
  deleteMessageList(messages: NIMMessageInfo[]) {
    let msgList: V2NIMMessage[] = []
    messages.forEach((msg, index, messages) => {
      msgList.push(msg.message)
    })

    ChatRepo.deleteMessages(msgList, undefined, false).then(() => {
      messages.forEach((msg) => {
        this.removeReplyInfo(msg.message.messageClientId)
      })
    }).catch((err: BusinessError) => {
      ErrorUtils.handleErrorToast(err.code)
    });
  }

  // 撤回消息
  revokeMessage(msg: NIMMessageInfo) {
    ChatRepo.revokeMessage(msg.message).then(() => {
      if (msg.isPinMsg && msg.pinInfo) {
        ChatRepo.unpinMessage(msg.pinInfo?.messageRefer)
      }
      this.removeReplyInfo(msg.message.messageClientId)
    }).catch((err: BusinessError) => {
      ErrorUtils.handleErrorToast(err.code)
      console.error(`netease Invoke startAbility failed, code is ${err.code}, message is ${err.message}`);
    });
  }

  /// 移除被回复信息
  removeReplyInfo(invalidMessageClientId: string) {
    const invalidMessage = this.chatInfo?.getMessage(invalidMessageClientId)
    if (invalidMessage) {
      const invalidIndex = this.chatInfo?.msgList.getMessageList().indexOf(invalidMessage)
      if (invalidIndex) {
        for (let index = invalidIndex; index < (this.chatInfo?.msgList.totalCount() ?? invalidIndex); index++) {
          let message = this.chatInfo?.msgList.getMessageList()[index]
          if (message && message.replyMsg?.message.messageClientId === invalidMessage.message.messageClientId) {
            message.replyMsg = undefined
          }
        }
      }
    }
  }

  // 收藏消息
  collectionMessage(msg: NIMMessageInfo) {
    if (ErrorUtils.checkNetworkAndToast()) {
      let collectionDic: Record<string, Object> = {}
      let message = msg.message
      clearForwardAtMark(message)
      const messageString = ChatKitClient.nim.messageConverter.messageSerialization(message)
      if (messageString) {
        collectionDic["message"] = messageString
      }

      collectionDic['conversationName'] = this.chatInfo?.conversationName ?? ''
      collectionDic['senderName'] = this.chatInfo?.getChatUserShowName(message) ?? ''
      collectionDic['avatar'] = this.chatInfo?.getChatUserAvatarUrl(message) ?? ''

      const collectionData = JSON.stringify(collectionDic)

      ChatRepo.addCollection({
        collectionType: message.messageType.valueOf() + collectionTypeOffset,
        collectionData: collectionData,
        uniqueId: message.messageServerId
      }).catch((err: BusinessError) => {
        ErrorUtils.handleErrorToast(err.code)
      }).finally(() => {
        NECommonUtils.showToast($r('app.string.chat_collection_success'))
      })
    }
  }

  // PIN消息
  pinMessage(msg: NIMMessageInfo) {
    if (ErrorUtils.checkNetworkAndToast()) {
      ChatRepo.pinMessage(msg.message).catch((err: BusinessError) => {
        if (err.code == V2NIMErrorCode.V2NIM_ERROR_CODE_PIN_ALREADY_EXIST) {
          return
        }
        ErrorUtils.handleErrorToast(err.code)
      })
    }
  }

  unpinMessage(msg: NIMMessageInfo) {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (msg.isPinMsg) {
        if (msg.pinInfo?.messageRefer !== undefined) {
          ChatRepo.unpinMessage(msg.pinInfo?.messageRefer).catch((err: BusinessError) => {
            if (err.code == V2NIMErrorCode.V2NIM_ERROR_CODE_PIN_NOT_EXIST) {
              return
            }
            ErrorUtils.handleErrorToast(err.code)
          })
        }
      }
    }
  }

  // 清理未读数
  clearUnreadCount() {
    if (IMKitConfigCenter.enableLocalConversation) {
      LocalConversationRepo.clearUnreadCountByIds([this.conversationId])
    } else {
      ConversationRepo.clearUnreadCountByIds([this.conversationId])
    }
  }

  // 消息发送之前调用，用于配置消息通用参数
  beforeSendMessage(msg: V2NIMMessage): V2NIMMessage {
    if (ChatKitConfig.messageReadState) {
      let msgConfig: V2NIMMessageConfig = {
        readReceiptEnabled: true
      }
      msg.messageConfig = msgConfig
    }
    return msg
  }

  // 发送消息并设置发送进度
  sendMessageAndSetProgress(message: V2NIMMessage) {
    this.sendMessage(this.beforeSendMessage(message), undefined, (percentage: number) => {
      let msgInfo = this.chatInfo?.getMessage(message.messageClientId)
      if (msgInfo) {
        let progress = percentage * 100
        msgInfo.setDownloadProgress(progress)
        if (progress >= 100) {
          msgInfo.setDownloadProgress(-1)
        }
      }
    });
  }

  // 发送文本消息
  async sendTextMessage(text: string, replyMsg?: NIMMessageInfo, aitModel?: AitModel, pushList?: string[]) {
    const message = ChatRepo.createTextMessage(text)
    //设置Ait
    if (aitModel && aitModel.aitBlocks.size > 0) {
      let extensionMap: YxAitMsg = {
        yxAitMsg: aitModel.aitBlocks
      }
      let extension = JSON.stringify(instanceToPlain(extensionMap))
      message.serverExtension = extension
    }

    //设置推送
    let params: V2NIMSendMessageParams | undefined = undefined
    if (pushList) {
      params = {
        pushConfig: {
          forcePush: true,
          forcePushAccountIds: pushList.length >= 0 ? pushList : undefined
        }
      }
    }

    // 回复
    if (replyMsg) {
      this.replyMessage(message, replyMsg.message, params)
      return
    }

    // 设置 AI 配置
    const enableAIStream: boolean = false
    if (enableAIStream) {
      const text: string = message.text ?? '你是谁'
      const aiUsers: V2NIMAIUser[] = await ChatKitClient.nim.aiService!.getAIUserList()
      const ollamaaitest20AIUser: V2NIMAIUser | undefined =
        aiUsers.find((aiUser) => aiUser.accountId === 'ollamaaitest9')

      const aiParams: V2NIMMessageAIConfigParams = {
        accountId: ollamaaitest20AIUser ? ollamaaitest20AIUser.accountId : (aiUsers.length > 0 ? aiUsers[0].accountId : ''),
        content: {
          msg: text,
          type: 0
        },
        messages: [
          {
            role: V2NIMAIModelRoleType.V2NIM_AI_MODEL_ROLE_TYPE_ASSISTANT,
            msg: text,
            type: 0
          }
        ],
        promptVariables: undefined,
        modelConfigParams: {
          prompt: undefined,
          maxTokens: undefined,
          topP: undefined,
          temperature: undefined
        },
        aiStream: true // open aiStream
      }

      if (typeof params === 'undefined') {
        params = {}
      }
      params.aiConfig = aiParams
    }
    this.sendMessage(message, params)
  }

  // 发送位置消息
  async sendLocationMessage(data: sceneMap.LocationChoosingResult) {
    const message = ChatRepo.createLocationMessage(data.location.latitude, data.location.longitude, data.address)
    message.text = data.name
    this.sendMessage(message)
  }

  /**
   * 发送图片消息
   * @param uri 本地图片地址
   */
  async sendImageMessage(uri: string) {
    try {
      if (uri.length > 0) {
        let fileType = ""
        const subStrings = uri.split(".");
        if (subStrings.length > 0) {
          fileType = subStrings[subStrings.length - 1];
        }
        // 将文件 拷贝到 临时目录
        const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
        // （以时间戳）生成一个新的文件名
        const fileName = Date.now() + '.' + fileType
        // 通过缓存路径+文件名 拼接出完整的路径
        let fileDir = DeviceUtils.rootDirPath + '/temp/'
        const copyFilePath = fileDir + fileName
        if (!fs.accessSync(fileDir)) {
          await fs.mkdir(fileDir)
        }
        await fs.copyFile(file.fd, copyFilePath)
        const imageSource = image.createImageSource(file.fd);
        let imageInfo = imageSource.getImageInfoSync()
        const message = await ChatRepo.createImageMessage(copyFilePath, file.name, undefined, imageInfo?.size.width,
          imageInfo?.size.height);
        const fn: Function = () => {
          this.sendMessageAndSetProgress(message)
        }
        ChatKitClient.runAfterLoggedIn(fn)

        await fs.close(file)
      }
    } catch (err) {
      console.log("net ease send image error", err);
    }
  }

  /**
   * 发送视频消息
   * @param uri 本地视频地址
   * @param duration 视频时长
   * @param width 视频宽度
   * @param height 视频高度
   */
  async sendVideoMessage(uri: string, duration?: number, width?: number, height?: number, thumbnail?: PixelMap) {
    try {
      let fileType = ""
      const subStrings = uri.split(".");
      if (subStrings.length > 0) {
        fileType = subStrings[subStrings.length - 1];
      }
      // 将文件 拷贝到 临时目录
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      // （以时间戳）生成一个新的文件名
      const fileName = Date.now() + '.' + fileType
      // 通过缓存路径+文件名 拼接出完整的路径
      let fileDir = DeviceUtils.rootDirPath + '/temp/'
      const copyFilePath = fileDir + fileName
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      await fs.copyFile(file.fd, copyFilePath)
      const message = await ChatRepo.createVideoMessage(copyFilePath, file.name, undefined, duration, width, height);
      const fn: Function = () => {
        this.sendMessageAndSetProgress(message)
      }
      ChatKitClient.runAfterLoggedIn(fn)

      await fs.close(file)
    } catch (err) {
      console.log("net ease send video error", err);
    }
  }

  /**
   * 发送文件消息
   * @param uri 文件地址
   */
  async sendFileMessage(uri: string) {
    try {
      let fileType = ""
      const subStrings = uri.split(".");
      if (subStrings.length > 0) {
        fileType = subStrings[subStrings.length - 1];
      }
      // 将文件 拷贝到 临时目录
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      // （以时间戳）生成一个新的文件名
      const fileName = Date.now() + '.' + fileType
      // 通过缓存路径+文件名 拼接出完整的路径
      let fileDir = DeviceUtils.rootDirPath + '/temp/'
      const copyFilePath = fileDir + fileName
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      await fs.copyFile(file.fd, copyFilePath)
      const message = await ChatRepo.createFileMessage(copyFilePath, file.name);
      this.sendMessage(message, undefined, (percentage: number) => {
        let msgInfo = this.chatInfo?.getMessage(message.messageClientId)
        if (msgInfo !== undefined) {
          let progress = percentage * 100
          msgInfo.setDownloadProgress(progress)
          if (progress >= 100) {
            msgInfo.setDownloadProgress(-1)
          }
        }
      });

      await fs.close(file)
    } catch (err) {
      console.log("net ease send file error", err);
    }
  }

  /**
   * 发送语音消息
   * @param uri
   * @param duration 单位 s
   */
  async sendAudioMessage(uri: string, duration: number) {
    try {
      const message = await ChatRepo.createAudioMessage(uri, undefined, undefined, duration * 1000);
      this.sendMessage(message)
    } catch (err) {
      console.error("net ease send audio message error", err.code, err.message)
    }
  }

  /**
   * 发送消息
   * @param msg 消息
   * @param params 消息配置参数
   * @param progress 消息发送进度
   */
  async sendMessage(msg: V2NIMMessage, params?: V2NIMSendMessageParams, progress?: (percentage: number) => void) {
    ChatRepo.sendMessage(this.beforeSendMessage(msg), this.conversationId!, params, progress)
      .catch((err: BusinessError) => {
        console.error("net ease send message error", err.code, err.message);
        sendMessageFailedTips(msg, err, this.conversationId!)
      })
  }

  /**
   * 回复消息
   * @param msg 消息
   * @param replyMsg 被回复的消息
   * @param params 消息配置参数
   * @param progress 消息发送进度
   */
  async replyMessage(msg: V2NIMMessage, replyMsg: V2NIMMessage, params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void) {
    ChatRepo.replyMessage(this.beforeSendMessage(msg), replyMsg, params, progress)
      .catch((err: BusinessError) => {
        console.error("net ease reply message error", err.code, err.message);
        sendMessageFailedTips(msg, err, this.conversationId!)
      })
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
    ChatRepo.sendMessage(this.beforeSendMessage(msg), conversationId, params, progress)
      .catch((err: BusinessError) => {
        console.error("net ease send message error", err.code, err.message);
        sendMessageFailedTips(msg, err, conversationId)
      })
  }

  // 消息附件下载
  async downloadAttachment(msg: NIMMessageInfo, path: string) {
    if (msg.message.attachment as V2NIMMessageFileAttachment) {
      let fileAttachment = msg.message.attachment as V2NIMMessageFileAttachment;
      if (fileAttachment.url !== undefined) {
        msg.setDownloadProgress(1)
        try {
          await StorageRepo.downloadFile(fileAttachment.url, path, (progress: number) => {
            if (progress < 100) {
              this.chatInfo?.downloadProgressMap.set(msg.message.messageClientId, progress)
              msg.setDownloadProgress(progress)
            } else {
              if (progress == 100) {
                msg.setDownloadProgress(100)
              }
              msg.setDownloadProgress(-1)
              this.chatInfo?.downloadProgressMap.delete(msg.message.messageClientId)
            }
          }
          )
        } catch (err) {
          console.log('netease downloadAttachment', err)
          msg.setDownloadProgress(-1)
        }
      }
    }
  }

  /**
   * 【逐条转发】将多个消息转发到多个会话中，并将留言发送到多个会话中
   * @param messages 待转发的消息
   * @param conversationIds 待转发的会话
   * @param leaveText 留言
   */
  forwardMessage(messages: V2NIMMessage[], conversationIds: ConversationSelectModel[],
    leaveText: string | undefined) {

    if (ErrorUtils.checkNetworkAndToast()) {
      conversationIds.forEach((conversation) => {
        messages.forEach((message) => {
          const forwardMsg = ChatRepo.createForwardMessage(message)
          try {
            if (forwardMsg && conversation.conversationId) {
              clearForwardAtMark(forwardMsg)
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
              ChatRepo.sendMessage(this.beforeSendMessage(leaveMsg), conversation.conversationId!)
                .catch((err: BusinessError) => {
                  console.error("net ease send message error", err.code, err.message);
                  sendMessageFailedTips(leaveMsg, err, conversation.conversationId!)
                })
            }, 200)
          }
        }
      })
    }
  }

  /**
   * 将多个消息合并为一条自定义消息
   * @param messages 待合并的消息
   * @param depth 合并转发消息的深度
   */
  async mergeForwardMessage(messages: NIMMessageInfo[], depth: number): Promise<V2NIMMessage | undefined> {
    // 校验网络
    if (ErrorUtils.checkNetworkAndToast()) {
      // 排序（发送时间正序）
      let sortMessages = messages.sort((m1, m2) => {
        if (m1.message.createTime < m2.message.createTime) {
          return -1
        }
        if (m1.message.createTime > m2.message.createTime) {
          return 1
        }
        return 0
      })

      let rawMessages = sortMessages.map(msg => msg.message)
      if (this.chatInfo) {
        try {
          return await createForwardMessageListFileDetail(rawMessages, this.chatInfo, depth)
        } catch (err) {
          console.error(err)
        }
      }
    }

    return undefined
  }

  resendMessage(msgInfo: NIMMessageInfo) {
    //设置推送
    let params: V2NIMSendMessageParams | undefined = undefined
    let pushList = msgInfo.message.pushConfig?.forcePushAccountIds
    if (pushList) {
      params = {
        pushConfig: {
          forcePush: true,
          forcePushAccountIds: pushList.length >= 0 ? pushList : undefined
        }
      }
    }
    if (msgInfo.isReplyMsg && msgInfo.replyMsg && msgInfo.replyMsg.message) {
      this.replyMessage(msgInfo.message,msgInfo.replyMsg?.message,params)
    }else {
      this.sendMessage(msgInfo.message,params)
    }
  }

  // 多选数据，添加新的选中消息
  addSelectMessage(msg: NIMMessageInfo) {
    this.selectMsgMap.set(msg.getMessageClientId(), msg)
    this.chatInfo?.getMessage(msg.getMessageClientId())?.setSelected(true)
    this.selectMsgCount = this.selectMsgMap.size
  }

  // 多选数据，移除选中消息
  removeSelectMessage(msg: NIMMessageInfo) {
    this.selectMsgMap.delete(msg.getMessageClientId())
    this.chatInfo?.getMessage(msg.getMessageClientId())?.setSelected(false)
    this.selectMsgCount = this.selectMsgMap.size
  }

  // 多选数据，清空所有选中消息
  clearSelectMessage() {
    this.selectMsgMap.forEach((msg) => {
      this.chatInfo?.getMessage(msg.getMessageClientId())?.setSelected(false)
    })
    this.selectMsgMap.clear()
    this.selectMsgCount = this.selectMsgMap.size
  }

  // 获取多选数据
  getSelectMessageList(): NIMMessageInfo[] {
    return Array.from(this.selectMsgMap.values());
  }

  // 获取多选数据数量
  getSelectMessageSize(): number {
    return this.selectMsgMap.size;
  }

  isSelect(msgClientId: string) {
    let result = this.selectMsgMap.has(msgClientId)
    let msg = this.chatInfo?.getMessage(msgClientId)
    console.debug('netease isSelect', msgClientId, result, ',content:', msg?.message.text)
    return result
  }

  /**
   * 销毁
   */
  onDestroy(): void {
    ChatRepo.offReceiverMessage(this.onReceiveFun)
    ChatRepo.offReceiveMessagesModified(this.onModifyFun)
    ChatRepo.offSendMessage(this.onSendFun)
    ChatRepo.offDeleteMessage(this.onDeleteFun)
    ChatRepo.offRevokeMessage(this.onRevokeFun)
    ChatRepo.offMessagePinNotification(this.onPinFun)
    ChatKitClient.nim.loginService.off('onDataSync', this.onSyncFinishedFun)
    // 长连接状态变更
    ChatKitClient.nim.loginService?.off('onConnectStatus', this.onConnectStatusChange)
    // 登录状态变更
    ChatKitClient.nim.loginService?.off('onLoginStatus', this.onLoginStatusChange)
    // 清理未读数
    this.clearUnreadCount()
    ChatKitClient.clearCurrentConversationId()
  }
}


class StreamMessage {
  public message: V2NIMMessage
  public streamingArr: string[]
  public index: number
  public finish: boolean

  constructor(message: V2NIMMessage) {
    this.message = message
    this.streamingArr = []
    this.index = message.aiConfig?.aiStreamLastChunk?.index ?? 0
    if (message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING ||
      message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_PLACEHOLDER) {
      this.finish = false // streaming / placeholder 认为还没结束
    } else {
      this.finish = true
    }
  }
}