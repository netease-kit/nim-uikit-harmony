/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NavigationBackBuilder } from '../builder/NavigationBackBuilder'

export interface TextEditParams {
  content: string
  title: ResourceStr
  maxLength: number
  showSave: boolean
  maxLine?: number
  height?: Length
  emptyTextEnable?: boolean
}

/**
 * 通用文本编辑页面
 */
@ComponentV2
export struct TextEditPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local params: TextEditParams | null = null
  @Local content: string = ''
  @Local maxLine: number = 3
  @Local textHeight: Length = 100

  build() {
    NavDestination() {
      NavigationBackBuilder(
        {
          title: this.params?.title,
          leftButtonTitle: $r('app.string.cancel'),
          leftButtonColor: '#ff666666',
          leftButtonAction: () => {
            this.pathStack.pop()
          },
          rightButtonTitle: this.params?.showSave ? $r('app.string.save') : undefined,
          rightButtonColor: (this.params?.emptyTextEnable === false
            && this.content.length <= 0) ? '#80337EFF' : '#ff337EFF',
          backgroundColor: '#ffEFF1F4',
          rightButtonAction: this.params?.showSave ? () => {
            if (this.params?.emptyTextEnable === false
              && this.content.length <= 0) {
              return
            }
            this.pathStack.pop(this.content)
          } : undefined
        }
      )
      Stack({ alignContent: Alignment.End }) {
        TextArea({ text: this.content })
          .fontSize(16)
          .fontColor("#333333")
          .maxLines(this.maxLine)
          .height(this.textHeight)
          .backgroundColor(Color.White)
          .maxLength(this.params?.maxLength)
          .showCounter(true, {
            thresholdPercentage: 1
          })
          .onChange((value: string) => {
            this.content = value
          })
          .padding({
            top: 16,
            bottom: 16,
            right: 28,
            left: 16
          })

        if (this.content.length > 0) {
          Image($r('app.media.input_clean'))
            .width(16)
            .height(16)
            .onClick(() => {
              this.content = ''
            })
            .margin({
              right: 12
            })
        }
      }
      .margin({ left: 20, right: 20 })
      .borderRadius(8)
    }
    .hideTitleBar(true)
    .backgroundColor('#ffEFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.params = this.pathStack.getParamByName("TextEditPage")[0] as TextEditParams
      this.content = this.params.content
      this.maxLine = this.params.maxLine ?? 3
      this.textHeight = this.params.height ?? 100
    })
  }
}

@Builder
export function TextEditPageBuilder() {
  TextEditPage()
}