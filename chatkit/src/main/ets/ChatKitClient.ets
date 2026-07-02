/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { CoreKitClient } from '@nimkit/corekit';
import {
  IM_SDK_VERSION,
  NIM,
  NIMInterface,
  V2NIMConnectStatus,
  V2NIMDataSyncState,
  V2NIMDataSyncType,
  V2NIMEnableServiceType,
  V2NIMError,
  V2NIMLoginStatus,
  V2NIMMessage,
  V2NIMMessageRevokeNotification
} from '@nimsdk/base';
import { IMKitConfigCenter, LocalConversationRepo, SubscriptionRepo } from '../../../Index';
import { KitLogger } from './logger/AppLogger';
import { LoggerKitImpl } from './logger/LoggerKitImpl';
import { ChatRepo } from './repo/ChatRepo';
import { DeferredStartupTask } from './utils/DeferredStartupTask';
import { saveLocalRevokeMessageFormOther } from './utils/MessageUtils';
import { NotificationHelper } from './utils/NotificationHelper';

export const currentConversationChanged: string = 'CurrentConversationChanged'
const DEFAULT_DEFERRED_STARTUP_DELAY_MS: number = 500

export type ChatKitStartupPerfMarker = (stage: string, detail?: string) => void

export class ChatKitClient {
  declare static nim: NIMInterface
  static appKey: string = ''
  static accountToken: string = ''
  static haveSyncedConversation: boolean = false
  //是否主动离开群
  static selfLeaveTeam = false
  static hasInitListener = false
  static currentConversationId: string = ''
  static networkAvailable: boolean = true
  static logger: KitLogger | undefined = undefined
  private static loggerCacheDir: string = ''
  private static enableKitLogger: boolean = false
  private static loggerStartupTask: DeferredStartupTask | undefined = undefined
  private static coreReportStartupTask: DeferredStartupTask | undefined = undefined

  static init(nimSdk: NIMInterface, appKey: string, disableLog?: boolean,
    autoScheduleDeferredStartup: boolean = true, startupPerfMarker?: ChatKitStartupPerfMarker): void {
    ChatKitClient.markStartupPerf(startupPerfMarker, 'chatkit.client_assign.start')
    if (ChatKitClient.hasInitListener) {
      ChatKitClient.onDestroy()
    }
    ChatKitClient.nim = nimSdk
    ChatKitClient.appKey = appKey
    ChatKitClient.logger = undefined
    ChatKitClient.enableKitLogger = disableLog !== true && nimSdk instanceof NIM
    ChatKitClient.loggerCacheDir = ChatKitClient.enableKitLogger && nimSdk instanceof NIM ? nimSdk.context.cacheDir : ''
    ChatKitClient.resetDeferredStartupTasks()
    ChatKitClient.markStartupPerf(startupPerfMarker, 'chatkit.client_assign.end',
      `loggerEnabled=${ChatKitClient.enableKitLogger}`)
    ChatKitClient.haveSyncedConversation = false
    // 新登录边界必须清理在线状态订阅缓存，避免切账号后复用上个账号的订阅结果。
    SubscriptionRepo.resetSubscriptionState()
    ChatKitClient.markStartupPerf(startupPerfMarker, 'chatkit.listener_init.start')
    ChatKitClient.initListener()
    ChatKitClient.markStartupPerf(startupPerfMarker, 'chatkit.listener_init.end')
    if (autoScheduleDeferredStartup) {
      ChatKitClient.markStartupPerf(startupPerfMarker, 'chatkit.deferred_startup.auto_schedule.start')
      ChatKitClient.scheduleDeferredStartup(DEFAULT_DEFERRED_STARTUP_DELAY_MS, startupPerfMarker)
      ChatKitClient.markStartupPerf(startupPerfMarker, 'chatkit.deferred_startup.auto_schedule.end')
    }
  }

  static saveAccountToken(token: string): void {
    ChatKitClient.accountToken = token
  }

  static scheduleDeferredStartup(delayMs: number = DEFAULT_DEFERRED_STARTUP_DELAY_MS,
    startupPerfMarker?: ChatKitStartupPerfMarker): void {
    ChatKitClient.ensureDeferredStartupTasks()
    ChatKitClient.scheduleDeferredTask(
      ChatKitClient.loggerStartupTask,
      'chatkit.logger_lazy_init',
      delayMs,
      startupPerfMarker
    )
    ChatKitClient.scheduleDeferredTask(
      ChatKitClient.coreReportStartupTask,
      'chatkit.core_report',
      delayMs,
      startupPerfMarker
    )
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
    // 设置 SDK 当前聊天账号
    ChatKitClient.switchCurrentConversation(true)
  }

  /**
   * 清除当前会话id
   */
  static clearCurrentConversationId() {
    ChatKitClient.currentConversationId = ''
    getContext().eventHub.emit(currentConversationChanged, '')
    // 消除 SDK 当前聊天账号
    ChatKitClient.switchCurrentConversation(false)
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

  static isLocalConversation(): boolean {
    return ChatKitClient.nim.isServiceEnable(V2NIMEnableServiceType.LOCAL_CONVERSATION)
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
    ChatKitClient.logger = undefined
    ChatKitClient.loggerCacheDir = ''
    ChatKitClient.enableKitLogger = false
    ChatKitClient.resetDeferredStartupTasks()
    ChatRepo.offRevokeMessage(ChatKitClient.onRevokeFun)
    ChatRepo.offReceiverMessage(ChatKitClient.onReceiveMessageFun)
    ChatKitClient.nim.conversationService?.off('onSyncFinished', ChatKitClient.onSyncFinishedFun)
    ChatKitClient.nim.localConversationService?.off('onSyncFinished', ChatKitClient.onSyncFinishedFun)
    ChatKitClient.nim.loginService.off('onDataSync', ChatKitClient.dataSyncFun)
    SubscriptionRepo.removeListener()

  }

  /**
   * 初始化监听
   */
  private static initListener() {
    if (ChatKitClient.hasInitListener) {
      return
    }
    Logger.info('ChatKit', "netease ChatKitClient initListener ");
    // 数据同步监听
    ChatKitClient.nim.conversationService?.on('onSyncFinished', ChatKitClient.onSyncFinishedFun)
    ChatKitClient.nim.localConversationService?.on('onSyncFinished', ChatKitClient.onSyncFinishedFun)
    ChatKitClient.nim.loginService.on('onDataSync', ChatKitClient.dataSyncFun)
    if (IMKitConfigCenter.enableShownOnlineState) {
      SubscriptionRepo.addListener()
    }
    // 消息撤回监听，消息撤回后，会收到通知
    ChatRepo.onRevokeMessage(ChatKitClient.onRevokeFun)
    // 消息接收监听，用于触发响铃和震动
    ChatRepo.onReceiverMessage(ChatKitClient.onReceiveMessageFun)
    ChatKitClient.hasInitListener = true

  }

  private static onSyncFinishedFun = () => {
    ChatKitClient.haveSyncedConversation = true
  }

  private static dataSyncFun = (type: V2NIMDataSyncType, state: V2NIMDataSyncState, error?: V2NIMError) => {
    // 会话 SDK 已按当前会话目标补齐昵称、头像和免打扰状态；好友/黑名单全量缓存由联系人页按需加载。
  }

  private static onRevokeFun = (messages: V2NIMMessageRevokeNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId !== ChatKitClient.currentConversationId) {
        saveLocalRevokeMessageFormOther(msg.messageRefer.conversationId, msg, false)
      }
    })
  }

  /**
   * 消息接收回调，用于触发响铃和震动
   */
  private static onReceiveMessageFun = (messages: V2NIMMessage[]) => {
    if (messages.length === 0) {
      return
    }
    // 收到新消息时触发响铃和震动（传递消息列表用于检查会话级别免打扰）
    NotificationHelper.notifyNewMessage(messages)
  }

  // 设置当前聊天会话
  private static switchCurrentConversation(on: boolean): void {
    if (IMKitConfigCenter.enableLocalConversation) {
      if (on) {
        // on
        LocalConversationRepo.setCurrentConversation(ChatKitClient.currentConversationId)
      } else {
        // off
        LocalConversationRepo.setCurrentConversation(undefined)
      }
    }
  }

  private static resetDeferredStartupTasks(): void {
    ChatKitClient.loggerStartupTask?.reset()
    ChatKitClient.coreReportStartupTask?.reset()
    ChatKitClient.loggerStartupTask = new DeferredStartupTask((): void => {
      ChatKitClient.initLogger()
    })
    ChatKitClient.coreReportStartupTask = new DeferredStartupTask((): void => {
      ChatKitClient.reportCoreKitInit()
    })
  }

  private static ensureDeferredStartupTasks(): void {
    if (!ChatKitClient.loggerStartupTask || !ChatKitClient.coreReportStartupTask) {
      ChatKitClient.resetDeferredStartupTasks()
    }
  }

  private static scheduleDeferredTask(task: DeferredStartupTask | undefined, stage: string, delayMs: number,
    startupPerfMarker?: ChatKitStartupPerfMarker): void {
    if (!task) {
      return
    }
    const didSchedule = task.schedule((runner: () => void): void => {
      setTimeout((): void => {
        ChatKitClient.markStartupPerf(startupPerfMarker, `${stage}.start`)
        runner()
        ChatKitClient.markStartupPerf(startupPerfMarker, `${stage}.end`)
      }, delayMs)
    })
    ChatKitClient.markStartupPerf(startupPerfMarker, `${stage}.${didSchedule ? 'schedule' : 'skip'}`,
      `delay=${delayMs}`)
  }

  private static initLogger(): void {
    if (!ChatKitClient.enableKitLogger || !ChatKitClient.loggerCacheDir || ChatKitClient.logger) {
      return
    }
    try {
      const logger = new LoggerKitImpl(ChatKitClient.loggerCacheDir)
      ChatKitClient.logger = new KitLogger(logger)
    } catch (e) {
      Logger.error('ChatKit', 'ChatKitClient initLogger failed', JSON.stringify(e))
    }
  }

  private static reportCoreKitInit(): void {
    if (!ChatKitClient.appKey) {
      return
    }
    CoreKitClient.init({
      appKey: ChatKitClient.appKey,
      imVersion: IM_SDK_VERSION,
    })
  }

  private static markStartupPerf(startupPerfMarker: ChatKitStartupPerfMarker | undefined, stage: string,
    detail?: string): void {
    if (startupPerfMarker) {
      startupPerfMarker(stage, detail)
    }
  }
}
