/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  mergedMessageNickKey, mergedMessageAvatarKey, multiForwardFileName,
  mergedMessageMaxDepth, mergedMessageLimitCount, singleMessageLimitCount,
  deleteMessagesLimitCount, mergedMessageCustomType, multiLineMessageCustomType,
  mergedMessageCellHeight, conversationSelectLimitCount,
  keyExtensionAtAll, typeExtensionAllowAll, typeExtensionAllowManager,
  keyExtensionTopSticky, keyExtensionSticky,
  typeExtensionStickyAdd, typeExtensionStickyRemove,
  collectionTypeOffset, keyReplyMsgKey, subscriptionOnlineStateDuration
} from '../../../main/ets/constant/Constant';

export default function ConstantTest() {
  describe('merged_message_keys', () => {
    it('should_have_non_empty_keys', 0, () => {
      expect(mergedMessageNickKey.length > 0).assertTrue();
      expect(mergedMessageAvatarKey.length > 0).assertTrue();
      expect(multiForwardFileName.length > 0).assertTrue();
    });
  });

  describe('merged_message_limits', () => {
    it('should_have_reasonable_values', 0, () => {
      expect(mergedMessageMaxDepth > 0).assertTrue();
      expect(mergedMessageLimitCount > 0).assertTrue();
      expect(singleMessageLimitCount > 0).assertTrue();
      expect(deleteMessagesLimitCount > 0).assertTrue();
      expect(mergedMessageCellHeight > 0).assertTrue();
      expect(mergedMessageCustomType > 0).assertTrue();
      expect(multiLineMessageCustomType > 0).assertTrue();
      expect(conversationSelectLimitCount > 0).assertTrue();
    });
  });

  describe('extension_keys', () => {
    it('should_have_non_empty_keys', 0, () => {
      expect(keyExtensionAtAll.length > 0).assertTrue();
      expect(keyExtensionTopSticky.length > 0).assertTrue();
      expect(keyExtensionSticky.length > 0).assertTrue();
    });
    it('should_have_distinct_allow_values', 0, () => {
      expect(typeExtensionAllowAll !== typeExtensionAllowManager).assertTrue();
    });
  });

  describe('sticky_operations', () => {
    it('should_have_distinct_values', 0, () => {
      expect(typeExtensionStickyAdd !== typeExtensionStickyRemove).assertTrue();
    });
  });

  describe('other_constants', () => {
    it('should_have_reasonable_values', 0, () => {
      expect(collectionTypeOffset > 0).assertTrue();
      expect(keyReplyMsgKey.length > 0).assertTrue();
      expect(subscriptionOnlineStateDuration > 0).assertTrue();
    });
  });
}
