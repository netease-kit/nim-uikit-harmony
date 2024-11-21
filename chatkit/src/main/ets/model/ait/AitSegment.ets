/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * 记录@消息的最小单位
 */
export class AitSegment {
  //@消息的起点
  start: number = 0;
  //@消息的终点位置
  end: number = 0;
  //是否已经被破坏
  broken: boolean = false
}
