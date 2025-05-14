/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import cryptoFramework from '@ohos.security.cryptoFramework';


export class AuthService {
  public static instance: AuthService = new AuthService()
  private static loginStoreName: string = 'im_uikit_login_store'
  private static userInfoKey: string = 'im_uikit_user_key';
  private dataPreferences: preferences.Preferences | null = null;
  private loginInfo: LoginInfo | null = null
  private onLoginSuccess?: OnLoginSuccess | null

  private constructor() {
  }

  public setOnLoginSuccess(loginSuccess: OnLoginSuccess) {
    this.onLoginSuccess = loginSuccess
  }

  //存储登录信息
  public saveLoginInfo(context: Context, loginInfo: LoginInfo) {
    this.loginInfo = loginInfo
    if (this.dataPreferences == null) {
      let options: preferences.Options = { name: AuthService.loginStoreName };
      this.dataPreferences = preferences.getPreferencesSync(context, options);
    }
    this.dataPreferences.putSync(AuthService.userInfoKey, JSON.stringify(loginInfo))
    this.dataPreferences.flush((err: BusinessError) => {
      if (err) {
        console.error(`Failed to flush. Code:${err.code}, message:${err.message}`);
        return;
      }
      console.info('Succeeded in flushing.');
    })
    if (this.onLoginSuccess) {
      this.onLoginSuccess.onSuccess(loginInfo)
    }
  }

  //获取登录信息
  public getLoginInfo(context: Context): LoginInfo | null {
    if (this.loginInfo != null) {
      return this.loginInfo
    }
    if (this.dataPreferences == null) {
      let options: preferences.Options = { name: AuthService.loginStoreName };
      this.dataPreferences = preferences.getPreferencesSync(context, options);
    }
    let jsonStr = this.dataPreferences.getSync(AuthService.userInfoKey, '')
    if (jsonStr == null || (jsonStr as string).length <= 0) {
      return null
    } else {
      let loginInfo: LoginInfo = JSON.parse(jsonStr as string)
      return loginInfo
    }
  }

  public logout(context: Context): Promise<void> {
    this.loginInfo = null
    if (this.dataPreferences == null) {
      let options: preferences.Options = { name: AuthService.loginStoreName };
      this.dataPreferences = preferences.getPreferencesSync(context, options);
    }
    this.dataPreferences.deleteSync(AuthService.userInfoKey)
    return this.dataPreferences.flush()
  }
}

export interface OnLoginSuccess {
  onSuccess: (user: LoginInfo) => void
}

//用户信息
export interface LoginInfo {
  //手机号或者邮箱
  user: string;

  //账号token
  accessToken: string;

  //Im账号
  imAccid: string;
  imToken: string;
  avatar: string | null;
  avRoomUid: string | null;
  nickname: string | null;

  //业务账号
  accountId: string;
}

/**
 * Deprecated inner function, don't use
 * @deprecated
 */
export async function deprecatedInnerSaveLoginInfoInner(context: Context, accountId: string, password: string): Promise<void> {
  const token: string = await md5(password)
  const user: LoginInfo = {
    user: accountId,

    //账号token
    accessToken: token,

    //Im账号
    imAccid: accountId,
    imToken: token,
    avatar: null,
    avRoomUid: null,
    nickname: accountId,

    //业务账号
    accountId: accountId
  }
  AuthService.instance.saveLoginInfo(context, user)
}

async function md5(value: string): Promise<string> {
  let md5 = cryptoFramework.createMd("MD5");
  await md5.update({ 'data': stringToUint8Array(value) })
  return uint8ArrayToHex((await md5.digest()).data)
}


function stringToUint8Array(str: string): Uint8Array {
  let arr: number[] = [];
  for (let i = 0; i < str.length; i++) {
    arr.push(str.charCodeAt(i));
  }
  return new Uint8Array(arr);
}

function uint8ArrayToHex(array: Uint8Array): string {
  return Array.from(array).map(b => b.toString(16).padStart(2, '0')).join('');
}
