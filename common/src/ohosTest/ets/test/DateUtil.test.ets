/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { DateUtil } from '../../../main/ets/utils/DateUtil';

export default function DateUtilTest() {
  describe('DateUtil_isDate', () => {
    it('should_match_yyyymmdd', 0, () => {
      expect(DateUtil.isDate('20240115')).assertTrue();
    });
    it('should_match_yyyy_mm_dd', 0, () => {
      expect(DateUtil.isDate('2024-01-15')).assertTrue();
    });
    it('should_match_yyyy_mm_dd_with_time', 0, () => {
      expect(DateUtil.isDate('2024-01-15 14:30:00')).assertTrue();
    });
    it('should_match_iso8601', 0, () => {
      expect(DateUtil.isDate('2024-01-15T14:30:00.000Z')).assertTrue();
    });
    it('should_match_time_only_hhmmss', 0, () => {
      expect(DateUtil.isDate('14:30:00')).assertTrue();
    });
    it('should_match_time_only_hhmm', 0, () => {
      expect(DateUtil.isDate('14:30')).assertTrue();
    });
    it('should_match_slash_format', 0, () => {
      expect(DateUtil.isDate('2024/01/15')).assertTrue();
    });
    it('should_match_slash_with_time', 0, () => {
      expect(DateUtil.isDate('2024/01/15 14:30:00')).assertTrue();
    });
    it('should_reject_plain_text', 0, () => {
      expect(DateUtil.isDate('hello')).assertFalse();
    });
    it('should_reject_empty', 0, () => {
      expect(DateUtil.isDate('')).assertFalse();
    });
    it('should_reject_short_number', 0, () => {
      expect(DateUtil.isDate('12345')).assertFalse();
    });
    it('should_reject_partial_date', 0, () => {
      expect(DateUtil.isDate('2024-01')).assertFalse();
    });
  });

  describe('DateUtil_parse', () => {
    it('should_parse_date_string_to_date_object', 0, () => {
      let date: Date = DateUtil.parse('2024-01-15');
      expect(date.getFullYear()).assertEqual(2024);
      expect(date.getMonth()).assertEqual(0);
      expect(date.getDate()).assertEqual(15);
    });

    it('should_parse_iso_date_string', 0, () => {
      let date: Date = DateUtil.parse('2024-06-15T14:30:00');
      let hours: number = date.getHours();
      expect(hours).assertEqual(14);
    });
  });

  describe('DateUtil_formatDate', () => {
    it('should_format_default', 0, () => {
      let result: string = DateUtil.formatDate('2024-01-15', 'yyyy-MM-dd');
      expect(result).assertEqual('2024-01-15');
    });
    it('should_format_slash', 0, () => {
      let result: string = DateUtil.formatDate('2024-01-15', 'yyyy/MM/dd');
      expect(result).assertEqual('2024/01/15');
    });
    it('should_format_with_time', 0, () => {
      let result: string = DateUtil.formatDate('2024-01-15T14:30:00', 'yyyy-MM-dd HH:mm:ss');
      expect(result).assertEqual('2024-01-15 14:30:00');
    });
    it('should_zero_time_for_date_only_input', 0, () => {
      let result: string = DateUtil.formatDate('2024-06-15', 'HH:mm');
      expect(result).assertEqual('00:00');
    });
    it('should_format_with_hh_mm', 0, () => {
      let result: string = DateUtil.formatDate('2024-01-15 08:30', 'HH:mm');
      expect(result).assertEqual('08:30');
    });
  });

  describe('DateUtil_format', () => {
    it('should_format_yyyy_mm_dd', 0, () => {
      let date: Date = new Date(2024, 0, 15);
      expect(DateUtil.format(date, 'yyyy-MM-dd')).assertEqual('2024-01-15');
    });
    it('should_format_with_time', 0, () => {
      let date: Date = new Date(2024, 5, 15, 14, 30, 45);
      expect(DateUtil.format(date, 'yyyy-MM-dd HH:mm:ss')).assertEqual('2024-06-15 14:30:45');
    });
    it('should_pad_single_digit', 0, () => {
      let date: Date = new Date(2024, 0, 5, 9, 5, 3);
      expect(DateUtil.format(date, 'HH:mm:ss')).assertEqual('09:05:03');
    });
    it('should_handle_december', 0, () => {
      let date: Date = new Date(2024, 11, 31);
      expect(DateUtil.format(date, 'yyyy-MM-dd')).assertEqual('2024-12-31');
    });
  });

  describe('DateUtil_dateDiff', () => {
    it('should_return_zero_for_same_day', 0, () => {
      let start: Date = new Date(2024, 0, 15);
      let end: Date = new Date(2024, 0, 15);
      expect(DateUtil.dateDiff(start, end)).assertEqual(0);
    });
    it('should_return_positive_when_end_after_start', 0, () => {
      let start: Date = new Date(2024, 0, 1);
      let end: Date = new Date(2024, 0, 10);
      expect(DateUtil.dateDiff(start, end)).assertEqual(9);
    });
    it('should_return_negative_when_start_after_end', 0, () => {
      let start: Date = new Date(2024, 0, 10);
      let end: Date = new Date(2024, 0, 1);
      expect(DateUtil.dateDiff(start, end)).assertEqual(-9);
    });
    it('should_handle_cross_month', 0, () => {
      let start: Date = new Date(2024, 0, 31);
      let end: Date = new Date(2024, 1, 1);
      expect(DateUtil.dateDiff(start, end)).assertEqual(1);
    });
    it('should_handle_cross_year', 0, () => {
      let start: Date = new Date(2024, 11, 31);
      let end: Date = new Date(2025, 0, 1);
      expect(DateUtil.dateDiff(start, end)).assertEqual(1);
    });
  });

  describe('DateUtil_strDateDiff', () => {
    it('should_return_zero_for_same_date', 0, () => {
      expect(DateUtil.strDateDiff('2024-01-15', '2024-01-15')).assertEqual(0);
    });
    it('should_return_positive', 0, () => {
      expect(DateUtil.strDateDiff('2024-01-01', '2024-01-10')).assertEqual(9);
    });
    it('should_return_negative', 0, () => {
      expect(DateUtil.strDateDiff('2024-01-10', '2024-01-01')).assertEqual(-9);
    });
    it('should_handle_cross_month', 0, () => {
      expect(DateUtil.strDateDiff('2024-01-31', '2024-02-01')).assertEqual(1);
    });
  });

  describe('DateUtil_formatTimestamp_today', () => {
    it('should_return_hh_mm_for_today', 0, () => {
      let now: Date = new Date();
      let ts: number = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 10, 30, 0).getTime();
      let result: string = DateUtil.formatTimestamp(ts, false);
      expect(result).assertEqual('10:30');
    });
    it('should_return_mm_dd_hh_mm_for_recent', 0, () => {
      let now: Date = new Date();
      let yesterday: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 14, 0, 0);
      let result: string = DateUtil.formatTimestamp(yesterday.getTime(), false);
      expect(result).assertContain(':');
    });
    it('should_return_yyyy_m_d_for_cross_year', 0, () => {
      let ts: number = new Date(2020, 5, 15, 10, 30, 0).getTime();
      expect(DateUtil.formatTimestamp(ts, false)).assertEqual('2020-6-15');
    });

    // formatTimestamp with isLocalized=true - cross-year
    it('should_handle_localized_cross_year', 0, () => {
      let ts: number = new Date(2020, 5, 15, 10, 30, 0).getTime();
      let result: string = DateUtil.formatTimestamp(ts, true);
      expect(result).assertContain('2020');
    });

    // formatTimestamp with isLocalized=true - cross-month/day
    it('should_handle_localized_cross_day', 0, () => {
      let now: Date = new Date();
      let yesterday: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 14, 0, 0);
      let result: string = DateUtil.formatTimestamp(yesterday.getTime(), true);
      expect(result).assertContain(':');
    });

    // formatTimestamp with isLocalized=true - today (no localization in today branch)
    it('should_handle_localized_today', 0, () => {
      let now: Date = new Date();
      let ts: number = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 8, 15, 0).getTime();
      let result: string = DateUtil.formatTimestamp(ts, true);
      expect(result).assertEqual('08:15');
    });
  });
}
