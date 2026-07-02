/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMFriend,
  V2NIMFriendAddApplication,
  V2NIMFriendAddRejection,
  V2NIMFriendDeletionType
} from '@nimsdk/base'
import { ChatKitClient } from '../ChatKitClient'
import { EventDisposer } from '../utils/DisposableBag'
import { createEventListenerHandle } from '../utils/EventListenerHandle'

export type FriendEventDisposer = EventDisposer

export class FriendEventRepo {
  static onFriendAdded(callback: (friend: V2NIMFriend) => void): FriendEventDisposer {
    const service = ChatKitClient.nim.friendService
    return createEventListenerHandle((listener: (friend: V2NIMFriend) => void): void => {
      service?.on('onFriendAdded', listener)
    }, (listener: (friend: V2NIMFriend) => void): void => {
      service?.off('onFriendAdded', listener)
    }, callback)
  }

  static onFriendDeleted(
    callback: (accountId: string, deletionType: V2NIMFriendDeletionType) => void
  ): FriendEventDisposer {
    const service = ChatKitClient.nim.friendService
    return createEventListenerHandle(
      (listener: (accountId: string, deletionType: V2NIMFriendDeletionType) => void): void => {
        service?.on('onFriendDeleted', listener)
      },
      (listener: (accountId: string, deletionType: V2NIMFriendDeletionType) => void): void => {
        service?.off('onFriendDeleted', listener)
      },
      callback
    )
  }

  static onFriendAddApplication(callback: (application: V2NIMFriendAddApplication) => void): FriendEventDisposer {
    const service = ChatKitClient.nim.friendService
    return createEventListenerHandle((listener: (application: V2NIMFriendAddApplication) => void): void => {
      service?.on('onFriendAddApplication', listener)
    }, (listener: (application: V2NIMFriendAddApplication) => void): void => {
      service?.off('onFriendAddApplication', listener)
    }, callback)
  }

  static onFriendAddRejected(callback: (rejection: V2NIMFriendAddRejection) => void): FriendEventDisposer {
    const service = ChatKitClient.nim.friendService
    return createEventListenerHandle((listener: (rejection: V2NIMFriendAddRejection) => void): void => {
      service?.on('onFriendAddRejected', listener)
    }, (listener: (rejection: V2NIMFriendAddRejection) => void): void => {
      service?.off('onFriendAddRejected', listener)
    }, callback)
  }

  static onFriendInfoChanged(callback: (friend: V2NIMFriend) => void): FriendEventDisposer {
    const service = ChatKitClient.nim.friendService
    return createEventListenerHandle((listener: (friend: V2NIMFriend) => void): void => {
      service?.on('onFriendInfoChanged', listener)
    }, (listener: (friend: V2NIMFriend) => void): void => {
      service?.off('onFriendInfoChanged', listener)
    }, callback)
  }
}
