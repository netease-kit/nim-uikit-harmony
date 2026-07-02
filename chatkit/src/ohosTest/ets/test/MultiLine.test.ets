/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { parseMultiLineAttachment, createMultiLineAttachment, normalizeMultiLineTitle, MULTI_LINE_TITLE_MAX_LENGTH } from '../../../main/ets/model/MultiLineAttachment';

export default function MultiLineTest() {
  describe('normalizeMultiLineTitle', () => {
    it('should_remove_newlines', 0, () => {
      expect(normalizeMultiLineTitle('a\nb')).assertEqual('ab');
    });
    it('should_truncate_to_max_length', 0, () => {
      const long: string = '12345678901234567890123';
      const result: string = normalizeMultiLineTitle(long);
      expect(result.length <= MULTI_LINE_TITLE_MAX_LENGTH).assertTrue();
    });
    it('should_return_empty_for_empty', 0, () => {
      expect(normalizeMultiLineTitle('')).assertEqual('');
    });
    it('should_remove_crlf', 0, () => {
      expect(normalizeMultiLineTitle('a\r\nb')).assertEqual('ab');
    });
  });

  describe('parseMultiLineAttachment', () => {
    it('should_parse_valid', 0, () => {
      const str: string = createMultiLineAttachment('T', 'B');
      const result = parseMultiLineAttachment(str);
      expect(result !== null).assertTrue();
      if (result !== null) {
        expect(result.data.title).assertEqual('T');
        expect(result.data.body).assertEqual('B');
      }
    });
    it('should_return_null_for_undefined', 0, () => {
      expect(parseMultiLineAttachment(undefined)).assertNull();
    });
    it('should_return_null_for_invalid_json', 0, () => {
      expect(parseMultiLineAttachment('{invalid}')).assertNull();
    });
    it('should_return_null_for_wrong_type', 0, () => {
      expect(parseMultiLineAttachment('{"type":999}')).assertNull();
    });
    it('should_return_null_for_missing_data', 0, () => {
      expect(parseMultiLineAttachment('{"type":102}')).assertNull();
    });
  });

  describe('createMultiLineAttachment', () => {
    it('should_create_valid_json', 0, () => {
      const str: string = createMultiLineAttachment('T', 'B');
      const parsed = parseMultiLineAttachment(str);
      expect(parsed !== null).assertTrue();
    });
    it('should_normalize_title', 0, () => {
      const str: string = createMultiLineAttachment('a\nb\nc', 'body');
      const parsed = parseMultiLineAttachment(str);
      if (parsed !== null) {
        expect(parsed.data.title).assertEqual('abc');
      }
    });
  });

  // isMultiLineMessage/getMultiLineTitle/getMultiLineBody/getMultiLinePreview
  // 依赖 V2NIMMessage 类型，ArkTS 不允许 Record 转 V2NIMMessage
  // 这些函数需在 IDE ohosTest 设备环境通过真实消息对象测试
}
