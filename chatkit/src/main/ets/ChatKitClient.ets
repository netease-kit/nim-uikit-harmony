/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { KitReport } from '@nimkit/coreKit/src/main/ets/KitReport';
import { IM_SDK_VERSION, NIMInterface, V2NIMDataSyncState, V2NIMDataSyncType } from '@nimsdk/base';

export class ChatKitClient {
  declare static nim: NIMInterface
  static haveSyncedConversation: boolean = false
  //是否主动离开群
  static selfLeaveTeam = false

  static init(nimSdk: NIMInterface, appKey: string) {
    ChatKitClient.nim = nimSdk
    ChatKitClient.haveSyncedConversation = false
    ChatKitClient.initListener()
    KitReport.reportToServer({
      appKey: appKey,
      component: 'ChatKit',
      version: '1.0.0',
      imVersion: IM_SDK_VERSION,
      platform: 'harmony',
      reportType: 'init',
      timeStamp: Date.now()
    })
  }

  static initListener() {
    ChatKitClient.nim.conversationService?.on('onSyncFinished',
      () => {
        ChatKitClient.haveSyncedConversation = true
      }
    )
  }

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
}