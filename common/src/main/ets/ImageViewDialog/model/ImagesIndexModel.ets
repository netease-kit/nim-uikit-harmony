/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { image } from '@kit.ImageKit'

/*
  图片查看器模型
  包含图片 url 列表和当前图片下标
 */

@ObservedV2
export class ImagesIndexModel {
  @Trace imageUrls: string[] = [];
  currentIndex: number = 0;
  // 缓存的缩略图 PixelMap 列表（用于图片预览时作为占位图，避免网络不可用时预览黑屏）
  thumbPixelMaps: (image.PixelMap | undefined)[] = [];

  constructor(imageUrls: string[] = [], currentIndex: number = 0, thumbPixelMaps: (image.PixelMap | undefined)[] = []) {
    this.imageUrls = imageUrls;
    this.currentIndex = currentIndex;
    this.thumbPixelMaps = thumbPixelMaps;
  }
}