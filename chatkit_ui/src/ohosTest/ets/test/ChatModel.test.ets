/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { NEChatMoreOperationType, NEChatMoreOperationData } from '../../../main/ets/model/NEChatMoreOperationData';
import { MessageOperationType, MessageOperationItem } from '../../../main/ets/model/MessageOperationItem';

export default function ChatModelTest() {
  describe('NEChatMoreOperationType', () => {
    it('should_have_all_expected_types', 0, () => {
      expect(NEChatMoreOperationType.Video).assertEqual(1);
      expect(NEChatMoreOperationType.File).assertEqual(2);
      expect(NEChatMoreOperationType.Location).assertEqual(3);
      expect(NEChatMoreOperationType.Call).assertEqual(4);
      expect(NEChatMoreOperationType.Translate).assertEqual(5);
    });
  });

  describe('NEChatMoreOperationData', () => {
    it('should_have_default_undefined_fields', 0, () => {
      const data = new NEChatMoreOperationData();
      expect(data.type === undefined).assertTrue();
      expect(data.operationTitle === undefined).assertTrue();
      expect(data.imageSource === undefined).assertTrue();
    });
  });

  describe('MessageOperationType', () => {
    it('should_have_unique_values', 0, () => {
      const values = [
        MessageOperationType.Delete,
        MessageOperationType.Copy,
        MessageOperationType.Undo,
        MessageOperationType.Forward,
        MessageOperationType.Pin,
        MessageOperationType.Unpin,
        MessageOperationType.Select,
        MessageOperationType.Collection,
        MessageOperationType.Reply,
        MessageOperationType.VoicePlayMode,
        MessageOperationType.TopSticky,
        MessageOperationType.UnTopSticky,
        MessageOperationType.VoiceToText,
        MessageOperationType.Translate,
        MessageOperationType.HideTranslation,
        MessageOperationType.AISearch,
      ];
      const seen = new Set<number>();
      for (let i = 0; i < values.length; i++) {
        expect(seen.has(values[i])).assertFalse();
        seen.add(values[i]);
      }
    });
  });

  describe('MessageOperationItem', () => {
    it('should_default_operationType_to_Delete', 0, () => {
      const item = new MessageOperationItem();
      expect(item.operationType).assertEqual(MessageOperationType.Delete);
    });
  });
}
