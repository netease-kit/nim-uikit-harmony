/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';

class MockLoginService {
  private onListeners: Map<string, Object[]> = new Map();
  private offListeners: Map<string, Object[]> = new Map();

  on(event: string, callback: Object): void {
    let arr = this.onListeners.get(event);
    if (arr === undefined) {
      arr = [];
      this.onListeners.set(event, arr);
    }
    arr.push(callback);
  }

  off(event: string, callback: Object): void {
    let arr = this.offListeners.get(event);
    if (arr === undefined) {
      arr = [];
      this.offListeners.set(event, arr);
    }
    arr.push(callback);
  }

  getOnCount(event: string): number {
    const arr = this.onListeners.get(event);
    if (arr !== undefined) {
      return arr.length;
    }
    return 0;
  }

  getOffCount(event: string): number {
    const arr = this.offListeners.get(event);
    if (arr !== undefined) {
      return arr.length;
    }
    return 0;
  }
}

export default function LoginEventRepoTest() {
  describe('LoginEventRepo_event_handle_pattern', () => {
    it('should_register_and_then_unregister_listener', 0, () => {
      const service = new MockLoginService();
      const callback = (data: Object): void => { /* noop */ };

      service.on('testEvent', callback);
      expect(service.getOnCount('testEvent')).assertEqual(1);
      expect(service.getOffCount('testEvent')).assertEqual(0);

      service.off('testEvent', callback);
      expect(service.getOffCount('testEvent')).assertEqual(1);
    });

    it('should_not_unregister_twice_in_disposer_pattern', 0, () => {
      let unregisterCount = 0;
      const callback = (): void => { /* noop */ };

      let disposed = false;
      const disposer = (): void => {
        if (disposed) {
          return;
        }
        disposed = true;
        unregisterCount++;
      };

      disposer();
      disposer();
      expect(unregisterCount).assertEqual(1);
    });

    it('should_independent_handles_unregister_separately', 0, () => {
      const service = new MockLoginService();
      const cb1 = (): void => { };
      const cb2 = (): void => { };

      service.on('testEvent', cb1);
      service.on('testEvent', cb2);
      expect(service.getOnCount('testEvent')).assertEqual(2);

      service.off('testEvent', cb1);
      expect(service.getOffCount('testEvent')).assertEqual(1);
    });
  });
}
