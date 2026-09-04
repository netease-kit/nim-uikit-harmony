/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { MessageReactionEmoji } from '../model/MessageReactionEmoji'
import { MessageReactionManager } from '../manager/MessageReactionManager'

const QUICK_REACTION_SIZE: number = 30
const QUICK_REACTION_LEFT_MARGIN: number = 13
const REACTION_GRID_ITEM_SIZE: number = 46
const REACTION_GRID_IMAGE_SIZE: number = 32

@ComponentV2
export struct MessageReactionPicker {
  @Param expanded: boolean = false
  @Param showExpandButton: boolean = true
  @Param @Require onReactionClick?: (index: number) => void = undefined
  @Param onExpandedChange?: (expanded: boolean) => void = undefined
  private readonly allReactionEmojis: MessageReactionEmoji[] = MessageReactionManager.getAllEmojis()

  @Builder
  private reactionImage(emoji: MessageReactionEmoji, size: number, leftMargin: number = 0) {
    Image(emoji.icon)
      .width(size)
      .height(size)
      .margin({ left: leftMargin })
      .objectFit(ImageFit.Contain)
      .onClick(() => {
        this.onReactionClick?.(emoji.index)
      })
  }

  @Builder
  private optionalReactionImage(emoji: MessageReactionEmoji | undefined, size: number, leftMargin: number = 0) {
    if (emoji !== undefined) {
      this.reactionImage(emoji, size, leftMargin)
    }
  }

  build() {
    Column() {
      Row() {
        ForEach(MessageReactionManager.getQuickReactionIndexes(this.showExpandButton), (reactionIndex: number) => {
          this.optionalReactionImage(MessageReactionManager.getEmoji(reactionIndex),
            QUICK_REACTION_SIZE, QUICK_REACTION_LEFT_MARGIN)
        }, (reactionIndex: number): string => reactionIndex.toString())

        Blank()

        if (this.showExpandButton) {
          Image(this.expanded ? $r('app.media.ic_chat_reaction_collapse') :
          $r('app.media.ic_chat_reaction_expand'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .onClick(() => {
              this.onExpandedChange?.(!this.expanded)
            })
        }
      }
      .width('100%')
      .height(50)
      .padding({ left: 3, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Divider()
        .height(1)
        .color('#E4E9F2')
        .margin({ left: 16, right: 16 })

      if (this.expanded) {
        Grid() {
          ForEach(this.allReactionEmojis, (emoji: MessageReactionEmoji) => {
            GridItem() {
              this.reactionImage(emoji, REACTION_GRID_IMAGE_SIZE)
            }
            .height(REACTION_GRID_ITEM_SIZE)
            .align(Alignment.Center)
          }, (emoji: MessageReactionEmoji): string => emoji.index.toString())
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
        .columnsGap(0)
        .rowsGap(0)
        .width('100%')
        .height(200)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
  }
}
