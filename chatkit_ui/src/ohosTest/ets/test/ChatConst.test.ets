/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { ChatConst } from '../../../main/ets/constants/ChatConst';

export default function ChatConstTest() {
  describe('ChatConst_page_sizes', () => {
    it('should_have_reasonable_message_page_size', 0, () => {
      expect(ChatConst.chatMessagePageSize > 0).assertTrue();
    });
    it('should_have_reasonable_message_delete_limit', 0, () => {
      expect(ChatConst.messageDeleteLimit > 0).assertTrue();
    });
  });

  describe('ChatConst_dimensions', () => {
    it('should_have_positive_image_dimensions', 0, () => {
      expect(ChatConst.imageMessageHeight > 0).assertTrue();
      expect(ChatConst.imageMessageWidth > 0).assertTrue();
    });
    it('should_have_positive_merged_message_dimensions', 0, () => {
      expect(ChatConst.mergedMessageHeight > 0).assertTrue();
      expect(ChatConst.mergedMessageMinHeight > 0).assertTrue();
    });
    it('should_have_positive_line_heights', 0, () => {
      expect(ChatConst.messageLineHeight > 0).assertTrue();
      expect(ChatConst.textLineHeight > 0).assertTrue();
    });
    it('should_have_positive_menu_dimensions', 0, () => {
      expect(ChatConst.menuItemWidth > 0).assertTrue();
      expect(ChatConst.menuItemHeight > 0).assertTrue();
      expect(ChatConst.menuItemColumnNum > 0).assertTrue();
    });
    it('should_have_positive_font_size', 0, () => {
      expect(ChatConst.messageTextFontSize > 0).assertTrue();
    });
  });

  describe('ChatConst_revoke_keys', () => {
    it('should_have_non_empty_revoke_keys', 0, () => {
      expect(ChatConst.revokeLocalKey.length > 0).assertTrue();
      expect(ChatConst.revokeLocalTimeKey.length > 0).assertTrue();
      expect(ChatConst.revokeMsgClientIdKey.length > 0).assertTrue();
      expect(ChatConst.revokeMsgTextKey.length > 0).assertTrue();
      expect(ChatConst.revokeMsgEditKey.length > 0).assertTrue();
      expect(ChatConst.revokeMsgAttachmentKey.length > 0).assertTrue();
    });
    it('should_have_unique_revoke_keys', 0, () => {
      const keys: string[] = [
        ChatConst.revokeLocalKey,
        ChatConst.revokeLocalTimeKey,
        ChatConst.revokeMsgClientIdKey,
        ChatConst.revokeMsgTextKey,
        ChatConst.revokeMsgEditKey,
        ChatConst.revokeMsgAttachmentKey,
      ];
      const seen = new Set<string>();
      for (let i = 0; i < keys.length; i++) {
        expect(seen.has(keys[i])).assertFalse();
        seen.add(keys[i]);
      }
    });
  });
}
