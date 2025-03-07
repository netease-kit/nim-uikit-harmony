/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { DoubleAlertDialog, NavigationBackBuilder, NECommonUtils } from '@nimkit/common'
import { NimRepository } from '../ability/NimRepository'
import { AppConfig } from '../constants/AppConfig'
import { IMSDKConfigManager } from '../manager/IMSDKConfigManager'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'


@Entry
@ComponentV2
struct LoginByAccountPage {
  pathStack: NavPathStack = new NavPathStack()
  accountId: string = ''
  accountIdToken: string = ''
  isLogin: boolean = false

  stringToUint8Array(str: string): Uint8Array {
    let arr: number[] = [];
    for (let i = 0; i < str.length; i++) {
      arr.push(str.charCodeAt(i));
    }
    return new Uint8Array(arr);
  }

  uint8ArrayToHex(array: Uint8Array): string {
    return Array.from(array).map(b => b.toString(16).padStart(2, '0')).join('');
  }

  async md5(value: string): Promise<string> {
    let md5 = cryptoFramework.createMd("MD5");
    await md5.update({ 'data': this.stringToUint8Array(value) })
    return this.uint8ArrayToHex((await md5.digest()).data)
  }

  loginAction = async () => {
    if (this.accountId.length === 0 || this.accountIdToken.length === 0) {
      NECommonUtils.showToast($r('app.string.login_config_input_empty'))
      return
    }

    if (!this.isLogin) {
      this.isLogin = true
      try {
        const nimRepository = NimRepository.getInstance(getContext(this))
        const appkey = AppConfig.appKey
        const token = await this.md5(this.accountIdToken)
        await nimRepository.login(this.accountId, token, appkey)
        this.isLogin = false
      } catch (err) {
        this.isLogin = false
        const tips = getContext(this).resourceManager.getStringSync($r('app.string.login_failed').id)
        NECommonUtils.showToast(tips + err)
        console.error(err)
      }
    }
  }
  clearCustomConfig = () => {
    IMSDKConfigManager.clearConfig()
    NECommonUtils.showToast($r('app.string.login_config_clean_success'))
  }
  clearDialog?: CustomDialogController = new CustomDialogController({
    builder: DoubleAlertDialog({
      title: $r('app.string.chat_team_error_tip_title'),
      message: $r('app.string.login_config_clean_tip'),
      sureText: $r('app.string.mine_setting_logout_yes'),
      cancelText: $r('app.string.mine_setting_logout_no'),
      sureAction: this.clearCustomConfig
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 140,
    width: 270,
  })

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        TextInput({
          placeholder: $r('app.string.login_placeholder_account'),
          text: this.accountId
        })
          .borderRadius(8)
          .backgroundColor(Color.White)
          .placeholderColor('#CCCCCC')
          .margin({
            left: 20,
            right: 20
          })
          .onChange((value: string, previewText?: PreviewText) => {
            this.accountId = value
          })

        TextInput({
          placeholder: $r('app.string.login_placeholder_token'),
          text: this.accountIdToken
        })
          .borderRadius(8)
          .backgroundColor(Color.White)
          .placeholderColor('#CCCCCC')
          .type(InputType.Password)
          .margin({
            top: 20,
            left: 20,
            right: 20
          })
          .onChange((value: string, previewText?: PreviewText) => {
            this.accountIdToken = value
          })

        Button($r('app.string.login'))
          .backgroundColor(0x337EFF)
          .width('90%')
          .margin({
            top: 20,
            left: 20,
            right: 20
          })
          .onClick(this.loginAction)

        Button($r('app.string.login_clean_config'))
          .backgroundColor(0x337EFF)
          .width('90%')
          .margin({
            top: 20,
            left: 20,
            right: 20
          })
          .onClick(() => {
            this.clearDialog?.open()
          })
      }
    }
    .backgroundColor('#EFF1F4')
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}

@Builder
export function LoginByAccountPageBuilder() {
  LoginByAccountPage()
}