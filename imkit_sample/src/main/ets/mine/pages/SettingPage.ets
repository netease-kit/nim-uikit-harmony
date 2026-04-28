/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ViewItemSwitch } from '@nimkit/common/src/main/ets/model/ViewItemSwitch';
import {
  CommonConstants,
  DoubleAlertDialog,
  NavigationBackBuilder,
  NECommonUtils,
  ViewItemArrow,
  ViewItemBuilder
} from '@nimkit/common';
import { ChatKitClient } from '@nimkit/chatkit/src/main/ets/ChatKitClient';
import { ConversationRepo, IMKitConfigCenter } from '@nimkit/chatkit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';

// 跳转页面入口函数
@Builder
function SettingPageBuilder() {
  SettingPage()
}

@ComponentV2
export struct SettingPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local localConversationOrOpen: boolean = true
  dataPreferences: preferences.Preferences | undefined
  @Local secondItems: ViewItemSwitch[] = []
  private context = getContext(this) as common.UIAbilityContext;
  logoutDialog?: CustomDialogController = new CustomDialogController({
    builder: DoubleAlertDialog({
      title: $r('app.string.mine_setting_logout'),
      message: $r('app.string.mine_setting_logout_confirm'),
      sureText: $r('app.string.mine_setting_logout_yes'),
      cancelText: $r('app.string.mine_setting_logout_no'),
      sureAction: this.logout
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 140,
    width: 270,
  })

  aboutToAppear(): void {
    let options: preferences.Options = { name: 'imkit_data' };
    this.dataPreferences = preferences.getPreferencesSync(getContext(this), options);
    this.localConversationOrOpen =
      this.dataPreferences?.getSync(CommonConstants.KEY_SETTING_LOCAL_CONVERSATION, true) as boolean

    this.secondItems = [
      // 听筒模式开关（暂时隐藏，通过长按语音消息切换）
      // {
      //   title: $r('app.string.mine_setting_earpiece'),
      //   itemHeight: 48,
      //   isOpen: this.earpieceOpen,
      //   switchChange: this.earpieceModeSwitchChange
      // },
      {
        title: $r('app.string.mine_setting_conversation'),
        itemHeight: 48,
        isOpen: this.localConversationOrOpen,
        switchChange: ((isOpen: boolean) => {
          this.dataPreferences?.putSync(CommonConstants.KEY_SETTING_LOCAL_CONVERSATION, isOpen)
          this.dataPreferences?.flush((err: BusinessError) => {
            if (err) {
              console.error("Failed to flush. code =" + err.code + ", message =" + err.message);
              return;
            }
            console.info("Succeeded in flushing.");
          })
          IMKitConfigCenter.enableLocalConversation = isOpen

          // restart app
          let applicationContext = this.context.getApplicationContext();
          let want: Want = {
            abilityName: 'IMAbility'
          };
          try {
            applicationContext.restartApp(want);
          } catch (error) {
            console.error(`restartApp fail, error: ${JSON.stringify(error)}`);
          }
        })
      },
    ]
  }

  async logout() {
    try {
      await ChatKitClient.nim.loginService.logout()
      ConversationRepo.removeAllConversationListener()
      ChatKitClient.onDestroy()
    } catch (err) {
      console.error(err)
      NECommonUtils.showToast(err)
    }
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
          // 第一组：子页面导航入口
          List() {
            ListItem() {
              ViewItemBuilder({
                title: $r('app.string.mine_setting_notify_title'),
                itemHeight: 48,
                routerUrl: 'NotifySettingPage',
                rightIcon: $r('app.media.arrow_right')
              })
            }
            .width('100%')
            .height(48)
            .backgroundColor(Color.White)
            .onClick(() => {
              this.pathStack.pushPath({ name: 'NotifySettingPage' })
            })

            ListItem() {
              ViewItemBuilder({
                title: $r('app.string.mine_setting_global_config'),
                itemHeight: 48,
                routerUrl: 'GlobalConfigPage',
                rightIcon: $r('app.media.arrow_right')
              })
            }
            .width('100%')
            .height(48)
            .backgroundColor(Color.White)
            .onClick(() => {
              this.pathStack.pushPath({ name: 'GlobalConfigPage' })
            })

            ListItem() {
              ViewItemBuilder({
                title: $r('app.string.push_config'),
                itemHeight: 48,
                routerUrl: 'PushConfigPage',
                rightIcon: $r('app.media.arrow_right')
              })
            }
            .width('100%')
            .height(48)
            .backgroundColor(Color.White)
            .onClick(() => {
              this.pathStack.pushPath({ name: 'PushConfigPage' })
            })

            ListItem() {
              ViewItemBuilder({
                title: $r('app.string.mine_setting_translation'),
                itemHeight: 48,
                routerUrl: 'TranslationSettingPage',
                rightIcon: $r('app.media.arrow_right')
              })
            }
            .width('100%')
            .height(48)
            .backgroundColor(Color.White)
            .onClick(() => {
              this.pathStack.pushPath({ name: 'TranslationSettingPage' })
            })
          }
          .borderRadius(8)
          .backgroundColor(Color.White)
          .margin({ left: 20, right: 20, top: 0 })

          // 第二组：当页基础开关
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

          // 退出登录
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