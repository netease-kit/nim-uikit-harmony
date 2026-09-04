/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import {
  calculateReactionLayoutWidth,
  calculateReactionNaturalWidth,
  buildReactionSummaryRenderKey,
  formatReactionCount,
  ReactionSummary
} from '../utils/MessageReactionUtils'
import { MessageReactionPicker } from './MessageReactionPicker'
import { MessageReactionEmoji } from '../model/MessageReactionEmoji'
import { MessageReactionManager } from '../manager/MessageReactionManager'

const REACTION_COUNT_FONT_SIZE: number = 12

@ComponentV2
export struct MessageReactionView {
  @Local private showPicker: boolean = false
  @Param @Require summaries: ReactionSummary[] = []
  @Param @Require onReactionClick?: (index: number) => Promise<boolean> = undefined
  @Param isReceiveStyle: boolean = false

  @Builder
  private reactionPickerBuilder() {
    MessageReactionPicker({
      expanded: true,
      showExpandButton: false,
      onReactionClick: async (index: number): Promise<boolean> => {
        const result = this.onReactionClick?.(index)
        const succeeded = result !== undefined ? await result : false
        if (succeeded) {
          this.showPicker = false
        }
        return succeeded
      }
    })
    .width(320)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }

  private getCountTextWidths(): number[] {
    return this.summaries.map((summary: ReactionSummary): number => {
      const textSize = this.getUIContext().getMeasureUtils().measureTextSize({
        textContent: formatReactionCount(summary.count),
        fontSize: REACTION_COUNT_FONT_SIZE,
        maxLines: 1
      })
      return px2vp(Number(textSize.width))
    })
  }

  onMeasureSize(_selfLayoutInfo: GeometryInfo, children: Array<Measurable>,
    constraint: ConstraintSizeOptions): SizeResult {
    const countTextWidths = this.getCountTextWidths()
    const naturalWidth = calculateReactionNaturalWidth(countTextWidths)
    const maxWidth = typeof constraint.maxWidth === 'number' ? constraint.maxWidth : naturalWidth
    const layoutWidth = calculateReactionLayoutWidth(countTextWidths, maxWidth)
    if (children.length === 0) {
      return { width: layoutWidth, height: 0 }
    }
    const childMeasureResult = children[0].measure({
      minWidth: layoutWidth,
      maxWidth: layoutWidth,
      minHeight: constraint.minHeight,
      maxHeight: constraint.maxHeight
    })
    return { width: layoutWidth, height: childMeasureResult.height }
  }

  onPlaceChildren(_selfLayoutInfo: GeometryInfo, children: Array<Layoutable>,
    _constraint: ConstraintSizeOptions): void {
    if (children.length > 0) {
      children[0].layout({ x: 0, y: 0 })
    }
  }

  private getCapsuleBackgroundColor(hasSelf: boolean = false): ResourceColor {
    // if (hasSelf) {
    //   return $r('app.color.color_chat_reaction_selected_bg')
    // }
    return this.isReceiveStyle ? $r('app.color.color_chat_reaction_receive_bg') :
      $r('app.color.color_chat_reaction_send_bg')
  }

  private getCapsuleBorderColor(hasSelf: boolean = false): ResourceColor {
    return hasSelf ? $r('app.color.color_chat_reaction_selected_border') :
      $r('app.color.color_chat_reaction_border')
  }

  @Builder
  private reactionItem(summary: ReactionSummary, emoji: MessageReactionEmoji | undefined) {
    if (emoji !== undefined) {
      Row({ space: 4 }) {
        Image(emoji.icon)
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)

        Text(formatReactionCount(summary.count))
          .fontSize(REACTION_COUNT_FONT_SIZE)
          .fontColor(summary.hasSelf ? $r('app.color.color_chat_send') :
          $r('app.color.color_chat_sub_title'))
          .maxLines(1)
          .translate({ y: 5 })
      }
      .height(28)
      .padding({ left: 6, right: 8 })
      .margin({ right: 6, bottom: 6 })
      .backgroundColor(this.getCapsuleBackgroundColor(summary.hasSelf))
      // .border({ width: 0.5, color: this.getCapsuleBorderColor(summary.hasSelf) })
      .borderRadius(14)
      .onClick(() => {
        this.onReactionClick?.(summary.index)
      })
    }
  }

  build() {
    Column() {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        Row() {
          Image($r('app.media.ic_chat_reaction_add'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
        }
        .width(28)
        .height(28)
        .margin({ right: 6, bottom: 6 })
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.getCapsuleBackgroundColor())
        .border({ width: 0.5, color: $r('app.color.color_chat_reaction_border') })
        .borderRadius(14)
        .onClick(() => {
          this.showPicker = true
        })
        .bindPopup(this.showPicker, {
          builder: this.reactionPickerBuilder,
          placement: Placement.Top,
          popupColor: Color.White,
          enableArrow: false,
          mask: true,
          autoCancel: true,
          onStateChange: (event): void => {
            if (!event.isVisible) {
              this.showPicker = false
            }
          }
        })

        ForEach(this.summaries, (summary: ReactionSummary) => {
          this.reactionItem(summary, MessageReactionManager.getEmoji(summary.index))
        }, (summary: ReactionSummary): string => buildReactionSummaryRenderKey(summary))
      }
      .padding({ left: 6, top: 6 })
      .constraintSize({ maxWidth: '100%' })
    }
    .constraintSize({ maxWidth: '100%' })
  }
}
