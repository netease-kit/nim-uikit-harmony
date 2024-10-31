/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import common from '@ohos.app.ability.common'
import { LogLevel, NIMInitializeOptions, NIMInterface, NIMServiceOptions, V2NIMProvidedServiceType } from '@nimsdk/base'
import { NIMSdk } from '@nimsdk/nim'
import { V2NIMTeamServiceImpl } from '@nimsdk/team'
import { V2NIMConversationServiceImpl } from '@nimsdk/conversation'
import { V2NIMUserServiceImpl } from '@nimsdk/user'
import { V2NIMFriendServiceImpl } from '@nimsdk/friend'
import { V2NIMClientAntispamUtil, V2NIMMessageServiceImpl } from '@nimsdk/message'
import { V2NIMConversationGroupServiceImpl } from '@nimsdk/conversationgroup'
import { AppConfig } from '../constants/AppConfig'
import { ChatKitClient } from '@nimkit/chatkit'
import { router } from '@kit.ArkUI'

export class NimRepository {
  private static instance?: NimRepository
  private _context: common.Context

  constructor(context: common.Context) {
    this._context = context
  }

  private _nim: NIMInterface | undefined

  public get nim(): NIMInterface {
    if (!this._nim) {
      this.init(this._context)
    }

    return this._nim!
  }

  public static getInstance(context: common.Context): NimRepository {
    if (!NimRepository.instance) {
      NimRepository.instance = new NimRepository(context)
    }
    return NimRepository.instance
  }

  async login(accountId: string, token: string, appKey: string) {
    try {
      await this.nim.loginService.login(accountId, token);
      console.error('----------- 登录成功 -----------')

      router.replaceUrl({
        url: 'pages/TabIndex'
      });
    } catch (error) {
      console.error('----------- 登录失败 -----------', error)
    }
  }

  init(context: common.Context) {
    console.warn('------------- 创建NIM实例 --------------')

    let initializeOptions: NIMInitializeOptions = {
      appkey: "xxx",
    }

    let serviceOptions: NIMServiceOptions = {
      loginServiceConfig: {},
    }

    // 正式服
    initializeOptions = {
      appkey: AppConfig.appKey,
      logLevel: LogLevel.Debug,
      // ...其他属性
    };

    serviceOptions = {
      loginServiceConfig: {
        lbsUrls: ['https://lbs.netease.im/lbs/webconf.jsp'],
        linkUrl: 'weblink.netease.im:443'
      },
      pushServiceConfig: {
        harmonyCertificateName: "DEMO_HMOS_PUSH"
      },
      databaseServiceConfig: {
        encrypt: false,
        appKey: AppConfig.appKey,
      }
    }

    this.initNim(initializeOptions, serviceOptions)
    ChatKitClient.init(this.nim, AppConfig.appKey)
    console.log("net ease nim from createDefaultNim: " + this._nim)
  }

  initNim(initializeOptions: NIMInitializeOptions, serviceOptions?: NIMServiceOptions) {
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_TEAM,
      (core, serviceName, serviceConfig) => new V2NIMTeamServiceImpl(core, serviceName, serviceConfig))
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_CLIENT_ANTISPAM_UTIL,
      (core, serviceName, serviceConfig) => new V2NIMClientAntispamUtil(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_CONVERSATION,
      (core, serviceName, serviceConfig) => new V2NIMConversationServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_CONVERSATION_GROUP,
      (core, serviceName, serviceConfig) => new V2NIMConversationGroupServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_MESSAGE,
      (core, serviceName, serviceConfig) => new V2NIMMessageServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_USER,
      (core, serviceName, serviceConfig) => new V2NIMUserServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_FRIEND,
      (core, serviceName, serviceConfig) => new V2NIMFriendServiceImpl(core, serviceName, serviceConfig));
    this._nim = NIMSdk.newInstance(this._context, initializeOptions, serviceOptions)
    console.log("nim from initNim: " + this._nim)
  }
}