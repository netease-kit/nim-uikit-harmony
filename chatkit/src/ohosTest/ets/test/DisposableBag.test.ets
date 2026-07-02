/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { DisposableBag } from '../../../main/ets/utils/DisposableBag';

export default function DisposableBagTest() {
  describe('DisposableBag', () => {
    it('should_call_all_disposers_on_dispose', 0, () => {
      let calls: string[] = [];
      let bag: DisposableBag = new DisposableBag();
      bag.add((): void => { calls.push('a'); });
      bag.add((): void => { calls.push('b'); });
      bag.dispose();
      expect(calls.length).assertEqual(2);
      expect(calls[0]).assertEqual('a');
      expect(calls[1]).assertEqual('b');
    });

    it('should_empty_after_dispose', 0, () => {
      let callCount: number = 0;
      let bag: DisposableBag = new DisposableBag();
      bag.add((): void => { callCount++; });
      bag.dispose();
      expect(callCount).assertEqual(1);
      bag.dispose();
      expect(callCount).assertEqual(1);
    });

    it('should_not_throw_on_empty_bag_dispose', 0, () => {
      let bag: DisposableBag = new DisposableBag();
      bag.dispose();
    });

    it('should_support_addAll', 0, () => {
      let calls: string[] = [];
      let bag: DisposableBag = new DisposableBag();
      bag.addAll([
        (): void => { calls.push('x'); },
        (): void => { calls.push('y'); },
        (): void => { calls.push('z'); },
      ]);
      bag.dispose();
      expect(calls.length).assertEqual(3);
    });
  });
}
