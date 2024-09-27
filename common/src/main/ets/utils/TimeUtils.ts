/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export function fillNum(num) {
  if (num < 10) {
    return `0${num}`;
  }
  return num.toString();
}

// 视频时长转换
export function getTimeString(time) {
  if (time == -1 || time == undefined) {
    time = 0;
  }
  const TIMESTAMP: number = 1000;
  const TIME_UNIT: number = 60;
  const MAX_HOURS: number = 24;
  let hour = Math.floor(time % (TIMESTAMP * TIME_UNIT * TIME_UNIT * MAX_HOURS) / (TIMESTAMP * TIME_UNIT * TIME_UNIT));
  let minute = Math.floor(time % (TIMESTAMP * TIME_UNIT * TIME_UNIT) / (TIMESTAMP * TIME_UNIT));
  let second = Math.floor(time % (TIMESTAMP * TIME_UNIT) / TIMESTAMP);
  if (hour > 0) {
    return `${fillNum(hour)}:${fillNum(minute)}:${fillNum(second)}`;
  }
  return `${fillNum(minute)}:${fillNum(second)}`;
}
