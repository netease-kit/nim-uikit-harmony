/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { promptAction } from '@kit.ArkUI';
import http from '@ohos.net.http';
import { AuthService, deprecatedInnerSaveLoginInfoInner, LoginInfo } from '../../AuthService';
import { WebParams } from '../../components/WebPage';
import { LoginConfig } from '../../config/LoginConfig';
import { BaseResponse } from '../../net/Response';
import { TextInputTypeModifier } from '../TextInputTypeModifier';

/**
 * @deprecated
 */
@ComponentV2
export struct DeprecatedLoginPage {
  phoneNumController: TextInputController = new TextInputController()
  smsController: TextInputController = new TextInputController()
  @Local isLogin: boolean = false;
  @Local smsCodeCommentStr: string = ''
  @Local phoneNumber: string = ''
  @Local smsCode: string = ''
  @Local countDownTime: number = 0
  @Local textInputModifier: TextInputTypeModifier = new TextInputTypeModifier()
  @Local innerLoginAcc: string = '' // only inner sdk
  pathStack: NavPathStack = new NavPathStack()
  private reTryCount: number = 60
  private isFirstRegister: boolean = false
  private isShownWarningDialog: boolean = false
  dialogController: CustomDialogController =
    new CustomDialogController({
      builder: LoginWarningDialog({
        cancel: () => {
          //do nothing
          this.isShownWarningDialog = false
        },
        confirm: () => {
          this.isShownWarningDialog = false
          //是否接受用户协议
          AppStorage.setOrCreate<boolean>(this.phoneNumber, true);
          this.isFirstRegister = false
          this.loginWithSmsCode()
        },
        pathStack: this.pathStack
      }),
      autoCancel: false,
      width: '60%'
    })

  build() {
    NavDestination() {
      Column() {
        Text($r('app.string.smsCodeLogin')).fontSize(22)
          .fontColor(0x222222).margin({ left: 30 })
        Text($r('app.string.smsCodeLoginComment'))
          .fontSize(12)
          .margin({ left: 30 })
        Row() {
          Text('+86 | ').fontColor('#ff999999')
          TextInput({
            placeholder: $r('app.string.pleaseInputPhoneMember'),
            text: this.phoneNumber
          })
            .type(InputType.Number)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .layoutWeight(1)
            .placeholderColor('#ffC7C9CE')
            .maxLength(11)
            .fontColor('#ff337EFF')
            .onChange((value: string) => {
              this.phoneNumber = value;
            })
          // .attributeModifier(this.textInputModifier)
          Image($r('app.media.edt_close'))
            .width(17)
            .height(17)
            .onClick(() => {
              //delete text
              this.phoneNumber = ''
            })
        }.margin({ top: 40, left: 30, right: 30 })
        .borderWidth({ bottom: 1 })

        Row().height(20)

        Row() {
          TextInput({
            placeholder: $r('app.string.pleaseInputSmsCode'),
            controller: this.smsController
          })
            .width('70%')
            .type(InputType.Number)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .placeholderColor('#ffC7C9CE')
            .fontColor('#ff333333"')
            .onChange((value: string) => {
              this.smsCode = value;
            })
          Text(this.countDownTime > 0 ? $r('app.string.retryAfterCount', this.countDownTime) :
          $r('app.string.getSmsCode'))
            .fontColor(this.countDownTime > 0 ? '#ff666B73' : '#ff337EFF')
            .onClick(() => {
              if (this.phoneNumber.length <= 0) {
                promptAction.showToast({
                  message: $r('app.string.inputPhoneNumber'),
                  alignment: Alignment.Bottom
                }
                )
                return
              }
              if (this.countDownTime <= 0) {
                this.getSmsCode()
              }
            })
        }.margin({ top: 40, left: 30, right: 30 })
        .borderWidth({ bottom: 1 })

        Row() {
          TextInput({
            placeholder: $r('app.string.inputInnerIMSDKAccount'),
            controller: this.smsController
          })
            .width('100%')
            .type(InputType.Normal)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .placeholderColor('#ffC7C9CE')
            .fontColor('#ff333333"')
            .onChange((value: string) => {
              this.innerLoginAcc = value;
            })
            .visibility(this.innerIsSDKLogin() ? Visibility.Visible : Visibility.None)
        }.margin({ top: 40, left: 30, right: 30 })
        .borderWidth({ bottom: 1 })

        Row().height(40)

        Button($r("app.string.registerOrLogin"), { type: ButtonType.Normal, stateEffect: false })
          .alignSelf(ItemAlign.Center)
          .onClick(() => {
            if (this.innerSDKLogin()) {
              return
            }
            if (this.smsCode.length <= 0) {
              promptAction.showToast({
                message: $r('app.string.inputSmsCode'),
                alignment: Alignment.Bottom
              }
              )
              return
            }

            if (!AppStorage.get(this.phoneNumber) && this.isFirstRegister) {
              this.showLoginWarningDialog()
            } else {
              this.loginWithSmsCode()
            }
          })
          .borderRadius(10)
          .height(50)
          .width('90%')
          .backgroundColor(0x337EFF)
          .enabled(isLoginButtonClickable(this.phoneNumber, this.smsCode, this.isLogin))
      }.alignItems(HorizontalAlign.Start)
      .height('100%')
      .width('100%')
      .margin({ top: 10 })

    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .onShown(() => {
      if (this.isShownWarningDialog) {
        this.showLoginWarningDialog()
      }
    })
  }

  // 获取验证码
  getSmsCode() {
    let httpClient = http.createHttp();
    httpClient.request(LoginConfig.getInstance().getBaseUrl() + 'userCenter/v1/auth/sendLoginSmsCode',
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'charset': 'utf-8',
          "appkey": LoginConfig.getInstance().appKey,
          "parentScope": LoginConfig.getInstance().parentScope,
          "scope": LoginConfig.getInstance().scope,
          "lang": LoginConfig.getInstance().lang,
          "deviceId": LoginConfig.getInstance().getDeviceId(),
          "clientType": LoginConfig.getInstance().clientType
        },
        extraData: { 'mobile': this.phoneNumber },
        connectTimeout: 60000, // 可选，默认为60000ms
        readTimeout: 60000, // 可选，默认为60000ms
      }, (err, data) => {
        if (!err) {
          let obj: BaseResponse = JSON.parse(data.result as string)
          if (obj.code == 200) {
            console.info('Result:' + JSON.stringify(obj));
            this.countDownTime = this.reTryCount
            let timer = setInterval(() => {
              if (this.countDownTime > 0) {
                this.countDownTime--
              } else {
                clearInterval(timer)
              }
            }, 1000)
            if (obj.data !== null) {
              let data: SmsResult = JSON.parse(JSON.stringify(obj.data))
              if (data.isFirstRegister !== undefined) {
                this.isFirstRegister = data.isFirstRegister
              }
            }

          } else {
            promptAction.showToast({
              message: $r('app.string.getSmsCodeError', obj.code),
              alignment: Alignment.Bottom
            })
            console.info('Result:' + JSON.stringify(data.result));
          }
        } else {
          if (err.code === 2300006) {
            promptAction.showToast({
              message: $r('app.string.network_not_working', err.code),
              alignment: Alignment.Bottom
            })
          } else {
            promptAction.showToast({
              message: $r('app.string.getSmsCodeError', err.code),
              alignment: Alignment.Bottom
            })
          }
        }
        // 当该请求使用完毕时，调用destroy方法主动销毁
        httpClient.destroy();
      }
    )
  }

  //显示警告弹框
  showLoginWarningDialog() {
    this.isShownWarningDialog = true
    this.dialogController.open()
  }

  //验证码登录
  loginWithSmsCode() {
    this.isLogin = true
    console.debug(`Performance Test app start  loginSuccess`)
    let httpClient = http.createHttp();
    httpClient.request(LoginConfig.getInstance().getBaseUrl() + 'userCenter/v1/auth/loginRegisterByCode',
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'charset': 'utf-8',
          "appkey": LoginConfig.getInstance().appKey,
          "parentScope": LoginConfig.getInstance().parentScope,
          "scope": LoginConfig.getInstance().scope,
          "lang": LoginConfig.getInstance().lang,
          "deviceId": LoginConfig.getInstance().getDeviceId(),
          "clientType": LoginConfig.getInstance().clientType
        },
        extraData: { 'mobile': this.phoneNumber, 'smsCode': this.smsCode },
        connectTimeout: 60000, // 可选，默认为60000ms
        readTimeout: 60000, // 可选，默认为60000ms
      }, (err, data) => {
        if (!err) {
          let obj: BaseResponse = JSON.parse(data.result as string)
          if (obj.code == 200 && obj.data != null) {
            let user: LoginInfo = JSON.parse(JSON.stringify(obj.data))
            AuthService.instance.saveLoginInfo(getContext(this), user)
          } else {
            promptAction.showToast({
              message: $r('app.string.loginFailed', obj.code),
              alignment: Alignment.Bottom
            })
            console.info('Result:' + JSON.stringify(data.result));
            this.isLogin = false;
          }
        } else {
          if (err.code === 2300006) {
            promptAction.showToast({
              message: $r('app.string.network_not_working', err.code),
              alignment: Alignment.Bottom
            })
          } else {
            promptAction.showToast({
              message: $r('app.string.loginFailed', err.code),
              alignment: Alignment.Bottom
            })
          }
          this.isLogin = false;
        }
        // 当该请求使用完毕时，调用destroy方法主动销毁
        httpClient.destroy();
      }
    )
  }

  /**
   *  IM SDK login
   */
  private innerSDKLogin(): boolean {
    if (this.innerIsSDKLogin()) {
      this.textInputModifier.toInputTypeNormal = true // set textInput.type(InputType.Normal)
      deprecatedInnerSaveLoginInfoInner(getContext(this), this.innerLoginAcc, '123456')
      return true
    } else {
      return false
    }
  }

  private innerIsSDKLogin(): boolean {
    return JSON.parse(JSON.stringify(this.pathStack.getParamByName('DeprecatedLoginPage')))[0] === 'SDK'
  }
}

interface SmsResult {
  firstRegister?: boolean,
  isFirstRegister?: boolean
}

@CustomDialog
struct LoginWarningDialog {
  cancel?: () => void
  confirm?: () => void
  controller: CustomDialogController
  pathStack?: NavPathStack

  build() {
    Column() {
      Text($r('app.string.login_warning'))
        .fontSize(20)
        .fontFeature("bold on")
        .margin({ top: 10, bottom: 10 })
      Text() {
        Span($r('app.string.login_warning_tips_pre'))
          .fontColor('#ff999999').fontSize(12)
        Span($r('app.string.privacy_title_tips'))
          .fontColor('#ff0062e3').fontSize(12)
          .onClick(() => {
            let params: WebParams = {
              src: LoginConfig.privacyUrl,
              title: getContext(this).resourceManager.getStringSync($r('app.string.privacy_title_tips').id)
            }
            this.pathStack?.pushPath({
              name: 'WebPage',
              param: params
            })
            this.controller.close()
          })
        Span($r('app.string.user_protocol_add'))
          .fontColor('#ff999999').fontSize(12)
        Span($r('app.string.user_protocol_title_tips'))
          .fontColor('#ff0062e3').fontSize(12)
          .onClick(() => {
            let params: WebParams = {
              src: LoginConfig.privacyUrl,
              title: getContext(this).resourceManager.getStringSync($r('app.string.user_protocol_title_tips').id)
            }
            this.pathStack?.pushPath({
              name: 'WebPage',
              param: params
            })
            this.controller.close()
          })
        Span($r('app.string.login_warning_tips_after'))
          .fontColor('#ff999999').fontSize(12)
      }
      .fontSize(12).margin({ top: 10, bottom: 10 })

      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button($r('app.string.login_disagree'))
          .onClick(() => {
            this.controller.close()
            if (this.cancel) {
              this.cancel()
            }
          })
          .backgroundColor(0xffffff)
          .fontSize(14)
          .fontColor('#ff0062e3')
        Button($r('app.string.login_have_read_and_agree'))
          .onClick(() => {
            this.controller.close()
            if (this.confirm) {
              this.confirm()
            }
          })
          .backgroundColor(0xffffff)
          .fontSize(14)
          .fontColor('#ff0062e3')
      }.margin({ bottom: 10 })
    }
    .width('100%').padding({
      left: 12,
      right: 12
    })
  }
}

function isLoginButtonClickable(userName: string, password: string, isLogin: boolean): boolean {
  return userName !== '' && password !== '' && !isLogin;
}


@Builder
export function DeprecatedLoginPageBuilder() {
  DeprecatedLoginPage()
}