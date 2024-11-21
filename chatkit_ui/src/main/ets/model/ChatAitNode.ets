/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { AitSegment } from '@nimkit/chatkit/src/main/ets/model/ait/AitSegment';

export interface ChatAitNode {
  //文本
  text: string,

  //片段
  segment?: AitSegment
  //accId
  account?: string
}
