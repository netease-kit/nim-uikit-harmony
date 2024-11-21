/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@Entry
@ComponentV2
export struct ChatMultiSelectView {
  @Param
  private onMultiForward?: (event: ClickEvent) => void = undefined
  @Param
  private onSingleForward?: (event: ClickEvent) => void = undefined
  @Param
  private onMultiDelete?: (event: ClickEvent) => void = undefined
  @Param
  private isEnable?: boolean = true

  build() {
    Row() {
      Column() {
        Image(this.isEnable ? $r('app.media.ic_chat_select_multi_forward') :
        $r("app.media.ic_chat_select_multi_forward_dis")).width(48).height(48).margin({ top: 20 })
        Text($r('app.string.chat_operation_multi_forward'))
          .fontColor($r('app.color.color_chat_sub_title'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .margin({ top: 8 })
      }.height('100%').alignItems(HorizontalAlign.Center).width(60).onClick((event) => {
        if (this.isEnable) {
          this.onMultiForward?.(event)
        }
      })

      Column() {
        Image(this.isEnable ? $r("app.media.ic_chat_select_forward") : $r("app.media.ic_chat_select_forward_dis"))
          .width(48)
          .height(48)
          .margin({ top: 20 })
        Text($r('app.string.chat_operation_single_forward'))
          .fontColor($r('app.color.color_chat_sub_title'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .margin({ top: 8 })
      }.height('100%').alignItems(HorizontalAlign.Center).width(60).onClick((event) => {
        if (this.isEnable) {
          this.onSingleForward?.(event)
        }
      })

      Column() {
        Image(this.isEnable ? $r('app.media.ic_chat_select_delete') : $r("app.media.ic_chat_select_delete_dis"))
          .width(48)
          .height(48)
          .margin({ top: 20 })
        Text($r('app.string.chat_operation_delete'))
          .fontColor($r('app.color.color_chat_sub_title'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .margin({ top: 8 })
      }.height('100%').alignItems(HorizontalAlign.Center).width(60).onClick((event) => {
        if (this.isEnable) {
          this.onMultiDelete?.(event)
        }
      })
    }
    .width('100%')
    .height(100)
    .backgroundColor($r('app.color.color_chat_op_bg'))
    .justifyContent(FlexAlign.SpaceAround)
    .padding({
      left: 20,
      right: 20,
    })
  }
}