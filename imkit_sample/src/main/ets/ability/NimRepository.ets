/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import common from '@ohos.app.ability.common'
import { NIMInitializeOptions, NIMInterface, NIMServiceOptions, V2NIMProvidedServiceType } from '@nimsdk/base'
import { NIMSdk } from '@nimsdk/nim'
import { V2NIMTeamServiceImpl } from '@nimsdk/team'
import { V2NIMConversationServiceImpl } from '@nimsdk/conversation'
import { V2NIMUserServiceImpl } from '@nimsdk/user'
import { V2NIMFriendServiceImpl } from '@nimsdk/friend'
import { V2NIMClientAntispamUtil, V2NIMMessageServiceImpl } from '@nimsdk/message'
import { V2NIMConversationGroupServiceImpl } from '@nimsdk/conversationgroup'
import { ChatKitClient } from '@nimkit/chatkit'

export class NimRepository {
  private static nimRepository: NimRepository | undefined
  private _context: common.Context
  private _nim: NIMInterface | undefined

  constructor(context: common.Context) {
    this._context = context
  }

  public static getInstance(context: common.Context): NimRepository {
    if (NimRepository.nimRepository == undefined) {
      NimRepository.nimRepository = new NimRepository(context);
    }
    return NimRepository.nimRepository
  }

  public static getNIM(): NIMInterface {
    return NimRepository.nimRepository?._nim!
  }

  initNim(initializeOptions: NIMInitializeOptions, serviceOptions?: NIMServiceOptions) {
    //初始化NIM SDK
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
    // 初始化 UI组件
    ChatKitClient.init(this._nim, initializeOptions.appkey)
  }
}