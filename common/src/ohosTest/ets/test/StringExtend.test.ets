/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { StringIsEmpty, TailString, GetUnreadCountStr, initalLetter } from '../../../main/ets/extend/StringExtend';

export default function StringExtendTest() {
  describe('StringIsEmpty', () => {
    it('should_return_true_for_null', 0, () => {
      expect(StringIsEmpty(null)).assertTrue();
    });
    it('should_return_true_for_undefined', 0, () => {
      expect(StringIsEmpty(undefined)).assertTrue();
    });
    it('should_return_true_for_empty', 0, () => {
      expect(StringIsEmpty('')).assertTrue();
    });
    it('should_return_true_for_whitespace_only', 0, () => {
      expect(StringIsEmpty('   ')).assertTrue();
    });
    it('should_return_false_for_non_empty', 0, () => {
      expect(StringIsEmpty('hello')).assertFalse();
    });
    it('should_return_false_for_content_with_whitespace', 0, () => {
      expect(StringIsEmpty('  hello  ')).assertFalse();
    });
  });

  describe('TailString', () => {
    it('should_return_last_two_chars_by_default', 0, () => {
      expect(TailString('hello')).assertEqual('lo');
    });
    it('should_return_last_n_chars', 0, () => {
      expect(TailString('hello', 3)).assertEqual('llo');
    });
    it('should_return_full_if_shorter_than_count', 0, () => {
      expect(TailString('ab', 5)).assertEqual('ab');
    });
    it('should_return_empty_for_empty', 0, () => {
      expect(TailString('')).assertEqual('');
    });
    it('should_return_empty_for_undefined', 0, () => {
      expect(TailString(undefined)).assertEqual('');
    });
    it('should_return_last_one_char', 0, () => {
      expect(TailString('hello', 1)).assertEqual('o');
    });
    it('should_return_full_if_equal_to_count', 0, () => {
      expect(TailString('hello', 5)).assertEqual('hello');
    });
  });

  describe('GetUnreadCountStr', () => {
    it('should_return_0_for_zero', 0, () => {
      expect(GetUnreadCountStr(0)).assertEqual('0');
    });
    it('should_return_string_for_50', 0, () => {
      expect(GetUnreadCountStr(50)).assertEqual('50');
    });
    it('should_return_99_for_99', 0, () => {
      expect(GetUnreadCountStr(99)).assertEqual('99');
    });
    it('should_return_99plus_for_100', 0, () => {
      expect(GetUnreadCountStr(100)).assertEqual('99+');
    });
    it('should_return_99plus_for_large', 0, () => {
      expect(GetUnreadCountStr(9999)).assertEqual('99+');
    });
  });

  describe('initalLetter', () => {
    it('should_return_uppercase_letter_for_chinese', 0, () => {
      let result: string = initalLetter('你好');
      expect(result.length > 0).assertTrue();
      expect(result).assertEqual(result.toUpperCase());
    });

    it('should_return_first_letter_uppercase', 0, () => {
      let result: string = initalLetter('世界');
      let firstChar: string = result.charAt(0);
      expect(firstChar === firstChar.toUpperCase()).assertTrue();
    });

    it('should_return_non_empty_for_valid_chinese', 0, () => {
      let result: string = initalLetter('测试');
      expect(result.length).assertEqual(1);
    });

    it('should_return_uppercase_for_english_input', 0, () => {
      let result: string = initalLetter('hello');
      expect(result.length).assertEqual(1);
      expect(result).assertEqual('H');
    });

    it('should_return_empty_for_empty_string', 0, () => {
      let result: string = initalLetter('');
      expect(result).assertEqual('');
    });
  });
}
