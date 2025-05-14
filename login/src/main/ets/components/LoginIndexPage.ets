/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@ComponentV2
export struct LoginIndexComponent {
  @Param pathStack?: NavPathStack | undefined = undefined

  build() {
    Column() {
      Row().height(80)
      Image($r('app.media.im_uikit_icon'))
        .width(120).height(120)
      Text('云信IM').fontSize(24)
        .fontColor('#333333')

      Row().height(127)

      Button($r("app.string.registerOrLogin"), { type: ButtonType.Normal, stateEffect: true })
        .alignSelf(ItemAlign.Center)
        .onClick(() => {
          this.pathStack?.pushPath({ name: "LoginPage" })
        })
        .borderRadius(10)
        .height(50)
        .width('90%')
        .backgroundColor(0x337EFF)
    }
    .height('100%')
    .width('100%')
    .margin({ top: 10 })
  }
}

@ComponentV2
export struct LoginIndexPage {
  pathStack: NavPathStack = new NavPathStack()

  build() {
    NavDestination() {
      LoginIndexComponent({
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })

  }
}

@Builder
export function LoginIndexPageBuilder() {
  LoginIndexPage()
}