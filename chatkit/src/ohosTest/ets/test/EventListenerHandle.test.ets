/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium'
import { createEventListenerHandle } from '../../../main/ets/utils/EventListenerHandle'

class MockEventService {
  onCount: number = 0
  offCount: number = 0
  listener?: () => void = undefined
  offListener?: () => void = undefined

  on(callback: () => void): void {
    this.onCount++
    this.listener = callback
  }

  off(callback: () => void): void {
    this.offCount++
    this.offListener = callback
    if (this.listener === callback) {
      this.listener = undefined
    }
  }

  emit(): void {
    this.listener?.()
  }
}

export default function eventListenerHandleTest() {
  describe('eventListenerHandleTest', () => {
    it('should_unregister_with_the_same_callback_reference', 0, () => {
      const service = new MockEventService()
      const callback = (): void => {
      }

      const dispose: () => void = createEventListenerHandle(
        (listener: () => void): void => service.on(listener),
        (listener: () => void): void => service.off(listener),
        callback
      )
      dispose()

      expect(service.onCount).assertEqual(1)
      expect(service.offCount).assertEqual(1)
      expect(service.offListener === callback).assertTrue()
    })

    it('should_not_callback_after_dispose', 0, () => {
      const service = new MockEventService()
      let callCount = 0
      const dispose: () => void = createEventListenerHandle(
        (listener: () => void): void => service.on(listener),
        (listener: () => void): void => service.off(listener),
        (): void => {
          callCount++
        }
      )

      service.emit()
      dispose()
      service.emit()

      expect(callCount).assertEqual(1)
    })

    it('should_only_unregister_once_when_disposed_repeatedly', 0, () => {
      const service = new MockEventService()
      const dispose: () => void = createEventListenerHandle(
        (listener: () => void): void => service.on(listener),
        (listener: () => void): void => service.off(listener),
        (): void => {
        }
      )

      dispose()
      dispose()

      expect(service.offCount).assertEqual(1)
    })
  })
}
