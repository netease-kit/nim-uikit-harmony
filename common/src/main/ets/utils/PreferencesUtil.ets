/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import common from '@ohos.app.ability.common';
import { preferences } from '@kit.ArkData';

let preference: preferences.Preferences | undefined = undefined
const context = getContext(this) as common.UIAbilityContext

export class PreferencesUtil {
  private readonly TAG: string = 'net ease PreferenceUtil';

  writeString(key: string, value?: string) {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.putSync(key, value)
    } catch (e) {
      console.error(this.TAG, 'Failed to write value, cause:' + e)
    }
    preference!!.flush()
  }

  readString(key: string, defaultValue?: string): string | undefined {
    if (preference === undefined) {
      this.getPreferences()
    }
    let value: preferences.ValueType | undefined = undefined
    try {
      value = preference!!.getSync(key, defaultValue)
    } catch (e) {
      console.error(this.TAG, 'Failed to read value, cause:' + e)
    }
    return value as string | undefined
  }

  writeArrayString(key: string, value?: Array<string>) {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.putSync(key, value)
    } catch (e) {
      console.error(this.TAG, 'Failed to write value, cause:' + e)
    }
    preference!!.flush()
  }

  readArrayString(key: string, defaultValue?: Array<string>): Array<string> | undefined {
    if (preference === undefined) {
      this.getPreferences()
    }
    let value: preferences.ValueType | undefined = undefined
    try {
      value = preference!!.getSync(key, defaultValue)
    } catch (e) {
      console.error(this.TAG, 'Failed to read value, cause:' + e)
    }
    return value as Array<string> | undefined
  }

  writeNumber(key: string, value?: number) {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.putSync(key, value)
    } catch (e) {
      console.error(this.TAG, 'Failed to write value, cause:' + e)
    }
    preference!!.flush()
  }

  readNumber(key: string, defaultValue?: number): number | undefined {
    if (preference === undefined) {
      this.getPreferences()
    }
    let value: preferences.ValueType | undefined = undefined
    try {
      value = preference!!.getSync(key, defaultValue)
    } catch (e) {
      console.error(this.TAG, 'Failed to read value, cause:' + e)
    }
    return value as number | undefined
  }

  writeArrayNumber(key: string, value?: Array<number>) {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.putSync(key, value)
    } catch (e) {
      console.error(this.TAG, 'Failed to write value, cause:' + e)
    }
    preference!!.flush()
  }

  readArrayNumber(key: string, defaultValue?: Array<number>): Array<number> | undefined {
    if (preference === undefined) {
      this.getPreferences()
    }
    let value: preferences.ValueType | undefined = undefined
    try {
      value = preference!!.getSync(key, defaultValue)
    } catch (e) {
      console.error(this.TAG, 'Failed to read value, cause:' + e)
    }
    return value as Array<number> | undefined
  }

  writeBoolean(key: string, value?: boolean) {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.putSync(key, value)
    } catch (e) {
      console.error(this.TAG, 'Failed to write value, cause:' + e)
    }
    preference!!.flush()
  }

  readBoolean(key: string, defaultValue?: boolean): boolean | undefined {
    if (preference === undefined) {
      this.getPreferences()
    }
    let value: preferences.ValueType | undefined = undefined
    try {
      value = preference!!.getSync(key, defaultValue)
    } catch (e) {
      console.error(this.TAG, 'Failed to read value, cause:' + e)
    }
    return value as boolean | undefined
  }

  writeArrayBoolean(key: string, value?: Array<boolean>) {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.putSync(key, value)
    } catch (e) {
      console.error(this.TAG, 'Failed to write value, cause:' + e)
    }
    preference!!.flush()
  }

  readArrayBoolean(key: string, defaultValue?: Array<boolean>): Array<boolean> | undefined {
    if (preference === undefined) {
      this.getPreferences()
    }
    let value: preferences.ValueType | undefined = undefined
    try {
      value = preference!!.getSync(key, defaultValue)
    } catch (e) {
      console.error(this.TAG, 'Failed to read value, cause:' + e)
    }
    return value as Array<boolean> | undefined
  }

  writeObject(key: string, value?: object) {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.putSync(key, value)
    } catch (e) {
      console.error(this.TAG, 'Failed to write value, cause:' + e)
    }
    preference!!.flush()
  }

  readObject<T>(key: string): T | undefined {
    if (preference === undefined) {
      this.getPreferences()
    }
    let value: preferences.ValueType | undefined = undefined
    try {
      value = preference!!.getSync(key, undefined)
    } catch (e) {
      console.error(this.TAG, 'Failed to read value, cause:' + e)
    }
    if (value === undefined) {
      return undefined
    } else {
      return value as T
    }
  }

  delete(key: string) {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.deleteSync(key)
    } catch (e) {
      console.error(this.TAG, 'Failed to delete, cause:' + e)
    }
    preference!!.flush()
  }

  clear() {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.clearSync()
    } catch (e) {
      console.error(this.TAG, 'Failed to clear, cause:' + e)
    }
    preference!!.flush()
  }

  flush() {
    if (preference === undefined) {
      this.getPreferences()
    }
    try {
      preference!!.flush()
    } catch (e) {
      console.error(this.TAG, 'Failed to flush, cause:' + e)
    }
  }

  private getPreferences() {
    try {

      let options: preferences.Options = { name: 'myStore' };
      preference = preferences.getPreferencesSync(context, options);
    } catch (e) {
      console.error(this.TAG, 'Failed to get preferences, cause:' + e)
    }
  }

  private deletePreferences() {
    try {
      preference?.deleteSync('myStore')
    } catch (e) {
      console.error(this.TAG, 'Failed to delete preferences, cause:' + e)
    }
    preference = undefined
  }
}

export default new PreferencesUtil()