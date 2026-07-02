/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    beforeAll(() => {});
    beforeEach(() => {});
    afterEach(() => {});
    afterAll(() => {});

    it('assertContain', 0, () => {
      let a = 'abc';
      let b = 'b';
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    // ChatInfo.pushMessage/unshiftMessage/cacheVoiceToText 测试依赖 ChatKitClient.nim mock
    // 由于 ArkTS 不允许 Record<string, Object> 赋值给 NIMInterface 类型，
    // 且不允许索引访问 ChatKitClient['nim']，这些测试需移至 ohosTest 设备环境
  });
}
