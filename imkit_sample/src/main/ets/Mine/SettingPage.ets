/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { LoginComponent } from '../pages/LoginComponent';
import { ViewItemSwitch } from '@nimkit/common/src/main/ets/model/ViewItemSwitch';
import promptAction from '@ohos.promptAction';
import { CommonConstants, NavigationBackBuilder, NECommonUtils, ViewItemArrow, ViewItemBuilder } from '@nimkit/common';
import { ChatKitClient } from '@nimkit/chatkit/src/main/ets/ChatKitClient';

@CustomDialog
export struct LogoutDialog {
  pathStack: NavPathStack = new NavPathStack()
  controller?: CustomDialogController

  async logout() {
    try {
      await LoginComponent.nim.loginService.logout()

      ChatKitClient.haveSyncedConversation = false
    } catch (err) {
      console.log(err)
      promptAction.showToast({
        message: err
      })
    }
  }

  build() {
    Column() {
      Text($r('app.string.mine_setting_logout'))
        .fontSize(17)
        .margin({ top: 19 })
        .height(22)

      Text($r('app.string.mine_setting_logout_confirm'))
        .fontSize(13)
        .fontColor("#333333")
        .height(35)
        .margin({ top: 10 })

      Row()
        .height(1)
        .width('100%')
        .backgroundColor("#EFF1F4")
        .margin({ top: 10 })

      Row() {
        Button($r('app.string.mine_setting_logout_no'), { type: ButtonType.Normal })
          .fontSize(17)
          .fontColor("#666666")
          .backgroundColor(Color.White)
          .width(135)
          .height(44)
          .onClick(() => {
            this.controller?.close()
          })

        Column()
          .width(1)
          .height('100%')
          .backgroundColor("#EFF1F4")

        Button($r('app.string.mine_setting_logout_yes'), { type: ButtonType.Normal })
          .fontSize(17)
          .fontColor("#007AFF")
          .backgroundColor(Color.White)
          .width(135)
          .height(44)
          .onClick(() => {
            this.logout()
            this.controller?.close()
          })
      }
      .height(44)
      .width(270)
      .alignItems(VerticalAlign.Center)
    }
    .height(140)
    .width(270)
    .backgroundColor(Color.White)
  }
}

// 跳转页面入口函数
@Builder
function SettingPageBuilder() {
  SettingPage()
}

PersistentStorage.persistProp(CommonConstants.KEY_SETTING_EARPIECE_MODE, true)
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_MESSAGE_READ_OR, true)

@Component
export struct SettingPage {
  pathStack: NavPathStack = new NavPathStack()
  earpieceOpen: boolean = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_EARPIECE_MODE) ?? true
  readOrOpen: boolean = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_MESSAGE_READ_OR) ?? true
  @State firstItem: ViewItemArrow[] = [
    {
      // title: $r("app.string.person_setting_remind"),
      // itemHeight: 48,
      // routerUrl: "MessageRemindPage",
      // rightIcon: $r('app.media.arrow_right')
    }
  ]
  @State secondItems: ViewItemSwitch[] = [
  // {
  //   title: $r('app.string.mine_setting_earpiece'),
  //   itemHeight: 48,
  //   isOpen: this.earpieceOpen,
  //   switchChange: this.EarpieceModeSwitchChange
  // },
  // {
  //   title: $r('app.string.mine_setting_read'),
  //   itemHeight: 48,
  //   isOpen: this.readOrOpen,
  //   switchChange: this.ReadOrSwitchChange
  // },
  ]
  logoutDialog?: CustomDialogController = new CustomDialogController({
    builder: LogoutDialog(),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 140,
    width: 270,
  })

  EarpieceModeSwitchChange(isOpen: boolean) {
    NECommonUtils.showToast('听筒模式: ' + (isOpen ? '打开' : '关闭'))
    AppStorage.setOrCreate<boolean>(CommonConstants.KEY_SETTING_EARPIECE_MODE, isOpen)
  }

  ReadOrSwitchChange(isOpen: boolean) {
    NECommonUtils.showToast('消息已读未读功能: ' + (isOpen ? '打开' : '关闭'))
    AppStorage.setOrCreate<boolean>(CommonConstants.KEY_SETTING_MESSAGE_READ_OR, isOpen)
  }

  aboutToDisappear(): void {
    this.logoutDialog = undefined
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.mine_setting'),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Column({ space: 12 }) {
          List() {
            ForEach(this.firstItem, (item: ViewItemSwitch) => {
              ListItem() {
                ViewItemBuilder(item)
              }
              .width('100%')
              .height(item.itemHeight)
              .backgroundColor(item.backgroundColor ?? Color.White)
              .onClick(() => {
                this.pathStack.pushPath({
                  name: item.routerUrl
                })
              })
            })
          }
          .borderRadius(8)
          .backgroundColor(Color.White)
          .margin({ left: 20, right: 20, top: 0 })

          List() {
            ForEach(this.secondItems, (item: ViewItemSwitch) => {
              ListItem() {
                ViewItemBuilder(item)
              }
              .width('100%')
              .height(item.itemHeight)
              .backgroundColor(item.backgroundColor ?? Color.White)
            })
          }
          .borderRadius(8)
          .backgroundColor(Color.White)
          .margin({ left: 20, right: 20, top: 0 })

          Row() {
            Text($r('app.string.mine_setting_logout'))
              .fontColor("#E6605C")
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          .alignItems(VerticalAlign.Center)
          .height(48)
          .onClick(() => {
            this.logoutDialog?.open()
          })
          .borderRadius(8)
          .backgroundColor(Color.White)
          .margin({ left: 20, right: 20, top: 0 })
        }
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}