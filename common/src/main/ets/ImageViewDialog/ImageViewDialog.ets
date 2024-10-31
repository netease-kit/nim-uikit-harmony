/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ImageItemView } from './ImageItemView';
import { ImagesIndexModel } from './model/ImagesIndexModel';

/*
  图片查看器
 */
@CustomDialog
export struct ImageViewDialog {
  controller?: CustomDialogController
  @BuilderParam imagesIndexModel?: ImagesIndexModel;
  swipeController: SwiperController = new SwiperController();

  build() {
    Swiper(this.swipeController) {
      ForEach(this.imagesIndexModel?.imageUrls, (item: string, index: number) => {
        ImageItemView({ imageUri: item })
          .width('100%')
          .height('100%')
      })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .autoPlay(false)
    .loop(false)
    .indicator(false)
    .effectMode(EdgeEffect.Fade)
    .index(this.imagesIndexModel?.currentIndex)
    .cachedCount(this.imagesIndexModel?.imageUrls.length)
    .onClick(() => {
      this.controller?.close()
    })
  }
}