/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { NECommonUtils } from '../../../main/ets/utils/NECommonUtils';
import { BreakPointType } from '../../../main/ets/utils/BreakpointSystem';
import { fillNum, getTimeString } from '../../../main/ets/utils/TimeUtils';

function makeStrOpts(): Record<string, string> {
  let o: Record<string, string> = new Object() as Record<string, string>;
  o['sm'] = 'small';
  o['md'] = 'medium';
  o['lg'] = 'large';
  o['xl'] = 'extra';
  o['xxl'] = 'huge';
  return o;
}

function makeNumOpts(): Record<string, number> {
  let o: Record<string, number> = new Object() as Record<string, number>;
  o['sm'] = 12;
  o['md'] = 15;
  o['lg'] = 4;
  o['xl'] = 8;
  o['xxl'] = 12;
  return o;
}

export default function CommonUtilsTest() {
  describe('NECommonUtils_shortName', () => {
    it('should_return_empty_for_empty_string', 0, () => {
      expect(NECommonUtils.shortName('', 2)).assertEqual('');
      expect(NECommonUtils.shortName('', 0)).assertEqual('');
      expect(NECommonUtils.shortName('')).assertEqual('');
    });
    it('should_return_empty_for_undefined', 0, () => {
      expect(NECommonUtils.shortName(undefined)).assertEqual('');
      expect(NECommonUtils.shortName(undefined, 3)).assertEqual('');
    });
    it('should_return_empty_when_count_zero', 0, () => {
      expect(NECommonUtils.shortName('hello', 0)).assertEqual('');
    });
    it('should_return_tail_truncated', 0, () => {
      expect(NECommonUtils.shortName('hello', 2)).assertEqual('lo');
      expect(NECommonUtils.shortName('hello', 3)).assertEqual('llo');
    });
    it('should_use_default_count_two', 0, () => {
      expect(NECommonUtils.shortName('hello')).assertEqual('lo');
    });
    // shortName edge: name shorter than count
    it('should_return_full_name_when_shorter_than_count', 0, () => {
      expect(NECommonUtils.shortName('ab', 5)).assertEqual('ab');
    });
    // shortName edge: single character with default count
    it('should_return_single_char_with_default_count', 0, () => {
      expect(NECommonUtils.shortName('a')).assertEqual('a');
    });
    // shortName edge: count equals exactly name length
    it('should_return_full_when_count_equals_length', 0, () => {
      expect(NECommonUtils.shortName('hello', 5)).assertEqual('hello');
    });
    // shortName edge: count greater than name length
    it('should_return_full_when_count_exceeds_length', 0, () => {
      expect(NECommonUtils.shortName('hi', 10)).assertEqual('hi');
    });
  });

  describe('NECommonUtils_showToast', () => {
    it('should_not_throw_with_valid_message', 0, () => {
      NECommonUtils.showToast('test message');
      expect(true).assertTrue();
    });

    it('should_not_throw_with_default_alignment', 0, () => {
      NECommonUtils.showToast('hello');
      expect(true).assertTrue();
    });
  });

  describe('BreakPointType', () => {
    it('should_getValue_return_correct_value', 0, () => {
      let bp: BreakPointType<string> = new BreakPointType<string>(makeStrOpts());
      expect(bp.getValue('sm')).assertEqual('small');
      expect(bp.getValue('md')).assertEqual('medium');
    });
    it('should_handle_number_generic', 0, () => {
      let bp: BreakPointType<number> = new BreakPointType<number>(makeNumOpts());
      expect(bp.getValue('sm')).assertEqual(12);
      expect(bp.getValue('md')).assertEqual(15);
    });
    // BreakPointType: lg, xl, xxl keys
    it('should_getValue_return_for_lg_xl_xxl_string', 0, () => {
      let bp: BreakPointType<string> = new BreakPointType<string>(makeStrOpts());
      expect(bp.getValue('lg')).assertEqual('large');
      expect(bp.getValue('xl')).assertEqual('extra');
      expect(bp.getValue('xxl')).assertEqual('huge');
    });
    // BreakPointType: lg, xl, xxl number
    it('should_getValue_return_for_lg_xl_xxl_number', 0, () => {
      let bp: BreakPointType<number> = new BreakPointType<number>(makeNumOpts());
      expect(bp.getValue('lg')).assertEqual(4);
      expect(bp.getValue('xl')).assertEqual(8);
      expect(bp.getValue('xxl')).assertEqual(12);
    });
    // BreakPointType: non-existent key returns undefined
    it('should_getValue_return_undefined_for_missing_key', 0, () => {
      let bp: BreakPointType<string> = new BreakPointType<string>(makeStrOpts());
      let result: string = bp.getValue('nonexistent');
      expect(result === undefined).assertTrue();
    });
    // BreakPointType: access options property directly
    it('should_have_options_property_accessible', 0, () => {
      let bp: BreakPointType<string> = new BreakPointType<string>(makeStrOpts());
      expect(bp.options['sm'] === 'small').assertTrue();
      expect(bp.options['md'] === 'medium').assertTrue();
    });
  });

  describe('TimeUtils_fillNum', () => {
    it('should_pad_single_digit', 0, () => {
      expect(fillNum(0)).assertEqual('00');
      expect(fillNum(5)).assertEqual('05');
      expect(fillNum(9)).assertEqual('09');
    });
    it('should_not_pad_double_digits', 0, () => {
      expect(fillNum(10)).assertEqual('10');
      expect(fillNum(59)).assertEqual('59');
    });
  });

  describe('TimeUtils_getTimeString', () => {
    it('should_format_zero_as_00_00', 0, () => {
      expect(getTimeString(0)).assertEqual('00:00');
      expect(getTimeString(undefined)).assertEqual('00:00');
    });
    it('should_format_seconds', 0, () => {
      expect(getTimeString(5000)).assertEqual('00:05');
      expect(getTimeString(30000)).assertEqual('00:30');
    });
    it('should_format_minutes_seconds', 0, () => {
      expect(getTimeString(65000)).assertEqual('01:05');
    });
    it('should_format_hours', 0, () => {
      expect(getTimeString(3600000)).assertEqual('01:00:00');
      expect(getTimeString(3661000)).assertEqual('01:01:01');
    });
    it('should_handle_large_hour_mod_24', 0, () => {
      expect(getTimeString(90000000)).assertEqual('01:00:00');
    });
  });
}
