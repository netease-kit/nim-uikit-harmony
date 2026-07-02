/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { EventDisposer } from './DisposableBag'

export type EventRegister<T> = (callback: T) => void
export type EventUnregister<T> = (callback: T) => void

export function createEventListenerHandle<T>(
  register: EventRegister<T>,
  unregister: EventUnregister<T>,
  callback: T
): EventDisposer {
  let disposed = false
  register(callback)
  return (): void => {
    if (disposed) {
      return
    }
    disposed = true
    unregister(callback)
  }
}
