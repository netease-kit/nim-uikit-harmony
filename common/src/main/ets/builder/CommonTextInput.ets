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
  @Param onClear?: () => void = undefined
  @Param activeBackgroundColor?: ResourceColor = undefined
  @Param text?: string = undefined
  @Param keepEditableState: boolean = true // 是否保持键盘弹出
  @Local inputText: string = ''
  @Local isFocused: boolean = false

  build() {
    if (this.onClear) {
      this.clearableTextInput()
    } else {
      this.defaultTextInput()
    }
  }

  @Builder
  defaultTextInput() {
    Stack({
      alignContent: Alignment.Start
    }) {
      TextInput({
        placeholder: this.placeHolderText
      })
        .type(InputType.Normal)
        .height(36)
        .margin({
          left: 20,
          right: 20
        })
        .padding({
          left: 36
        })
        .cancelButton({
          style: CancelButtonStyle.INPUT,
          icon: {
            src: $r('app.media.input_clean'),
            size: 16,
            color: "#B3B7BC"
          }
        })
        .borderRadius(4)
        .backgroundColor('#F2F4F5')
        .placeholderColor('#A6ADB6')
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
          if (this.onSubmit) {
            this.onSubmit(enterKey, event)
          }
          if (this.keepEditableState) {
            event.keepEditableState()
          }
        })
        .onChange(this.onTextChange)
        .onAppear(() => {

        })

      Image(this.leftIcon)
        .height(16)
        .width(16)
        .margin({
          left: 36
        })
    }
    .width('100%')
    .height(32)
  }

  @Builder
  clearableTextInput() {
    Stack() {
      Row() {
        Image(this.leftIcon)
          .height(16)
          .width(16)
          .margin({
            left: 16,
            right: 8
          })

        TextInput({
          text: this.text ?? this.inputText,
          placeholder: this.placeHolderText
        })
          .type(InputType.Normal)
          .height(36)
          .layoutWeight(1)
          .padding(0)
          .cancelButton({
            style: CancelButtonStyle.INVISIBLE
          })
          .backgroundColor(Color.Transparent)
          .placeholderColor('#A6ADB6')
          .onFocus(() => {
            this.isFocused = true
          })
          .onBlur(() => {
            this.isFocused = false
          })
          .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
            if (this.onSubmit) {
              this.onSubmit(enterKey, event)
            }
            if (this.keepEditableState) {
              event.keepEditableState()
            }
          })
          .onChange((value: string, previewText?: PreviewText) => {
            this.inputText = value
            if (this.onTextChange) {
              this.onTextChange(value, previewText)
            }
          })

        if ((this.text ?? this.inputText).length > 0) {
          Image($r('app.media.input_clean'))
            .width(16)
            .height(16)
            .margin({
              left: 8,
              right: 12
            })
            .onClick(() => {
              this.inputText = ''
              if (this.onTextChange) {
                this.onTextChange('')
              }
              if (this.onClear) {
                this.onClear()
              }
            })
        }
      }
      .width('100%')
      .height(36)
      .borderRadius(4)
      .backgroundColor(this.activeBackgroundColor !== undefined &&
        (this.isFocused || (this.text ?? this.inputText).length > 0) ? this.activeBackgroundColor : '#F2F4F5')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(36)
    .padding({
      left: 20,
      right: 20
    })
  }
}
