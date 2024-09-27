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

  build() {
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
        .onSubmit(this.onSubmit)
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
}