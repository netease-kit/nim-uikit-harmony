/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@ComponentV2
export struct CommonTextInput {
  @Param placeHolderText?: ResourceStr = $r('app.string.text_input_placeholder')
  @Param leftIcon?: Resource = $r('app.media.text_input_icon')
  @Param onSubmit?: (enterKey: EnterKeyType, event: SubmitEvent) => void = undefined
  @Param onTextChange?: (value: string, previewText?: PreviewText) => void = undefined
  @Param keepEditableState: boolean = true // 是否保持键盘弹出
  @Local inputText: string = ''

  handleTextChange(value: string, previewText?: PreviewText) {
    this.inputText = value
    this.onTextChange?.(value, previewText)
  }

  clearInput() {
    this.inputText = ''
    this.onTextChange?.('')
  }

  build() {
    Stack({
      alignContent: Alignment.End
    }) {
      Stack({
        alignContent: Alignment.Start
      }) {
        TextInput({
          text: this.inputText,
          placeholder: this.placeHolderText
        })
          .type(InputType.Normal)
          .width('100%')
          .height(36)
          .padding({
            left: 36,
            right: 36
          })
          .borderRadius(4)
          .backgroundColor('#F2F4F5')
          .placeholderColor('#A6ADB6')
          .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
            this.onSubmit?.(enterKey, event)
            if (this.keepEditableState) {
              event.keepEditableState()
            }
          })
          .onChange((value: string, previewText?: PreviewText) => {
            this.handleTextChange(value, previewText)
          })

        Image(this.leftIcon)
          .height(16)
          .width(16)
          .margin({
            left: 16
          })
      }
      .width('100%')
      .height(36)

      if (this.inputText.length > 0) {
        Image($r('app.media.input_clean'))
          .width(16)
          .height(16)
          .margin({
            right: 12
          })
          .onClick(() => {
            this.clearInput()
          })
      }
    }
    .width('100%')
    .height(36)
    .margin({
      left: 20,
      right: 20
    })
  }
}
