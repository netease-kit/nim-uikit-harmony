/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMMessage } from '@nimsdk/base';
import { IsReceiveMsg, IsReceiveMsgOperation } from '../../../main/ets/model/IsReceiveMsg';

export default function IsReceiveMsgTest() {
  describe('IsReceiveMsgOperation', () => {
    it('should_have_expected_enum_values', 0, () => {
      expect(IsReceiveMsgOperation.ADD).assertEqual(0);
      expect(IsReceiveMsgOperation.DELETE).assertEqual(1);
    });
  });

  describe('IsReceiveMsg_constructor', () => {
    it('should_set_isReceiveMsg_true_with_messages', 0, () => {
      const msg = new IsReceiveMsg(true, [], IsReceiveMsgOperation.ADD);
      expect(msg.yes).assertTrue();
      expect(msg.no).assertFalse();
      expect(msg.count).assertEqual(0);
    });

    it('should_default_to_false_when_isReceiveMsg_false', 0, () => {
      const msg = new IsReceiveMsg(false);
      expect(msg.yes).assertFalse();
      expect(msg.no).assertTrue();
      expect(msg.count).assertEqual(0);
    });

    it('should_default_operation_to_ADD', 0, () => {
      const msg = new IsReceiveMsg(true);
      expect(msg.operation).assertEqual(IsReceiveMsgOperation.ADD);
    });

    it('should_set_properties_when_isReceiveMsg_true_and_messages_non_empty', 0, () => {
      const messages = [
        { messageClientId: 'test_msg_1' } as V2NIMMessage,
        { messageClientId: 'test_msg_2' } as V2NIMMessage
      ];
      const msg = new IsReceiveMsg(true, messages, IsReceiveMsgOperation.DELETE);
      expect(msg.yes).assertTrue();
      expect(msg.no).assertFalse();
      expect(msg.count).assertEqual(2);
      expect(msg.operation).assertEqual(IsReceiveMsgOperation.DELETE);
    });
  });
}
