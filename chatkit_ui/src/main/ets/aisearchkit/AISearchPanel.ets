/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { AISearchMessage, AISearchViewModel } from './AISearchViewModel'
import { ChatKitClient } from '@nimkit/chatkit'
import { NECommonUtils } from '@nimkit/common'

@ComponentV2
export struct AISearchPanel {
  @Param keyword: string = ''
  @Param onClose: () => void = () => {}
  @Local viewModel: AISearchViewModel = new AISearchViewModel()
  @Local expanded: boolean = false
  @Local inputText: string = ''

  aboutToAppear(): void {
    this.viewModel.aboutToAppear()
    this.viewModel.search(this.keyword)
  }

  aboutToDisappear(): void {
    this.viewModel.aboutToDisappear()
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.expanded ? '#80000000' : Color.Transparent)
        .onClick(() => {
          this.onClose()
        })

      Column() {
        Row() {
          Row() {
            Text($r('app.string.chat_ai_search_cancel'))
              .fontSize(16)
              .fontColor('#666666')
          }
            .height(50)
            .layoutWeight(1)
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.onClose()
            })

          Row() {
            if (this.viewModel.isLoading) {
              LoadingProgress()
                .width(14)
                .height(14)
                .color('#337EFF')
                .margin({ right: 2 })
            }
            Text(this.viewModel.isLoading ? $r('app.string.chat_ai_searching') : $r('app.string.chat_ai_search'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
          }
            .height(50)
            .layoutWeight(2)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)

          Row() {
            if (!this.expanded) {
              Image($r('app.media.ic_ai_search_more'))
                .width(16)
                .height(16)
                .margin({ right: 2 })
              Text($r('app.string.chat_ai_search_more_info'))
                .fontSize(16)
                .fontColor('#2155EE')
            }
          }
            .height(50)
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              if (!this.expanded) {
                this.expanded = true
              }
            })
        }
        .height(50)
        .width('100%')
        .padding({ left: 16, right: 16 })

        Divider().strokeWidth(1).color('#EEEEEE')

        if (this.expanded) {
          Column() {
            TextArea({ text: this.inputText, placeholder: $r('app.string.chat_ai_search_hint') })
              .height(72)
              .width('100%')
              .backgroundColor(Color.Transparent)
              .fontSize(14)
              .lineHeight(20)
              .placeholderColor('#AAAAAA')
              .fontColor('#333333')
              .onChange((value: string) => {
                this.inputText = value
              })
            Text($r('app.string.chat_ai_search_send'))
              .fontSize(16)
              .fontColor('#2155EE')
              .opacity(this.inputText.trim().length > 0 ? 1 : 0.5)
              .alignSelf(ItemAlign.End)
              .margin({ right: 12, bottom: 12 })
              .onClick(() => {
                const text = this.inputText.trim()
                if (text.length === 0) {
                  return
                }
                if (ChatKitClient.connectBroken()) {
                  NECommonUtils.showToast($r('app.string.chat_network_error_tips'))
                  return
                }
                if (this.viewModel.search(text)) {
                  this.inputText = ''
                }
              })
          }
          .backgroundColor('#F5F5F5')
          .margin({ left: 20, right: 20, top: 16 })
        }

        List() {
          ForEach(this.viewModel.messages, (message: AISearchMessage, index: number) => {
            ListItem() {
              Column() {
                Row() {
                  Text(message.answer)
                    .fontSize(15)
                    .fontColor('#333333')
                    .lineHeight(22)
                    .width('100%')
                }
                .width('100%')
                .padding({ left: 20, right: 20 })
                if (index < this.viewModel.messages.length - 1) {
                  Divider()
                    .strokeWidth(3)
                    .color('#EFF1F2')
                    .width('100%')
                    .margin({ top: 16 })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 16, bottom: 16 })
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ top: 16, bottom: 16 })
      }
      .width('100%')
      .height(this.expanded ? '87.5%' : '50%')
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
  }
}
