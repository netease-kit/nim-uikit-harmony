/**
 * EndItemView
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−06-03
 *
 * Copyright © 2025 Netease. All rights reserved.
 */
/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMConversation } from '@nimsdk/base'

@ComponentV2
export struct EndItemView {
  @Param conversationInfo: V2NIMConversation = {} as V2NIMConversation
  @Event deleteItem: () => void = () => {
  }
  @Event stickTopItem: (stickTop: boolean) => void = (stickTop: boolean) => {
  }

  build() {
    if (this.conversationInfo != null) {
      Row({  }) {
        Stack() {
          if (this.conversationInfo.stickTop) {
            Text($r('app.string.unstick_top_conversation'))
              .fontSize(14)
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.stickTopItem(false)
              })
              .height(30)
              .textAlign(TextAlign.Center)
          } else {
            Text($r('app.string.stick_top_conversation'))
              .fontSize(14)
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.stickTopItem(true)
              })
              .height(30)
              .textAlign(TextAlign.Center)
          }
        }
        .width(70)
        .height('100%')
        .backgroundColor('#347EFF')
        Stack() {
          Text($r('app.string.delete_conversation'))
            .fontSize(14)
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.deleteItem()
            })
            .height(30)
            .textAlign(TextAlign.Center)
        }.width(70)
        .height('100%')
        .backgroundColor('#E75E58')
      }
    }
  }
}