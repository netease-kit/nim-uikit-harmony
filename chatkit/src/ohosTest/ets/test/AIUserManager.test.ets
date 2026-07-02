/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  isAIChatUserByServerExtension, filterAIChatUsers,
  getAIWelcomeTextByServerExtension,
  AIUserManager
} from '../../../main/ets/manager/AIUserManager';
import { V2NIMAIUser } from '@nimsdk/base';

export default function AIUserManagerTest() {
  describe('isAIChatUserByServerExtension', () => {
    it('should_return_false_for_undefined', 0, () => {
      expect(isAIChatUserByServerExtension(undefined)).assertFalse();
    });
    it('should_return_false_for_empty_string', 0, () => {
      expect(isAIChatUserByServerExtension('')).assertFalse();
    });
    it('should_return_false_for_null_like', 0, () => {
      expect(isAIChatUserByServerExtension('null')).assertFalse();
    });
    it('should_return_true_for_aiChat_1', 0, () => {
      expect(isAIChatUserByServerExtension('{"aiChat":1}')).assertTrue();
    });
    it('should_return_true_for_aiChat_string_1', 0, () => {
      expect(isAIChatUserByServerExtension('{"aiChat":"1"}')).assertTrue();
    });
    it('should_return_false_for_aiChat_0', 0, () => {
      expect(isAIChatUserByServerExtension('{"aiChat":0}')).assertFalse();
    });
    it('should_return_true_for_legacy_key', 0, () => {
      expect(isAIChatUserByServerExtension('{"ai_chat":1}')).assertTrue();
    });
    it('should_return_false_for_other_keys', 0, () => {
      expect(isAIChatUserByServerExtension('{"other":1}')).assertFalse();
    });
    it('should_return_false_for_invalid_json', 0, () => {
      expect(isAIChatUserByServerExtension('{invalid}')).assertFalse();
    });
    it('should_return_false_for_array_json', 0, () => {
      expect(isAIChatUserByServerExtension('[1,2,3]')).assertFalse();
    });
  });

  describe('filterAIChatUsers', () => {
    it('should_return_empty_for_empty_array', 0, () => {
      const users: V2NIMAIUser[] = [];
      const result: V2NIMAIUser[] = filterAIChatUsers(users);
      expect(result.length).assertEqual(0);
    });
    it('should_filter_out_non_ai_users', 0, () => {
      const user1: V2NIMAIUser = JSON.parse(
        '{"accountId":"u1","name":"n1","serverExtension":"{\\"aiChat\\":1}","modelType":0,"aiModelType":0}'
      ) as V2NIMAIUser;
      const user2: V2NIMAIUser = JSON.parse(
        '{"accountId":"u2","name":"n2","serverExtension":"{}","modelType":0,"aiModelType":0}'
      ) as V2NIMAIUser;
      const users: V2NIMAIUser[] = [user1, user2];
      const result: V2NIMAIUser[] = filterAIChatUsers(users);
      expect(result.length).assertEqual(1);
      expect(result[0].accountId).assertEqual('u1');
    });
    it('should_filter_by_legacy_key', 0, () => {
      const user: V2NIMAIUser = JSON.parse(
        '{"accountId":"u3","name":"n3","serverExtension":"{\\"ai_chat\\":\\"1\\"}","modelType":0,"aiModelType":0}'
      ) as V2NIMAIUser;
      const users: V2NIMAIUser[] = [user];
      const result: V2NIMAIUser[] = filterAIChatUsers(users);
      expect(result.length).assertEqual(1);
    });
  });

  describe('AIUserManager', () => {
    it('should_getAITranslateLanguages_empty_when_no_provider', 0, () => {
      AIUserManager.setProvider(undefined);
      const result: string[] = AIUserManager.getAITranslateLanguages();
      expect(result.length).assertEqual(0);
    });
    it('should_isAIUser_return_false_for_empty', 0, () => {
      expect(AIUserManager.isAIUser(undefined)).assertFalse();
      expect(AIUserManager.isAIUser('')).assertFalse();
    });
    it('should_isAIChatUser_return_false_for_empty', 0, () => {
      expect(AIUserManager.isAIChatUser(undefined)).assertFalse();
      expect(AIUserManager.isAIChatUser('')).assertFalse();
    });
    it('should_setAIUserAgentProvider_delegate_to_setProvider', 0, () => {
      AIUserManager.setAIUserAgentProvider(undefined);
      const result: string[] = AIUserManager.getAITranslateLanguages();
      expect(result.length).assertEqual(0);
    });
    it('should_read_welcome_text_from_server_extension', 0, () => {
      const result: string = getAIWelcomeTextByServerExtension('{"welcomeText":"欢迎来到魔法世界"}');

      expect(result).assertEqual('欢迎来到魔法世界');
    });
    it('should_keep_welcome_text_original_value', 0, () => {
      const result: string = getAIWelcomeTextByServerExtension('{"welcomeText":"  欢迎来到魔法世界  "}');

      expect(result).assertEqual('  欢迎来到魔法世界  ');
    });
  });
}
