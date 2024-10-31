/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ChatRepo, ConversationRepo, ErrorUtils, StorageRepo } from '@nimkit/chatkit';
import fs from '@ohos.file.fs';
import {
  V2NIMConnectStatus,
  V2NIMDataSyncState,
  V2NIMDataSyncType,
  V2NIMError,
  V2NIMErrorCode,
  V2NIMLoginStatus,
  V2NIMMessage,
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
import '../common/MessageHelper';
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

@ObservedV2
export class ChatBaseViewModel {
  @Trace static currentViewModel: ChatBaseViewModel | undefined = undefined
  @Trace anchorMsg: NIMMessageInfo | undefined = undefined
  @Trace conversationId: string = ""
  accountId: string = ""
  @Trace chatInfo: ChatInfo | undefined = undefined;
  isLoading = false
  hasMore = false
  hasNew = false
  revokeMsg: NIMMessageInfo | undefined = undefined
  sendingMsgClientId: string = ''
  saveRevokeClientId: string = ''
  hasLoadData = false
  // 网络连接状态
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  // 发送消息
  onSendFun = async (message: V2NIMMessage): Promise<void> => {
    if (message.conversationId === this.conversationId) {
      if (this.hasNew) {
        let result = await this.getMessageList()
      }
      if (message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
        if (message.messageClientId !== this.sendingMsgClientId) {
          this.sendingMsgClientId = message.messageClientId
          this.chatInfo?.pushMessage(message)
          this.chatInfo?.setReceiveMsg(true)
        }

      } else {
        this.chatInfo?.updateMessageStatus(message)
      }
    }
  }
  private msgDirection: number = 0

  setAnchorMessage(msg: NIMMessageInfo | undefined) {
    this.anchorMsg = msg
  }

  init(conversationId: string, chatInfo: ChatInfo) {
    this.conversationId = conversationId
    this.accountId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    this.chatInfo = chatInfo;
    // 设置当前会话
    ChatKitClient.setCurrentConversationId(this.conversationId)
    // 注册消息接受监听
    ChatRepo.onReceiverMessage(this.onReceiveFun)
    // 注册消息发送监听
    ChatRepo.onSendMessage(this.onSendFun)
    // 注册消息删除监听
    ChatRepo.onDeleteMessage(this.onDeleteFun)
    // 注册消息撤回监听
    ChatRepo.onRevokeMessage(this.onRevokeFun)
    // 注册消息置顶监听
    ChatRepo.onMessagePinNotification(this.onPinFun)
    // 清理未读数
    ConversationRepo.clearUnreadCountByIds([this.conversationId])
    // 监听数据同步完成监听
    ChatKitClient.nim.loginService.on('onDataSync', this.onSyncFinishedFun)
    // 长连接状态变更
    ChatKitClient.nim.loginService?.on('onConnectStatus', this.onConnectStatusChange)
    // 登录状态变更
    ChatKitClient.nim.loginService?.on('onLoginStatus', this.onLoginStatusChange)

    ChatBaseViewModel.currentViewModel = this
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
      this.chatInfo?.setReceiveMsg(true);
      this.toHandleReceiveMessage(receiveMsg)
      this.clearUnreadCount()
    }
  }
  // 删除消息
  onDeleteFun = (messages: V2NIMMessageDeletedNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId === this.conversationId) {
        this.chatInfo?.deleteMessage(msg.messageRefer.messageClientId)
      }
    })
  }
  // 撤回消息
  onRevokeFun = (messages: V2NIMMessageRevokeNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId === this.conversationId) {
        console.debug('netease viewmodel onRevokeFun revoke message', msg.revokeAccountId,
          msg.messageRefer.messageClientId)
        let revokeMsg = this.chatInfo?.getMessage(msg.messageRefer.messageClientId)
        this.chatInfo?.revokeMessage(msg.messageRefer.messageClientId)
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

    } else if (notification.pinState == V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_UPDATED) {
      this.chatInfo?.addPinMessage([notification.pin])

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
      'onlyQueryLocal': true
    }).catch((err: BusinessError) => {
      hasError = true
      return []
    })
    let result: NIMMessageInfo[] = [];
    if (hasError) {
      return result
    }
    if (messageList.length == ChatConst.chatMessagePageSize) {
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
    this.chatInfo?.msgList.push(anchorMsg)
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
    console.debug('netease loadMessageListWithAnchor,lenght:', messageAfterList.length, 'hasNew:', this.hasNew)
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
    })
  }

  // 删除消息
  deleteMessage(msg: NIMMessageInfo) {
    ChatRepo.deleteMessage(msg.message, undefined, false).catch((err: BusinessError) => {
      ErrorUtils.handleErrorToast(err.code)
    });
  }

  // 撤回消息
  revokeMessage(msg: NIMMessageInfo) {
    ChatRepo.revokeMessage(msg.message).then(() => {
      if (msg.isPinMsg && msg.pinInfo) {
        ChatRepo.unpinMessage(msg.pinInfo?.messageRefer)
      }
    }).catch((err: BusinessError) => {
      ErrorUtils.handleErrorToast(err.code)
      console.error(`netease Invoke startAbility failed, code is ${err.code}, message is ${err.message}`);
    });
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
    ConversationRepo.clearUnreadCountByIds([this.conversationId])
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
  async sendTextMessage(text: string) {
    const message = ChatRepo.createTextMessage(text)
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
        const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
        // （以时间戳）生成一个新的文件名
        const fileName = Date.now() + '.' + fileType
        // 通过缓存路径+文件名 拼接出完整的路径
        let fileDir = DeviceUtils.rootDirPath + '/temp/'
        const copyFilePath = fileDir + fileName
        if (!fs.accessSync(fileDir)) {
          await fs.mkdir(fileDir)
        }
        fs.copyFileSync(file.fd, copyFilePath)
        const imageSource = image.createImageSource(file.fd);
        let imageInfo = imageSource.getImageInfoSync()
        const message = await ChatRepo.createImageMessage(copyFilePath, file.name, undefined, imageInfo?.size.width,
          imageInfo?.size.height);
        const fn: Function = () => {
          this.sendMessageAndSetProgress(message)
        }
        ChatKitClient.runAfterLoggedIn(fn)
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
  async sendVideoMessage(uri: string, duration?: number, width?: number, height?: number) {
    try {
      let fileType = ""
      const subStrings = uri.split(".");
      if (subStrings.length > 0) {
        fileType = subStrings[subStrings.length - 1];
      }
      // 将文件 拷贝到 临时目录
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      // （以时间戳）生成一个新的文件名
      const fileName = Date.now() + '.' + fileType
      // 通过缓存路径+文件名 拼接出完整的路径
      let fileDir = DeviceUtils.rootDirPath + '/temp/'
      const copyFilePath = fileDir + fileName
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      fs.copyFileSync(file.fd, copyFilePath)
      const message = await ChatRepo.createVideoMessage(copyFilePath, file.name, undefined, duration, width, height);
      const fn: Function = () => {
        this.sendMessageAndSetProgress(message)
      }
      ChatKitClient.runAfterLoggedIn(fn)
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
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      // （以时间戳）生成一个新的文件名
      const fileName = Date.now() + '.' + fileType
      // 通过缓存路径+文件名 拼接出完整的路径
      let fileDir = DeviceUtils.rootDirPath + '/temp/'
      const copyFilePath = fileDir + fileName
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      fs.copyFileSync(file.fd, copyFilePath)
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
    const message = await ChatRepo.createAudioMessage(uri, undefined, undefined, duration * 1000);
    this.sendMessage(message)
  }

  /**
   * 发送消息
   * @param msg 消息
   * @param params 消息配置参数
   * @param progress 消息发送进度
   */
  async sendMessage(msg: V2NIMMessage, params?: V2NIMSendMessageParams, progress?: (percentage: number) => void) {
    try {
      ChatRepo.sendMessage(this.beforeSendMessage(msg), this.conversationId!!, params, progress)
    } catch (err) {
      console.log("net ease send message error", err, msg.sendingState.toString());
    }
  }

  /**
   * 转发消息
   * @param msg 消息体
   * @param conversationId 转发到某个绘画
   * @param params 消息参数
   * @param progress 消息发送进度
   */
  async sendForwardMessage(msg: V2NIMMessage, conversationId: string, params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void) {
    try {
      ChatRepo.sendMessage(this.beforeSendMessage(msg), conversationId, params, progress)
    } catch (err) {
      console.log("net ease send message error", err, msg.sendingState.toString());
    }
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
   * 将多个消息转发到多个会话中，并将留言发送到多个会话中
   * @param messages 待转发的消息
   * @param conversationIds 带转发的会话
   * @param leaveText 留言
   */
  forwardMessage(messages: NIMMessageInfo[], conversationIds: ConversationSelectModel[],
    leaveText: string | undefined) {

    if (ErrorUtils.checkNetworkAndToast()) {
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
              ChatRepo.sendMessage(this.beforeSendMessage(leaveMsg), conversation.conversationId ?? '')
            }, 200)
          }
        }
      })
    }
  }

  /**
   * 销毁
   */
  onDestroy(): void {
    ChatRepo.offReceiverMessage(this.onReceiveFun)
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
    ConversationRepo.clearUnreadCountByIds([this.conversationId])
    ChatKitClient.clearCurrentConversationId()
  }
}

