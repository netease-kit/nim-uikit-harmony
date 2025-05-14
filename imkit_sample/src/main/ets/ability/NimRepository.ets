/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import common from '@ohos.app.ability.common'
import { LogLevel, NIMInitializeOptions, NIMInterface, NIMServiceOptions,
  V2NIMEnableServiceType,
  V2NIMProvidedServiceType } from '@nimsdk/base'
import { NIMSdk } from '@nimsdk/nim'
import { V2NIMTeamServiceImpl } from '@nimsdk/team'
import { V2NIMConversationServiceImpl } from '@nimsdk/conversation'
import { V2NIMUserServiceImpl } from '@nimsdk/user'
import { V2NIMFriendServiceImpl } from '@nimsdk/friend'
import { V2NIMClientAntispamUtil, V2NIMMessageServiceImpl } from '@nimsdk/message'
import { AppConfig } from '../constants/AppConfig'
import { ChatKitClient, IMKitConfigCenter } from '@nimkit/chatkit'
import { router } from '@kit.ArkUI'
import { IMSDKConfigManager } from '../manager/IMSDKConfigManager'
import { V2NIMLocalConversationServiceImpl } from '@nimsdk/localconversation'

export class NimRepository {
  private static instance?: NimRepository
  private _context: common.Context

  constructor(context: common.Context) {
    this._context = context
  }

  private _nim: NIMInterface | undefined

  public get nim(): NIMInterface {
    if (!this._nim) {
      this.createDefaultNim(this._context)
    }

    return this._nim!
  }

  public static getInstance(context: common.Context): NimRepository {
    if (!NimRepository.instance) {
      NimRepository.instance = new NimRepository(context)
      NimRepository.instance.nim
    }
    return NimRepository.instance
  }

  async login(accountId: string, token: string, appKey: string) {
    try {
      console.debug(`Performance Test im start loginSuccess`)
      await this.nim.loginService.login(accountId, token);
      console.error('----------- 登录成功 -----------')
      console.debug(`Performance Test im loginSuccess`)

      ChatKitClient.init(this.nim, appKey)

      router.replaceUrl({
        url: 'pages/TabIndex'
      });
    } catch (error) {
      console.error('----------- 登录失败 -----------', error)
      throw error as Error
    }
  }

  createDefaultNim(context: common.Context) {
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

    const customConfig = IMSDKConfigManager.getConfig()
    if (customConfig?.enableCustomConfig) {
      if (customConfig.configOptions) {
        serviceOptions = customConfig.configOptions
        let appKey = serviceOptions.databaseServiceConfig?.appKey
        if (appKey) {
          initializeOptions.appkey = appKey
        }
      }
    } else {
      serviceOptions = {
        loginServiceConfig: {
           lbsUrls: ['https://lbs.netease.im/lbs/webconf.jsp'],
           linkUrl: 'weblink.netease.im:443'
          //lbsUrls: ['https://imtest.netease.im/lbs/webconf'],
          //linkUrl: 'imtest-jd.netease.im:8091'
        },
        pushServiceConfig: {
          harmonyCertificateName: "DEMO_HMOS_PUSH"
        },
        databaseServiceConfig: {
          encrypt: false,
          appKey: AppConfig.appKey,
        }
      }
    }

    this.initNim(initializeOptions, serviceOptions)
    console.log("net ease nim from createDefaultNim: " + this._nim)
  }

  initNim(initializeOptions: NIMInitializeOptions, serviceOptions?: NIMServiceOptions) {
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_TEAM,
      (core, serviceName, serviceConfig) => new V2NIMTeamServiceImpl(core, serviceName, serviceConfig))
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_CLIENT_ANTISPAM_UTIL,
      (core, serviceName, serviceConfig) => new V2NIMClientAntispamUtil(core, serviceName, serviceConfig));
    if (IMKitConfigCenter.enableLocalConversation) {
      NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_LOCAL_CONVERSATION,
        (core, serviceName, serviceConfig) => new V2NIMLocalConversationServiceImpl(core, serviceName, serviceConfig));
    } else {
      NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_CONVERSATION,
        (core, serviceName, serviceConfig) => new V2NIMConversationServiceImpl(core, serviceName, serviceConfig));
    }
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_MESSAGE,
      (core, serviceName, serviceConfig) => new V2NIMMessageServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_USER,
      (core, serviceName, serviceConfig) => new V2NIMUserServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_FRIEND,
      (core, serviceName, serviceConfig) => new V2NIMFriendServiceImpl(core, serviceName, serviceConfig));
    initializeOptions.isOpenConsoleLog = true
    this._nim = NIMSdk.newInstance(this._context, initializeOptions, serviceOptions)
    console.log("nim from initNim: " + this._nim)
  }

  isLocalConversation(): boolean {
    if (this._nim?.isServiceEnable(V2NIMEnableServiceType.LOCAL_CONVERSATION)) {
      return true
    }

    return false
  }
}