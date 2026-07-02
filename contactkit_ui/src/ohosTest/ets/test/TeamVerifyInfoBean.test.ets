/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { TeamVerifyActionTextType } from '../../../main/ets/model/TeamVerifyInfoBean';

export default function TeamVerifyInfoBeanTest() {
  describe('TeamVerifyActionTextType_enum', () => {
    it('should_have_unique_values', 0, () => {
      const values: number[] = [
        TeamVerifyActionTextType.APPLICATION as number,
        TeamVerifyActionTextType.INVITATION as number,
        TeamVerifyActionTextType.ACCEPT_APPLICATION as number,
        TeamVerifyActionTextType.REJECT_APPLICATION as number,
        TeamVerifyActionTextType.ACCEPT_INVITATION as number,
        TeamVerifyActionTextType.REJECT_INVITATION as number,
      ];
      const seen = new Set<number>();
      for (let i = 0; i < values.length; i++) {
        expect(seen.has(values[i])).assertFalse();
        seen.add(values[i]);
      }
    });
  });

  describe('getTeamVerifyActionTextType_coverage_note', () => {
    it('function_requires_V2NIMTeamJoinActionInfo_SDK_type', 0, () => {
      // getTeamVerifyActionTextType 是纯 switch 逻辑，但依赖 SDK 类型 V2NIMTeamJoinActionInfo
      // 该类型含 20+ 字段，无法在 src/test 中用 implements 接口完整模拟
      // 需要 ohosTest 设备环境提供真实 SDK 对象进行测试
      const val1: number = TeamVerifyActionTextType.APPLICATION as number;
      const val2: number = TeamVerifyActionTextType.INVITATION as number;
      expect(val1 !== val2).assertTrue();
    });
  });
}
