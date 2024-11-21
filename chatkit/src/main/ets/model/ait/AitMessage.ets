/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { AitSegment } from './AitSegment'
import { Type } from 'class-transformer'
import 'reflect-metadata'

export class AitMessage {
  /**
   * 账号
   */
  accountId: string = ""
  //@的文本
  text: string
  //@的信息存储，一个文案可能被@多次
  @Type(() => AitSegment)
  segments: AitSegment[] = []

  constructor(text: string, accountId: string) {
    this.text = text
    this.accountId = accountId
  }

  addSegment(start: number, end: number, broken?: boolean) {
    let segment: AitSegment = {
      start: start,
      end: end,
      broken: broken ?? false
    }
    this.segments.push(...[segment])
  }

  removeSegment(start: number, end: number) {
    let index = this.segments.findIndex(e => e.start === start && e.end === end)
    if (index >= 0) {
      this.segments.splice(index, 1)
    }
  }

  valid(): boolean {
    if (this.segments.length < 0) {
      return false
    }
    for (let segment of this.segments) {
      if (!segment.broken) {
        return true
      }
    }
    return false
  }

  segmentToMap(segment: AitSegment): Map<string, number | boolean> {
    let map = new Map<string, number | boolean>()
    map.set('start', segment.start)
    map.set('end', segment.end)
    map.set('broken', segment.broken ?? false)
    return map
  }
}

