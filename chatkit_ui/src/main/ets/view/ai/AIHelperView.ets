/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { AIHelperItem } from '../../model/AIHelperItem'
import { AIHelperClickListener } from '../../model/AIHelperClickListener'

const AI_HELPER_LOADING_FRAMES: ImageFrameInfo[] = [
  { src: $r('app.media.ic_chat_ai_helper_loading_00'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_01'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_02'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_03'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_04'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_05'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_06'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_07'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_08'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_09'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_10'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_11'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_12'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_13'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_14'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_15'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_16'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_17'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_18'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_19'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_20'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_21'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_22'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_23'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_24'), duration: 40 },
  { src: $r('app.media.ic_chat_ai_helper_loading_25'), duration: 400 }
]

/**
 * AI 助聊面板组件（受控组件）
 * 对齐 Android AIHelperView
 */
@ComponentV2
export struct AIHelperView {
  @Param clickListener: AIHelperClickListener | undefined = undefined
  @Param @Require isLoading: boolean
  @Param @Require isError: boolean
  @Param @Require helperItems: AIHelperItem[]

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($rawfile('ai_icon_highlight.png'))
          .width(24)
          .height(24)
          .margin({ left: 12 })

        Text($r('app.string.chat_ai_helper_title'))
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 4 })

        Blank()

        Row() {
          Image($rawfile('ic_chat_ai_helper_refresh.svg'))
            .width(24)
            .height(24)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick(() => {
          if (!this.isLoading && this.clickListener) {
            this.clickListener.onRefreshClick()
          }
        })
      }
      .width('100%')
      .height(30)

      // 加载态
      if (this.isLoading) {
        Column() {
          ImageAnimator()
            .images(AI_HELPER_LOADING_FRAMES)
            .state(AnimationStatus.Running)
            .iterations(-1)
            .fixedSize(true)
            .width(72)
            .height(72)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.isError) {
        // 错误态
        Column() {
          Text($r('app.string.chat_ai_helper_error_title'))
            .fontSize(16)
            .fontColor('#333333')
            .fontWeight(FontWeight.Bold)

          Text($r('app.string.chat_ai_helper_error_try'))
            .fontSize(14)
            .fontColor('#333333')
            .margin({ top: 12 })
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .border({ width: 1, color: '#D6DAE0', radius: 16 })
            .onClick(() => {
              if (!this.isLoading && this.clickListener) {
                this.clickListener.onTryAgainClick()
              }
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // 内容列表：3 条等高平分，白色圆角卡片
        Column({ space: 8 }) {
          ForEach(this.helperItems, (item: AIHelperItem, index: number) => {
            Row() {
              // 彩色标签
              Text(item.tag)
                .fontSize(15)
                .fontColor(item.tagTextColor ?? '#E75257')
                .maxLines(1)
                .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .border({ radius: 6 })
                .backgroundColor(item.tagBgColor ?? '#FFE0E6')

              // 回复文本
              Text(item.content)
                .fontSize(14)
                .fontColor('#333333')
                .lineHeight(20)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
                .margin({ left: 8, right: 4 })

              // 编辑按钮（扩大点击区域）
              Row() {
                Image($rawfile('ic_chat_ai_helper_edit.svg'))
                  .width(20)
                  .height(20)
              }
              .padding({ left: 8, right: 4, top: 8, bottom: 8 })
              .onClick(() => {
                this.clickListener?.onItemEditClick(item)
              })
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .margin({ top: 3, bottom: 3 })
            .alignItems(VerticalAlign.Center)
            .borderRadius(8)
            .backgroundColor('#FFFFFF')
            .onClick(() => {
              this.clickListener?.onItemClick(item)
            })
          }, (item: AIHelperItem, index: number) => `${index}_${item.tag}`)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 4, bottom: 8 })
      }
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
