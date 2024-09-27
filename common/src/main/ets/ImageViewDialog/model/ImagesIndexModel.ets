/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/*
  图片查看器模型
  包含图片 url 列表和当前图片下标
 */

@ObservedV2
export class ImagesIndexModel {
  @Trace imageUrls: string[] = [];
  currentIndex: number = 0;

  constructor(imageUrls: string[] = [], currentIndex: number = 0) {
    this.imageUrls = imageUrls;
    this.currentIndex = currentIndex;
  }
}