/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
@ObservedV2
export class NERectData {
  @Trace
  x: number = 0;
  @Trace
  y: number = 0;
  @Trace
  width: number = 0;
  @Trace
  height: number = 0;
}