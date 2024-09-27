/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { systemDateTime } from '@kit.BasicServicesKit';

export class DateUtils {
  static formatTime(lastTime: number, msgTime: number): string {
    const msgDate = new Date(msgTime);
    const nowDate = new Date(systemDateTime.getTime());

    const yearOptions: Intl.DateTimeFormatOptions = {
      hour12: false,
      hour: '2-digit',
      minute: '2-digit',
      month: 'long',
      day: 'numeric',
      year: 'numeric'
    };

    const monthOptions: Intl.DateTimeFormatOptions = {
      hour12: false,
      hour: '2-digit',
      minute: '2-digit',
      month: 'long',
      day: 'numeric',
    };

    const minuteOptions: Intl.DateTimeFormatOptions = {
      hour12: false,
      hour: '2-digit',
      minute: '2-digit',
    };

    if (msgTime - lastTime > 300000) {
      if (nowDate.getFullYear() !== msgDate.getFullYear()) {
        return msgDate.toLocaleString('zh-CN', yearOptions);
      } else if (nowDate.getMonth() !== msgDate.getMonth() || nowDate.getDay() !== msgDate.getDay()) {
        return msgDate.toLocaleString('zh-CN', monthOptions);
      } else {
        return msgDate.toLocaleString('zh-CN', minuteOptions);
      }
    }
    return '';
  }

  static formatCallTime(time: number): string {
    const hour: number = Math.floor(time / 3600);
    const minute: number = Math.floor((time % 3600) / 60);
    const second: number = time % 60;
    if (hour === 0) {
      return `${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}`;
    }
    return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}:${second.toString()
      .padStart(2, '0')}`;
  }
}