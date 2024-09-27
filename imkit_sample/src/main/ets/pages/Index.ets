/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { LoginComponent } from './LoginComponent';

/**
 * Index is the entry of application and Here is a list showing three buttons,
 * click the button to jump to different pages.
 */


@Entry
@Component
struct Index {
  pathStack: NavPathStack = new NavPathStack()
  @State showLoginPage: boolean = true

  build() {
    Navigation(this.pathStack) {
      if (this.showLoginPage) {
        Column() {
          Row().height(80)
          Image($r('app.media.im_uikit_icon'))
            .width(120).height(120)
          Text('云信IM').fontSize(24)
            .fontColor('#333333')

          Row().height(127)

          Button($r('app.string.login'), { type: ButtonType.Normal, stateEffect: true })
            .alignSelf(ItemAlign.Center)
            .onClick(() => {
              //账号ID
              let accountId = ''
              //账号Token
              let accountToken = ''
              //应用APPKEY
              let appKey = ''
              const loginComponent = new LoginComponent();
              loginComponent.login(accountId, accountToken, appKey)
            })
            .borderRadius(10)
            .height(50)
            .width('90%')
            .backgroundColor(0x337EFF)

          Row().height(200)

          Image($r('app.media.yunxin_icon'))
            .width(82).height(20)
        }
        .alignItems(HorizontalAlign.Center)
        .height('100%')
        .width('100%')
        .margin({ top: 10 })
      } else {
        Column() {
          Row().height(80)
          Image($r('app.media.im_uikit_icon'))
            .width(120).height(120)
          Text($r('app.string.ability_label')).fontSize(24)
            .fontColor('#333333')

          Row().height(12)

          Text($r('app.string.yunxin_comment')).fontSize(16)
            .fontColor('#666666')

          Row().height(330)

          Image($r('app.media.yunxin_icon'))
            .width(82).height(20)
        }
        .alignItems(HorizontalAlign.Center)
        .height('100%')
        .width('100%')
        .margin({ top: 10 })
      }


    }.mode(NavigationMode.Auto)
  }
}
