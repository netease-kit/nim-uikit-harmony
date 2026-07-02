/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import i18n from '@ohos.i18n'
import { AppLanguageCode, CommonConstants } from '../constants/CommonConstants'

export function normalizeAppLanguage(language?: string): AppLanguageCode {
  if (language === 'default' || language === AppLanguageCode.Auto) {
    return AppLanguageCode.Auto
  }
  if (language === AppLanguageCode.ZhCN) {
    return AppLanguageCode.ZhCN
  }
  if (language === AppLanguageCode.EnUS) {
    return AppLanguageCode.EnUS
  }
  return AppLanguageCode.Auto
}

export function isEnglishSystemLanguage(language?: string): boolean {
  if (!language || language.length === 0) {
    return false
  }
  return language.toLowerCase().startsWith('en')
}

export function resolveEffectiveAppLanguage(appLanguage?: string, systemLanguage?: string): AppLanguageCode {
  const normalizedAppLanguage = normalizeAppLanguage(appLanguage)
  if (normalizedAppLanguage !== AppLanguageCode.Auto) {
    return normalizedAppLanguage
  }
  if (isEnglishSystemLanguage(systemLanguage)) {
    return AppLanguageCode.EnUS
  }
  return AppLanguageCode.ZhCN
}

export function getCurrentSystemLanguage(): string {
  try {
    return i18n.System.getSystemLanguage()
  } catch (e) {
    console.warn(`getCurrentSystemLanguage failed: ${e}`)
    return ''
  }
}

export function getStoredAppLanguage(): AppLanguageCode {
  return normalizeAppLanguage(AppStorage.get<string>(CommonConstants.KEY_SETTING_APP_LANGUAGE))
}

export function getEffectiveAppLanguage(): AppLanguageCode {
  return resolveEffectiveAppLanguage(getStoredAppLanguage(), getCurrentSystemLanguage())
}
