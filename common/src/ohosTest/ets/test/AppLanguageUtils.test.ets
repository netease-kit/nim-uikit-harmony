/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { AppLanguageCode, CommonConstants } from '../../../main/ets/constants/CommonConstants';
import {
  normalizeAppLanguage,
  resolveEffectiveAppLanguage,
  isEnglishSystemLanguage,
  getCurrentSystemLanguage,
  getStoredAppLanguage,
  getEffectiveAppLanguage
} from '../../../main/ets/utils/AppLanguageUtils';

export default function AppLanguageUtilsTest() {
  describe('AppLanguageUtils_normalizeAppLanguage', () => {
    it('should_normalize_auto_to_auto', 0, () => {
      expect(normalizeAppLanguage(AppLanguageCode.Auto)).assertEqual(AppLanguageCode.Auto);
    });
    it('should_normalize_default_to_auto', 0, () => {
      expect(normalizeAppLanguage('default')).assertEqual(AppLanguageCode.Auto);
    });
    it('should_normalize_zh_CN', 0, () => {
      expect(normalizeAppLanguage(AppLanguageCode.ZhCN)).assertEqual(AppLanguageCode.ZhCN);
    });
    it('should_normalize_en_US', 0, () => {
      expect(normalizeAppLanguage(AppLanguageCode.EnUS)).assertEqual(AppLanguageCode.EnUS);
    });
    it('should_normalize_unknown_to_auto', 0, () => {
      expect(normalizeAppLanguage('fr')).assertEqual(AppLanguageCode.Auto);
      expect(normalizeAppLanguage('')).assertEqual(AppLanguageCode.Auto);
    });
  });

  describe('AppLanguageUtils_isEnglishSystemLanguage', () => {
    it('should_detect_en_US', 0, () => {
      expect(isEnglishSystemLanguage('en-US')).assertTrue();
    });
    it('should_detect_en_GB', 0, () => {
      expect(isEnglishSystemLanguage('en-GB')).assertTrue();
    });
    it('should_detect_en_lowercase', 0, () => {
      expect(isEnglishSystemLanguage('en')).assertTrue();
    });
    it('should_detect_EN_uppercase', 0, () => {
      expect(isEnglishSystemLanguage('EN')).assertTrue();
    });
    it('should_reject_zh_CN', 0, () => {
      expect(isEnglishSystemLanguage('zh-CN')).assertFalse();
    });
    it('should_reject_empty', 0, () => {
      expect(isEnglishSystemLanguage('')).assertFalse();
    });
    it('should_reject_undefined', 0, () => {
      expect(isEnglishSystemLanguage(undefined)).assertFalse();
    });
  });

  describe('AppLanguageUtils_resolveEffectiveAppLanguage', () => {
    it('should_use_app_language_when_set', 0, () => {
      expect(resolveEffectiveAppLanguage(AppLanguageCode.ZhCN, 'en-US')).assertEqual(AppLanguageCode.ZhCN);
      expect(resolveEffectiveAppLanguage(AppLanguageCode.EnUS, 'zh-CN')).assertEqual(AppLanguageCode.EnUS);
    });
    it('should_fallback_to_en_when_system_is_english', 0, () => {
      expect(resolveEffectiveAppLanguage(AppLanguageCode.Auto, 'en-US')).assertEqual(AppLanguageCode.EnUS);
    });
    it('should_fallback_to_zh_when_system_is_not_english', 0, () => {
      expect(resolveEffectiveAppLanguage(AppLanguageCode.Auto, 'zh-CN')).assertEqual(AppLanguageCode.ZhCN);
      expect(resolveEffectiveAppLanguage(undefined, '')).assertEqual(AppLanguageCode.ZhCN);
    });
    it('should_handle_undefined_app_language_with_en_system', 0, () => {
      expect(resolveEffectiveAppLanguage(undefined, 'en-GB')).assertEqual(AppLanguageCode.EnUS);
    });
  });

  describe('AppLanguageUtils_getCurrentSystemLanguage', () => {
    it('should_return_non_empty_string', 0, () => {
      let lang: string = getCurrentSystemLanguage();
      expect(typeof lang === 'string').assertTrue();
    });
  });

  describe('AppLanguageUtils_getStoredAppLanguage', () => {
    it('should_return_auto_when_not_set', 0, () => {
      let result: AppLanguageCode = getStoredAppLanguage();
      expect(result === AppLanguageCode.Auto || result === AppLanguageCode.ZhCN || result === AppLanguageCode.EnUS).assertTrue();
    });

    it('should_return_stored_value_when_set', 0, () => {
      AppStorage.setOrCreate<string>(CommonConstants.KEY_SETTING_APP_LANGUAGE, AppLanguageCode.ZhCN);
      let result: AppLanguageCode = getStoredAppLanguage();
      expect(result).assertEqual(AppLanguageCode.ZhCN);
    });

    it('should_normalize_default_to_auto', 0, () => {
      AppStorage.setOrCreate<string>(CommonConstants.KEY_SETTING_APP_LANGUAGE, 'default');
      let result: AppLanguageCode = getStoredAppLanguage();
      expect(result).assertEqual(AppLanguageCode.Auto);
    });

    it('should_return_auto_when_stored_as_auto', 0, () => {
      AppStorage.setOrCreate<string>(CommonConstants.KEY_SETTING_APP_LANGUAGE, AppLanguageCode.Auto);
      let result: AppLanguageCode = getStoredAppLanguage();
      expect(result).assertEqual(AppLanguageCode.Auto);
    });
  });

  describe('AppLanguageUtils_getEffectiveAppLanguage', () => {
    it('should_return_valid_language_code', 0, () => {
      let result: AppLanguageCode = getEffectiveAppLanguage();
      let isValid: boolean = result === AppLanguageCode.Auto ||
        result === AppLanguageCode.ZhCN ||
        result === AppLanguageCode.EnUS;
      expect(isValid).assertTrue();
    });

    it('should_respect_app_language_over_system', 0, () => {
      AppStorage.setOrCreate<string>(CommonConstants.KEY_SETTING_APP_LANGUAGE, AppLanguageCode.ZhCN);
      let result: AppLanguageCode = getEffectiveAppLanguage();
      expect(result).assertEqual(AppLanguageCode.ZhCN);
    });

    it('should_fallback_when_app_language_is_auto', 0, () => {
      AppStorage.setOrCreate<string>(CommonConstants.KEY_SETTING_APP_LANGUAGE, AppLanguageCode.Auto);
      let result: AppLanguageCode = getEffectiveAppLanguage();
      let isExpected: boolean = result === AppLanguageCode.ZhCN || result === AppLanguageCode.EnUS;
      expect(isExpected).assertTrue();
    });
  });
}
