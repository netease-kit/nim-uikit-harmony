/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import deviceInfo from '@ohos.deviceInfo';

export class LoginConfig {
  static baseUrlTest: string = 'https://yiyong-user-center-qa.netease.im/';
  static baseUrlOnline: string = 'https://yiyong-user-center.netease.im/';
  /// 隐私协议链接
  static privacyUrl: string =
    "https://yunxin.163.com/clauses?serviceType=3";
  static privacyUrlEN: string =
    "https://commsease.com/en/clauses?serviceType=3";
  /// 用户政策链接
  static userPoliceUrl: string = "https://yunxin.163.com/clauses";
  static userPoliceUrlEN: string =
    "https://commsease.com/en/clauses?serviceType=0";
  private static instance: LoginConfig = new LoginConfig();
  public appKey: string | null = null;
  public parentScope: number = 0;
  public scope: number = 0;
  public lang: string = 'zh';
  public deviceId: string = '';
  public clientType: number = 8;
  public isDebug: boolean = false;

  private constructor() {
  }

  public static getInstance(): LoginConfig {
    if (!LoginConfig.instance) {
      LoginConfig.instance = new LoginConfig();
    }
    return LoginConfig.instance;
  }

  public initConfig(appKey: string, parentScope: number, scope: number, isDebug: boolean, lang: string | null): void {
    this.appKey = appKey;
    this.parentScope = parentScope;
    this.scope = scope;
    this.lang = lang == null ? 'zh' : lang;
    this.isDebug = isDebug;
  }

  public getDeviceId(): string {
    if (this.deviceId === '') {
      this.deviceId = deviceInfo.udid
    }
    return this.deviceId;
  }

  public getBaseUrl(): string {
    return this.isDebug ? LoginConfig.baseUrlTest : LoginConfig.baseUrlOnline;
  }
}