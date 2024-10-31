/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { pinyin4js } from '@ohos/pinyin4js';

/// 获取通讯录索引
/// ("你好" -> "nĭ hăo" ->) "ni hao" -> "NI HAO" -> "N"
export async function initalLetter(string: string): Promise<string> {
  /** 使用convertToPinyinString方法将汉字转换成拼音字母。
   其中参数1为待转数据，参数2为拼音间隔字符，参数3设置是否带声调符号。
   */
  const pinyin: string = pinyin4js.convertToPinyinString(string, '', pinyin4js.WITHOUT_TONE);
  if (pinyin.length > 0) {
    return pinyin.toUpperCase()[0]
  }
  return ''
}

/// 判断字符串是否为空
export function StringIsEmpty(str?: string | null) {
  return str === null || str === undefined || str.trim().length === 0;
}

/// 字符串尾部截取
/// - Parameter count: 尾部截取长度
export function TailString(string?: string, count: number = 2): string {
  if (string) {
    const start: number = (string.length - count) > 0 ? string.length - count : 0
    const end: number = string.length
    return string.substring(start, end)
  }
  return ""
}

/**
 * 获取未读数展示
 * @param unreadCount
 * @returns
 */
export function GetUnreadCountStr(unreadCount: number): string {
  if (unreadCount < 100) {
    return `${unreadCount}`
  } else {
    return '99+'
  }
}