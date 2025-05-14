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

import { router } from '@kit.ArkUI';
import { ChatKitClient } from '@nimkit/chatkit/src/main/ets/ChatKitClient';
import { ConversationRepo, IMKitConfigCenter } from '@nimkit/chatkit';
import { ChatKitConfig } from '@nimkit/chatkit_ui/src/main/ets/ChatKitConfig';
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
  @Local earpieceOpen: boolean = AppStorage.get(CommonConstants.KEY_SETTING_EARPIECE_MODE) ?? true
  @Local readOrOpen: boolean = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_MESSAGE_READ_OR) ?? true
  @Local localConversationOrOpen: boolean = true
  dataPreferences: preferences.Preferences | undefined
  @Local firstItem: ViewItemArrow[] = [
    {
      // title: $r("app.string.person_setting_remind"),
      // itemHeight: 48,
      // routerUrl: "MessageRemindPage",
      // rightIcon: $r('app.media.arrow_right')
    }
  ]
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
      {
        title: $r('app.string.mine_setting_earpiece'),
        itemHeight: 48,
        isOpen: this.earpieceOpen,
        switchChange: this.earpieceModeSwitchChange
      },
      {
        title: $r('app.string.mine_setting_read'),
        itemHeight: 48,
        isOpen: this.readOrOpen,
        switchChange: this.readOrSwitchChange
      },
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
      router.replaceUrl({
        url: 'pages/Index'
      })
    } catch (err) {
      console.error(err)
      NECommonUtils.showToast(err)
    }
  }

  earpieceModeSwitchChange(isOpen: boolean) {
    AppStorage.set(CommonConstants.KEY_SETTING_EARPIECE_MODE, isOpen)
  }

  readOrSwitchChange(isOpen: boolean) {
    AppStorage.set(CommonConstants.KEY_SETTING_MESSAGE_READ_OR, isOpen)
    ChatKitConfig.messageReadState = isOpen
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