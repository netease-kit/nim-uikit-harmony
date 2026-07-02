/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { AppLanguageCode } from '../../../main/ets/constants/CommonConstants';
import { normalizeAppLanguage, resolveEffectiveAppLanguage, isEnglishSystemLanguage } from '../../../main/ets/utils/AppLanguageUtils';
import { NECommonUtils } from '../../../main/ets/utils/NECommonUtils';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('should_prefer_app_language_over_system_language', 0, () => {
      expect(resolveEffectiveAppLanguage(AppLanguageCode.ZhCN, 'en-US')).assertEqual(AppLanguageCode.ZhCN)
      expect(resolveEffectiveAppLanguage(AppLanguageCode.EnUS, 'zh-CN')).assertEqual(AppLanguageCode.EnUS)
    });

    it('should_fall_back_to_system_english_when_app_language_is_default', 0, () => {
      expect(resolveEffectiveAppLanguage(AppLanguageCode.Auto, 'en-US')).assertEqual(AppLanguageCode.EnUS)
      expect(resolveEffectiveAppLanguage(undefined, 'en-GB')).assertEqual(AppLanguageCode.EnUS)
    });

    it('should_default_to_chinese_when_app_language_and_system_language_are_not_english', 0, () => {
      expect(resolveEffectiveAppLanguage(AppLanguageCode.Auto, 'zh-CN')).assertEqual(AppLanguageCode.ZhCN)
      expect(resolveEffectiveAppLanguage(undefined, '')).assertEqual(AppLanguageCode.ZhCN)
    });

    it('should_normalize_invalid_app_language_to_default', 0, () => {
      expect(normalizeAppLanguage('default')).assertEqual(AppLanguageCode.Auto)
      expect(normalizeAppLanguage('zh')).assertEqual(AppLanguageCode.Auto)
      expect(normalizeAppLanguage('')).assertEqual(AppLanguageCode.Auto)
    });

    // ---- isEnglishSystemLanguage 边界 ----
    it('should_detect_english_system_language_case_insensitive', 0, () => {
      expect(isEnglishSystemLanguage('en-US')).assertTrue();
      expect(isEnglishSystemLanguage('en-GB')).assertTrue();
      expect(isEnglishSystemLanguage('EN')).assertTrue();
      expect(isEnglishSystemLanguage('en')).assertTrue();
    });

    it('should_reject_non_english_system_language', 0, () => {
      expect(isEnglishSystemLanguage('zh-CN')).assertFalse();
      expect(isEnglishSystemLanguage('ja-JP')).assertFalse();
      expect(isEnglishSystemLanguage('')).assertFalse();
    });

    // ---- NECommonUtils.shortName ----
    it('should_return_tail_truncated_name', 0, () => {
      expect(NECommonUtils.shortName('hello', 2)).assertEqual('lo');
      expect(NECommonUtils.shortName('hello', 3)).assertEqual('llo');
    });

    it('should_return_full_if_shorter_than_count', 0, () => {
      expect(NECommonUtils.shortName('ab', 5)).assertEqual('ab');
    });

    it('should_return_empty_for_undefined_name', 0, () => {
      expect(NECommonUtils.shortName(undefined)).assertEqual('');
    });
  });
}
