/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { CustomMessageUtils } from '../../../main/ets/utils/CustomMessageUtils';
import { V2NIMMessageAttachment } from '@nimsdk/base';

function mockAttachment(rawStr: string): V2NIMMessageAttachment {
  const att: V2NIMMessageAttachment = new Object() as V2NIMMessageAttachment;
  att.raw = rawStr;
  return att;
}

export default function CustomMessageUtilsTest() {
  describe('CustomMessageUtils_attachmentOfCustomMessage', () => {
    it('should_parse_valid_json', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{"type":101,"data":"test"}');
      const result = CustomMessageUtils.attachmentOfCustomMessage(att);
      expect(result !== undefined).assertTrue();
    });

    it('should_return_undefined_for_invalid_json', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{invalid}');
      expect(CustomMessageUtils.attachmentOfCustomMessage(att)).assertUndefined();
    });

    it('should_return_undefined_for_no_raw', 0, () => {
      const att: V2NIMMessageAttachment = new Object() as V2NIMMessageAttachment;
      expect(CustomMessageUtils.attachmentOfCustomMessage(att)).assertUndefined();
    });
  });

  describe('CustomMessageUtils_typeOfCustomMessage', () => {
    it('should_extract_type', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{"type":101}');
      expect(CustomMessageUtils.typeOfCustomMessage(att)).assertEqual(101);
    });

    it('should_return_undefined_for_invalid', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{invalid}');
      expect(CustomMessageUtils.typeOfCustomMessage(att)).assertUndefined();
    });
  });

  describe('CustomMessageUtils_dataOfCustomMessage', () => {
    it('should_extract_data', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{"type":102,"data":"mydata"}');
      const result = CustomMessageUtils.dataOfCustomMessage(att);
      expect(result !== undefined).assertTrue();
    });
  });

  describe('CustomMessageUtils_heightOfCustomMessage', () => {
    it('should_extract_customHeight', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{"type":101,"customHeight":130}');
      expect(CustomMessageUtils.heightOfCustomMessage(att)).assertEqual(130);
    });

    it('should_return_undefined_for_invalid', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{invalid}');
      expect(CustomMessageUtils.heightOfCustomMessage(att)).assertUndefined();
    });
  });

  describe('CustomMessageUtils_isUnknownMessage', () => {
    it('should_return_false_for_merged_message', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{"type":101}');
      expect(CustomMessageUtils.isUnknownMessage(att)).assertFalse();
    });

    it('should_return_true_for_other_type', 0, () => {
      const att: V2NIMMessageAttachment = mockAttachment('{"type":999}');
      expect(CustomMessageUtils.isUnknownMessage(att)).assertTrue();
    });

    it('should_return_false_for_undefined', 0, () => {
      expect(CustomMessageUtils.isUnknownMessage(undefined)).assertFalse();
    });
  });
}
