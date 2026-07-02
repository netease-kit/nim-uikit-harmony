/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMConnectStatus,
  V2NIMDataSyncState,
  V2NIMDataSyncType,
  V2NIMError,
  V2NIMLoginStatus
} from '@nimsdk/base'
import { ChatKitClient } from '../ChatKitClient'
import { EventDisposer } from '../utils/DisposableBag'
import { createEventListenerHandle } from '../utils/EventListenerHandle'

export type LoginEventDisposer = EventDisposer

export class LoginEventRepo {
  static onDataSync(
    callback: (type: V2NIMDataSyncType, state: V2NIMDataSyncState, error?: V2NIMError) => void
  ): LoginEventDisposer {
    const service = ChatKitClient.nim.loginService
    return createEventListenerHandle(
      (
        listener: (type: V2NIMDataSyncType, state: V2NIMDataSyncState, error?: V2NIMError) => void
      ): void => {
        service?.on('onDataSync', listener)
      },
      (
        listener: (type: V2NIMDataSyncType, state: V2NIMDataSyncState, error?: V2NIMError) => void
      ): void => {
        service?.off('onDataSync', listener)
      },
      callback
    )
  }

  static onConnectStatus(callback: (status: V2NIMConnectStatus) => void): LoginEventDisposer {
    const service = ChatKitClient.nim.loginService
    return createEventListenerHandle((listener: (status: V2NIMConnectStatus) => void): void => {
      service?.on('onConnectStatus', listener)
    }, (listener: (status: V2NIMConnectStatus) => void): void => {
      service?.off('onConnectStatus', listener)
    }, callback)
  }

  static onLoginStatus(callback: (status: V2NIMLoginStatus) => void): LoginEventDisposer {
    const service = ChatKitClient.nim.loginService
    return createEventListenerHandle((listener: (status: V2NIMLoginStatus) => void): void => {
      service?.on('onLoginStatus', listener)
    }, (listener: (status: V2NIMLoginStatus) => void): void => {
      service?.off('onLoginStatus', listener)
    }, callback)
  }
}
