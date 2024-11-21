/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  IM_SDK_VERSION,
  NIM,
  NIMInterface,
  V2NIMConnectStatus,
  V2NIMDataSyncState,
  V2NIMDataSyncType,
  V2NIMError,
  V2NIMLoginStatus,
  V2NIMMessageRevokeNotification
} from '@nimsdk/base';
import { ChatRepo } from './repo/ChatRepo';
import { saveLocalRevokeMessageFormOther } from './utils/MessageUtils';
import { NEFriendUserCache } from './NEFriendUserCache';
import { CoreKitClient } from '@nimkit/coreKit';
import { LoggerKitImpl } from './logger/LoggerKitImpl';
import { KitLogger } from './logger/AppLogger';

export const currentConversationChanged: string = 'CurrentConversationChanged'

export class ChatKitClient {
  declare static nim: NIMInterface
  static haveSyncedConversation: boolean = false
  //是否主动离开群
  static selfLeaveTeam = false
  static hasInitListener = false
  static currentConversationId: string = ''
  static networkAvailable: boolean = true
  static logger: KitLogger | undefined = undefined

  static init(nimSdk: NIMInterface, appKey: string, disableLog?: boolean) {
    ChatKitClient.nim = nimSdk
    if (disableLog !== true) {
      if (nimSdk instanceof NIM) {
        let logger = new LoggerKitImpl(nimSdk.context.cacheDir)
        ChatKitClient.logger = new KitLogger(logger)
      }
    }
    ChatKitClient.haveSyncedConversation = false
    ChatKitClient.initListener()
    CoreKitClient.init({
      appKey: appKey,
      imVersion: IM_SDK_VERSION,
    })
  }

  /**
   * 长连接是否断开
   * 可用于判断网络是否断开
   */
  static connectBroken() {
    return ChatKitClient.nim.loginService.getConnectStatus() !== V2NIMConnectStatus.V2NIM_CONNECT_STATUS_CONNECTED
  }

  /**
   * 设置当前会话id
   * @param conversationId 当前会话id
   */
  static setCurrentConversationId(conversationId: string) {
    ChatKitClient.currentConversationId = conversationId
    getContext().eventHub.emit(currentConversationChanged, conversationId)
  }

  /**
   * 清除当前会话id
   */
  static clearCurrentConversationId() {
    ChatKitClient.currentConversationId = ''
    getContext().eventHub.emit(currentConversationChanged, '')
  }

  /**
   * 获取当前会话id
   * @returns 当前会话id
   */
  static getCurrentConversationId(): string {
    return ChatKitClient.currentConversationId
  }

  /**
   * 是否登录
   * @returns
   */
  static hasLogin(): boolean {
    return ChatKitClient.nim != null && ChatKitClient.nim.loginService.getLoginUser() != null
  }

  static getLoginUserId(): string {
    return ChatKitClient.nim.loginService.getLoginUser()
  }

  /**
   * IM 主数据是否同步完成
   * @returns
   */
  static isMainDataSynced(): boolean {
    let dataSync = ChatKitClient.nim.loginService.getDataSync()
    if (dataSync != null) {
      for (const item of dataSync) {
        if (item.type === V2NIMDataSyncType.V2NIM_DATA_SYNC_TYPE_MAIN &&
          item.state === V2NIMDataSyncState.V2NIM_DATA_SYNC_STATE_COMPLETED) {
          return true
        }
      }
    }
    return false
  }

  /**
   * 等待登录后执行
   */
  static runAfterLoggedIn(fn: Function) {
    if (ChatKitClient.nim.loginService?.getLoginStatus() === V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED) {
      fn()
    } else {
      const onLoginStatusFunc = (status: V2NIMLoginStatus) => {
        if (status === V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED) {
          fn()
          ChatKitClient.nim.loginService.off('onLoginStatus', onLoginStatusFunc)
        }
      }
      ChatKitClient.nim.loginService.on('onLoginStatus', onLoginStatusFunc)
    }
  }

  /*
  * 销毁 清理监听
  */
  static onDestroy() {
    ChatKitClient.hasInitListener = false
    ChatKitClient.haveSyncedConversation = false
    ChatKitClient.selfLeaveTeam = false
    ChatKitClient.currentConversationId = ''
    ChatRepo.offRevokeMessage(ChatKitClient.onRevokeFun)
    ChatKitClient.nim.conversationService?.off('onSyncFinished', ChatKitClient.onSyncFinishedFun)
    ChatKitClient.nim.loginService.off('onDataSync', ChatKitClient.dataSyncFun)

  }

  /**
   * 初始化监听
   */
  private static initListener() {
    if (ChatKitClient.hasInitListener) {
      return
    }
    console.info("netease ChatKitClient initListener ");
    // 数据同步监听
    ChatKitClient.nim.conversationService?.on('onSyncFinished', ChatKitClient.onSyncFinishedFun)
    ChatKitClient.nim.loginService.on('onDataSync', ChatKitClient.dataSyncFun)
    // 消息撤回监听，消息撤回后，会收到通知
    ChatRepo.onRevokeMessage(ChatKitClient.onRevokeFun)
    ChatKitClient.hasInitListener = true

  }

  private static onSyncFinishedFun = () => {
    console.debug(`Performance Test onSyncFinishedFun`)
    ChatKitClient.haveSyncedConversation = true
  }

  private static dataSyncFun = (type: V2NIMDataSyncType, state: V2NIMDataSyncState, error?: V2NIMError) => {
    if (state === V2NIMDataSyncState.V2NIM_DATA_SYNC_STATE_COMPLETED) {
      NEFriendUserCache.getInstance()
    }
  }

  private static onRevokeFun = (messages: V2NIMMessageRevokeNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId !== ChatKitClient.currentConversationId) {
        saveLocalRevokeMessageFormOther(msg.messageRefer.conversationId, msg, false)
      }
    })
  }
}