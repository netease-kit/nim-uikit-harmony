/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import common from '@ohos.app.ability.common'
import { LogLevel, NIMInitializeOptions, NIMInterface, NIMServiceOptions,
  V2NIMProvidedServiceType } from '@nimsdk/base'
import { NIMSdk } from '@nimsdk/nim'
import { V2NIMTeamServiceImpl } from '@nimsdk/team'
import { V2NIMConversationServiceImpl } from '@nimsdk/conversation'
import { V2NIMUserServiceImpl } from '@nimsdk/user'
import { V2NIMFriendServiceImpl } from '@nimsdk/friend'
import { V2NIMClientAntispamUtil, V2NIMMessageServiceImpl } from '@nimsdk/message'
import { AppConfig } from '../constants/AppConfig'
import { ChatKitClient, ContactRepo, IMKitConfigCenter } from '@nimkit/chatkit'
import { router } from '@kit.ArkUI'
import { IMSDKConfigManager } from '../manager/IMSDKConfigManager'
import { V2NIMLocalConversationServiceImpl } from '@nimsdk/localconversation'
import { ChatKitUIClient } from '@nimkit/chatkit_ui/Index'
import { V2NIMSignallingServiceImpl } from '@nimsdk/signalling'
import { CallKitClient } from '../callkit/ChatKitUIClient'
import { V2NIMSearchServiceImpl } from '@nimsdk/search'
import { StartupPerfDebugTimer } from '../uitrace/StartupPerfDebugTimer'

const NON_CRITICAL_STARTUP_DELAY_MS: number = 500

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
    }
    return NimRepository.instance
  }

  async login(accountId: string, token: string, appKey: string) {
    try {
      const nim = this.nim

      ChatKitClient.init(nim, appKey, false, false)

      await nim.loginService.login(accountId, token);
      console.error('----------- 登录成功 -----------')
      StartupPerfDebugTimer.mark('im.login_success')

      ChatKitClient.saveAccountToken(token)

      await ContactRepo.getUserListFromCloud([accountId])

      // chat ui init & login CallKit
      ChatKitUIClient.setInstance(new CallKitClient())
      ChatKitUIClient.getInstance().init(this._context, nim, appKey, accountId, token)

      router.replaceUrl({
        url: 'pages/TabIndex'
      });
      StartupPerfDebugTimer.mark('route.tab_index')

      ChatKitClient.scheduleDeferredStartup(NON_CRITICAL_STARTUP_DELAY_MS)
    } catch (error) {
      StartupPerfDebugTimer.fail('im.login_failed')
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
      loginServiceConfig: {}
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
           // lbsUrls: ['https://imtest.netease.im/lbs/webconf'],
           // linkUrl: 'weblink-dev-gy.netease.im:443'
        },
        pushServiceConfig: {
          harmonyCertificateName: "DEMO_HMOS_PUSH_NEW",
          customPushContentType: "CONTENT_TYPE_TEST"
        },
        databaseServiceConfig: {
          encrypt: false,
          appKey: AppConfig.appKey,
        },
        searchServiceConfig: {
          searchAccountIdEnabled: true
        },
        localConversationServiceConfig: {
          clearUnreadAfterDeleteConversation: true
        }
      }
    }

    this.initNim(initializeOptions, serviceOptions)
    console.log("net ease nim from createDefaultNim: " + this._nim)
  }

  initNim(initializeOptions: NIMInitializeOptions, serviceOptions?: NIMServiceOptions) {
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_TEAM, (core, serviceName, serviceConfig) => new V2NIMTeamServiceImpl(core, serviceName, serviceConfig))
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_CLIENT_ANTISPAM_UTIL, (core, serviceName, serviceConfig) => new V2NIMClientAntispamUtil(core, serviceName, serviceConfig));
    // imkit_sample 为演示本地会话/云端会话切换，同时注册两个会话 service。
    // 真实接入方必须严格按 SDK 接入规范二选一注册，避免额外同步和性能开销。
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_LOCAL_CONVERSATION, (core, serviceName, serviceConfig) => new V2NIMLocalConversationServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_CONVERSATION, (core, serviceName, serviceConfig) => new V2NIMConversationServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_MESSAGE, (core, serviceName, serviceConfig) => new V2NIMMessageServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_USER, (core, serviceName, serviceConfig) => new V2NIMUserServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_FRIEND, (core, serviceName, serviceConfig) => new V2NIMFriendServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_SIGNALLING, (core, serviceName, serviceConfig) => new V2NIMSignallingServiceImpl(core, serviceName, serviceConfig));
    NIMSdk.registerCustomServices(V2NIMProvidedServiceType.V2NIM_PROVIDED_SERVICE_SEARCH, (core, serviceName, serviceConfig) => new V2NIMSearchServiceImpl(core, serviceName, serviceConfig));
    initializeOptions.isOpenConsoleLog = true
    try {
      this._nim = NIMSdk.newInstance(this._context, initializeOptions, serviceOptions)
      console.log("nim from initNim: " + this._nim)
    } catch (e) {
      console.error("nim from initNim: " + this._nim + JSON.stringify(e))
    }
  }

  isLocalConversation(): boolean {
    return IMKitConfigCenter.enableLocalConversation
  }
}
