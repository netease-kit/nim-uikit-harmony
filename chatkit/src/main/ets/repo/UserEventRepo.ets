/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMUser } from '@nimsdk/base'
import { ChatKitClient } from '../ChatKitClient'
import { EventDisposer } from '../utils/DisposableBag'
import { createEventListenerHandle } from '../utils/EventListenerHandle'

export type UserEventDisposer = EventDisposer

export class UserEventRepo {
  static onUserProfileChanged(callback: (users: V2NIMUser[]) => void): UserEventDisposer {
    const service = ChatKitClient.nim.userService
    return createEventListenerHandle((listener: (users: V2NIMUser[]) => void): void => {
      service?.on('onUserProfileChanged', listener)
    }, (listener: (users: V2NIMUser[]) => void): void => {
      service?.off('onUserProfileChanged', listener)
    }, callback)
  }
}
