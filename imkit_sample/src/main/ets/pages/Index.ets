/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { IMKitConfigCenter } from '@nimkit/chatkit';
import { CommonConstants, NECommonUtils } from '@nimkit/common';

import { AuthService, BuildProfile, LoginConfig, LoginIndexComponent, LoginInfo } from '@nimkit/login';
import { NimRepository } from '../ability/NimRepository';
import { AppConfig } from '../constants/AppConfig';
import { preferences } from '@kit.ArkData';
import { DeprecatedIndexButton } from '../other/DeprecatedIndexButton'

/**
 * Index is the entry of application and Here is a list showing three buttons,
 * click the button to jump to different pages.
 */


@Entry
@ComponentV2
struct Index {
  pathStack: NavPathStack = new NavPathStack()
  @Local showLoginPage: boolean = false
  login = async (accountId: string, token: string) => {
    const nimRepository = NimRepository.getInstance(getContext(this))
    try {
      await nimRepository.login(accountId, token, AppConfig.appKey)
    } catch (err) {
      this.showLoginPage = true
      const tips = getContext(this).resourceManager.getStringSync($r('app.string.login_failed').id)
      NECommonUtils.showToast(tips + err)
      console.error(err)
    }
  }

  async onPageShow(): Promise<void> {
    LoginConfig.getInstance().initConfig(
      AppConfig.appKey, 2, 7, BuildProfile.DEBUG, null
    );
    let dataPreferences: preferences.Preferences | null = null;
    const options: preferences.Options = { name: 'imkit_data' };
    dataPreferences = preferences.getPreferencesSync(getContext(this), options);
    IMKitConfigCenter.enableLocalConversation = dataPreferences.getSync(CommonConstants.KEY_SETTING_MESSAGE_READ_OR, true) as boolean
    const loginUser = AuthService.instance.getLoginInfo(getContext(this))
    if (loginUser) {
      this.login(loginUser.imAccid, loginUser.imToken)
    } else {
      this.showLoginPage = true
    }

    AuthService.instance.setOnLoginSuccess({
      onSuccess: (user: LoginInfo): void => {
        console.debug(`Performance Test app loginSuccess`)
        this.login(user.imAccid, user.imToken)
      }
    })
  }

  build() {
    Navigation(this.pathStack) {
      if (this.showLoginPage) {
        LoginIndexComponent({
          pathStack: this.pathStack
        })
          .height('80%')

        Row().layoutWeight(1)

        Row() {
          Text($r('app.string.login_privatized_configuration'))
            .fontColor("#999999")
            .fontSize(12)
            .onClick(() => {
              this.pathStack?.pushPath({ name: "IMSDKConfigPage" })
            })

          Text($r('app.string.login_by_account'))
            .fontColor("#999999")
            .fontSize(12)
            .margin({
              left: 20
            })
            .onClick(() => {
              this.pathStack?.pushPath({ name: "LoginByAccountPage" })
            })
        }
        .margin({
          top: 10,
          bottom: 40
        })

        // InnerSDK
        // DeprecatedIndexButton({ pathStack: this.pathStack })
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
    .hideTitleBar(true)
  }
}