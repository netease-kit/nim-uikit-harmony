/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { NIMEmoticonType, NIMInputEmoticon } from '../manager/NEEmojiManager';

@Entry
@ComponentV2
export struct NEChatEmojiListItem {
  @Param emoji: NIMInputEmoticon = new NIMInputEmoticon();
  @Param @Require onDidClick?: (emoji: NIMInputEmoticon) => void;

  build() {
    RelativeContainer() {
      if (this.emoji.type === NIMEmoticonType.file) {
        Image($rawfile(`emoji/${this.emoji.file}`))
          .width(30)
          .height(30)
          .alignRules({
            center: { anchor: "__container__", align: VerticalAlign.Center },
            middle: { anchor: "__container__", align: HorizontalAlign.Center }
          })
      } else if (this.emoji.type === NIMEmoticonType.delete) {
        Image($rawfile(`emoji/${this.emoji.file}`))
          .width(28)
          .height(22)
          .alignRules({
            center: { anchor: "__container__", align: VerticalAlign.Center },
            middle: { anchor: "__container__", align: HorizontalAlign.Center }
          })
      }

    }.width('100%')
    .height('100%')
    .alignRules({
      left: { anchor: "__container__", align: HorizontalAlign.Start },
      right: { anchor: "__container__", align: HorizontalAlign.End },
      bottom: { anchor: "__container__", align: VerticalAlign.Bottom },
      top: { anchor: "__container__", align: VerticalAlign.Top }
    }).onClick(() => {
      if (this.onDidClick) {
        this.onDidClick(this.emoji);
      }
    })
  }
}