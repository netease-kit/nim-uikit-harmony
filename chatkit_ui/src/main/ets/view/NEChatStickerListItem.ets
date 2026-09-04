/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { NEStickerItem } from '../model/NEStickerPackage'

@ComponentV2
export struct NEChatStickerListItem {
  @Param sticker: NEStickerItem = new NEStickerItem('', $rawfile('emoji/emoji_00.png'), '')
  @Param @Require onDidClick?: (sticker: NEStickerItem) => void

  build() {
    Stack() {
      Image(this.sticker.image)
        .width(54)
        .height(54)
        .objectFit(ImageFit.Contain)
    }
    .width('100%')
    .height('100%')
    .onClick((): void => {
      this.onDidClick?.(this.sticker)
    })
  }
}
