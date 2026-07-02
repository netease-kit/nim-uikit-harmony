/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  V2NIMBindUserAIBotToQrCodeParams,
  V2NIMCreateUserAIBotParams,
  V2NIMCreateUserAIBotResult,
  V2NIMDeleteUserAIBotParams,
  V2NIMGetUserAIBotListParams,
  V2NIMGetUserAIBotListResult,
  V2NIMGetUserAIBotParams,
  V2NIMRefreshUserAIBotTokenParams,
  V2NIMRefreshUserAIBotTokenResult,
  V2NIMUpdateUserAIBotParams,
  V2NIMUserAIBot
} from '@nimsdk/base';
import { AIRepo } from '../repo/AIRepo';

export class UserAIBotManager {
  private static deletedBotAccids: string[] = []
  private static userAIBotMap: Map<string, V2NIMUserAIBot> = new Map()

  static markDeletedUserAIBot(accid: string): void {
    if (!accid || UserAIBotManager.deletedBotAccids.includes(accid)) {
      return
    }
    UserAIBotManager.deletedBotAccids.push(accid)
    UserAIBotManager.userAIBotMap.delete(accid)
  }

  static clearDeletedUserAIBot(accid: string): void {
    if (!accid) {
      return
    }
    UserAIBotManager.deletedBotAccids = UserAIBotManager.deletedBotAccids.filter((item: string) => item !== accid)
  }

  static isDeletedUserAIBot(accid: string): boolean {
    return !!accid && UserAIBotManager.deletedBotAccids.includes(accid)
  }

  private static cacheUserAIBot(bot?: V2NIMUserAIBot): void {
    if (!bot?.accid) {
      return
    }
    UserAIBotManager.userAIBotMap.set(bot.accid, bot)
    UserAIBotManager.clearDeletedUserAIBot(bot.accid)
  }

  private static cacheUserAIBotList(bots?: V2NIMUserAIBot[]): void {
    bots?.forEach((bot: V2NIMUserAIBot) => {
      UserAIBotManager.cacheUserAIBot(bot)
    })
  }

  static mergeLocalUserAIBot(bot?: V2NIMUserAIBot): void {
    UserAIBotManager.cacheUserAIBot(bot)
  }

  static getCachedUserAIBot(accid: string): V2NIMUserAIBot | undefined {
    if (!accid) {
      return undefined
    }
    return UserAIBotManager.userAIBotMap.get(accid)
  }

  static hasCachedUserAIBot(accid: string): boolean {
    return !!accid && UserAIBotManager.userAIBotMap.has(accid)
  }

  static async isUserAIBot(accid: string): Promise<boolean> {
    if (!accid || UserAIBotManager.isDeletedUserAIBot(accid)) {
      return false
    }
    if (UserAIBotManager.hasCachedUserAIBot(accid)) {
      return true
    }
    try {
      const bot = await AIRepo.getUserAIBot({ accid })
      UserAIBotManager.cacheUserAIBot(bot)
      return !!bot?.accid
    } catch (err) {
      Logger.error('ChatKit', 'UserAIBotManager isUserAIBot error: ' + JSON.stringify(err))
      return false
    }
  }

  static async createUserAIBot(params: V2NIMCreateUserAIBotParams): Promise<V2NIMCreateUserAIBotResult> {
    const result = await AIRepo.createUserAIBot(params)
    if (params.accid) {
      UserAIBotManager.cacheUserAIBot({
        accid: params.accid,
        name: params.name,
        icon: params.icon,
        sign: params.sign,
        ex: params.ex
      })
    }
    return result
  }

  static async getUserAIBotList(params?: V2NIMGetUserAIBotListParams): Promise<V2NIMGetUserAIBotListResult> {
    const result = await AIRepo.getUserAIBotList(params)
    UserAIBotManager.cacheUserAIBotList(result?.bots)
    return result
  }

  static async getUserAIBot(params: V2NIMGetUserAIBotParams): Promise<V2NIMUserAIBot> {
    const bot = await AIRepo.getUserAIBot(params)
    UserAIBotManager.cacheUserAIBot(bot)
    return bot
  }

  static async updateUserAIBot(params: V2NIMUpdateUserAIBotParams): Promise<void> {
    await AIRepo.updateUserAIBot(params)
    const cachedBot = UserAIBotManager.getCachedUserAIBot(params.accid)
    UserAIBotManager.cacheUserAIBot({
      accid: params.accid,
      appid: cachedBot?.appid,
      name: params.name !== undefined ? params.name : cachedBot?.name,
      icon: params.icon !== undefined ? params.icon : cachedBot?.icon,
      sign: params.sign !== undefined ? params.sign : cachedBot?.sign,
      gender: cachedBot?.gender,
      email: cachedBot?.email,
      birth: cachedBot?.birth,
      mobile: cachedBot?.mobile,
      ex: params.ex !== undefined ? params.ex : cachedBot?.ex,
      type: cachedBot?.type,
      modelConfig: cachedBot?.modelConfig,
      yunxinConfig: cachedBot?.yunxinConfig,
      validFlag: cachedBot?.validFlag,
      createTime: cachedBot?.createTime,
      updateTime: cachedBot?.updateTime,
      business: cachedBot?.business,
      level: cachedBot?.level,
      ownerid: cachedBot?.ownerid
    })
  }

  static async deleteUserAIBot(params: V2NIMDeleteUserAIBotParams): Promise<void> {
    await AIRepo.deleteUserAIBot(params)
    UserAIBotManager.markDeletedUserAIBot(params.accid)
  }

  static async refreshUserAIBotToken(params: V2NIMRefreshUserAIBotTokenParams): Promise<V2NIMRefreshUserAIBotTokenResult> {
    return await AIRepo.refreshUserAIBotToken(params)
  }

  static async bindUserAIBotToQrCode(params: V2NIMBindUserAIBotToQrCodeParams): Promise<void> {
    return await AIRepo.bindUserAIBotToQrCode(params)
  }
}
