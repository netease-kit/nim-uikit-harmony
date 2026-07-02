/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';

/**
 * DateUtils.formatCallTime 的纯逻辑单元测试
 * 将函数逻辑复制为本地版本，避免 HarmonyOS 平台 import 依赖。
 */
function formatCallTime(time: number): string {
  const hour: number = Math.floor(time / 3600);
  const minute: number = Math.floor((time % 3600) / 60);
  const second: number = time % 60;
  if (hour === 0) {
    return `${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}`;
  }
  return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}:${second.toString()
    .padStart(2, '0')}`;
}

export default function dateUtilsTest() {
  describe('DateUtils_formatCallTime', () => {
    it('should_format_zero_seconds', 0, () => {
      expect(formatCallTime(0)).assertEqual('00:00');
    });

    it('should_format_seconds_only', 0, () => {
      expect(formatCallTime(5)).assertEqual('00:05');
    });

    it('should_format_30_seconds', 0, () => {
      expect(formatCallTime(30)).assertEqual('00:30');
    });

    it('should_format_59_seconds', 0, () => {
      expect(formatCallTime(59)).assertEqual('00:59');
    });

    it('should_format_one_minute', 0, () => {
      expect(formatCallTime(60)).assertEqual('01:00');
    });

    it('should_format_minutes_and_seconds', 0, () => {
      expect(formatCallTime(90)).assertEqual('01:30');
    });

    it('should_format_10_minutes_5_seconds', 0, () => {
      expect(formatCallTime(605)).assertEqual('10:05');
    });

    it('should_format_59_minutes_59_seconds', 0, () => {
      expect(formatCallTime(3599)).assertEqual('59:59');
    });

    it('should_format_one_hour', 0, () => {
      expect(formatCallTime(3600)).assertEqual('01:00:00');
    });

    it('should_format_one_hour_one_minute_one_second', 0, () => {
      expect(formatCallTime(3661)).assertEqual('01:01:01');
    });

    it('should_format_two_hours_thirty_minutes_forty_five_seconds', 0, () => {
      expect(formatCallTime(9045)).assertEqual('02:30:45');
    });

    it('should_format_10_hours', 0, () => {
      expect(formatCallTime(36000)).assertEqual('10:00:00');
    });

    it('should_format_large_time_value', 0, () => {
      // 99小时59分59秒 = 359999秒
      expect(formatCallTime(359999)).assertEqual('99:59:59');
    });
  });
}
