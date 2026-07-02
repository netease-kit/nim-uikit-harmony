/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { CommonConstants, TranslationLanguageCode, SUPPORTED_TRANSLATION_LANGUAGES, AppLanguageCode } from '../../../main/ets/constants/CommonConstants';

export default function CommonConstantsTest() {
  describe('CommonConstants_KEYS_unique', () => {
    const allKeys = [
      CommonConstants.KEY_SETTING_EARPIECE_MODE,
      CommonConstants.KEY_SETTING_MESSAGE_READ_OR,
      CommonConstants.KEY_SETTING_LOCAL_CONVERSATION,
      CommonConstants.KEY_SETTING_SHOWN_ONLINE_STATE,
      CommonConstants.KEY_SETTING_ANTISPAM_TIP_MESSAGE,
      CommonConstants.KEY_SETTING_CLOUD_SEARCH,
      CommonConstants.KEY_SETTING_COLLECTION_ENABLE,
      CommonConstants.KEY_SETTING_PIN_ENABLE,
      CommonConstants.KEY_SETTING_TYPING_STATUS,
      CommonConstants.KEY_SETTING_ONLY_FRIEND_CALL,
      CommonConstants.KEY_SETTING_TEAM_JOIN_AGREE_MODE,
      CommonConstants.KEY_SETTING_TEAM_ENABLE,
      CommonConstants.KEY_SETTING_TOP_MESSAGE,
      CommonConstants.KEY_SETTING_AI_STREAM,
      CommonConstants.KEY_SETTING_RICH_TEXT_MESSAGE,
      CommonConstants.KEY_SETTING_TEAM_MANAGER_MAX_COUNT,
      CommonConstants.KEY_SETTING_READ_MESSAGE,
      CommonConstants.KEY_SETTING_PUSH_CONFIG_ENABLED,
      CommonConstants.KEY_SETTING_PUSH_CONFIG_CONTENT,
      CommonConstants.KEY_SETTING_NOTIFY_RING,
      CommonConstants.KEY_SETTING_NOTIFY_VIBRATE,
      CommonConstants.KEY_SETTING_AUTO_TRANSLATION_ENABLE_TIME,
      CommonConstants.KEY_SETTING_TRANSLATION_TARGET_LANGUAGE,
      CommonConstants.KEY_SETTING_APP_LANGUAGE,
    ];
    it('should_have_all_keys_non_empty', 0, () => {
      for (let key of allKeys) {
        expect(key.length > 0).assertTrue();
      }
    });
    it('should_have_unique_keys', 0, () => {
      let seen = new Set<string>();
      for (let key of allKeys) {
        expect(seen.has(key)).assertFalse();
        seen.add(key);
      }
    });
  });

  describe('CommonConstants_breakpoints', () => {
    it('should_have_increasing_breakpoint_sizes', 0, () => {
      expect(CommonConstants.BREAKPOINTS_SM_SIZE < CommonConstants.BREAKPOINTS_MD_SIZE).assertTrue();
      expect(CommonConstants.BREAKPOINTS_MD_SIZE < CommonConstants.BREAKPOINTS_LG_SIZE).assertTrue();
      expect(CommonConstants.BREAKPOINTS_LG_SIZE < CommonConstants.BREAKPOINTS_XL_SIZE).assertTrue();
    });
    it('should_have_breakpoint_names_non_empty', 0, () => {
      expect(CommonConstants.BREAKPOINTS_SM_NAME.length > 0).assertTrue();
      expect(CommonConstants.BREAKPOINTS_MD_NAME.length > 0).assertTrue();
      expect(CommonConstants.BREAKPOINTS_LG_NAME.length > 0).assertTrue();
      expect(CommonConstants.BREAKPOINTS_XL_NAME.length > 0).assertTrue();
    });
  });

  describe('TranslationLanguageCode', () => {
    it('should_have_all_members', 0, () => {
      expect(TranslationLanguageCode.ZH_CHS).assertEqual('zh-CHS');
      expect(TranslationLanguageCode.EN).assertEqual('en');
      expect(TranslationLanguageCode.JA).assertEqual('ja');
      expect(TranslationLanguageCode.KO).assertEqual('ko');
      expect(TranslationLanguageCode.FR).assertEqual('fr');
    });
    it('should_have_supported_list_non_empty', 0, () => {
      expect(SUPPORTED_TRANSLATION_LANGUAGES.length > 0).assertTrue();
    });
  });

  describe('AppLanguageCode', () => {
    it('should_have_expected_values', 0, () => {
      expect(AppLanguageCode.Auto).assertEqual('auto');
      expect(AppLanguageCode.ZhCN).assertEqual('zh-CN');
      expect(AppLanguageCode.EnUS).assertEqual('en-US');
    });
  });
}
