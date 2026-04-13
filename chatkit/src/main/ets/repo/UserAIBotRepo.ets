/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

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
import { ChatKitClient } from '../ChatKitClient';

export class UserAIBotRepo {
  private static deletedBotAccids: string[] = []

  static markDeletedUserAIBot(accid: string): void {
    if (!accid || UserAIBotRepo.deletedBotAccids.includes(accid)) {
      return
    }
    UserAIBotRepo.deletedBotAccids.push(accid)
  }

  static clearDeletedUserAIBot(accid: string): void {
    if (!accid) {
      return
    }
    UserAIBotRepo.deletedBotAccids = UserAIBotRepo.deletedBotAccids.filter((item: string) => item !== accid)
  }

  static isDeletedUserAIBot(accid: string): boolean {
    return !!accid && UserAIBotRepo.deletedBotAccids.includes(accid)
  }

  /**
   * 创建一个用户级 AI Bot 账号
   *
   * @param params 创建参数
   * @returns 创建结果，包含 Bot 的登录密钥
   */
  static async createUserAIBot(params: V2NIMCreateUserAIBotParams): Promise<V2NIMCreateUserAIBotResult | undefined> {
    const result = await ChatKitClient.nim.aiService?.createUserAIBot(params)
    if (result && params.accid) {
      UserAIBotRepo.clearDeletedUserAIBot(params.accid)
    }
    return result
  }

  /**
   * 分页查询当前用户名下的所有用户级 AI Bot 账号列表
   *
   * @param params 查询参数，可选
   * @returns 查询结果，包含 Bot 列表和分页信息
   */
  static async getUserAIBotList(params?: V2NIMGetUserAIBotListParams): Promise<V2NIMGetUserAIBotListResult | undefined> {
    return await ChatKitClient.nim.aiService?.getUserAIBotList(params)
  }

  /**
   * 更新当前用户名下的指定用户级 AI Bot 账号信息
   *
   * @param params 更新参数
   */
  static async updateUserAIBot(params: V2NIMUpdateUserAIBotParams): Promise<void> {
    await ChatKitClient.nim.aiService?.updateUserAIBot(params)
    UserAIBotRepo.clearDeletedUserAIBot(params.accid)
  }

  /**
   * 删除当前用户名下的指定用户级 AI Bot 账号
   *
   * @param params 删除参数
   */
  static async deleteUserAIBot(params: V2NIMDeleteUserAIBotParams): Promise<void> {
    await ChatKitClient.nim.aiService?.deleteUserAIBot(params)
    UserAIBotRepo.markDeletedUserAIBot(params.accid)
  }

  /**
   * 刷新指定用户级 AI Bot 账号的登录密钥
   *
   * @param params 刷新参数
   * @returns 刷新结果，包含新的登录密钥
   */
  static async getUserAIBot(params: V2NIMGetUserAIBotParams): Promise<V2NIMUserAIBot | undefined> {
    try {
      const bot = await ChatKitClient.nim.aiService?.getUserAIBot(params)
      if (bot?.accid) {
        UserAIBotRepo.clearDeletedUserAIBot(bot.accid)
      }
      return bot
    } catch (e) {
      console.error('UserAIBotRepo getUserAIBot error', e)
      return undefined
    }
  }

  static async refreshUserAIBotToken(params: V2NIMRefreshUserAIBotTokenParams): Promise<V2NIMRefreshUserAIBotTokenResult | undefined> {
    return await ChatKitClient.nim.aiService?.refreshUserAIBotToken(params)
  }

  static async bindUserAIBotToQrCode(params: V2NIMBindUserAIBotToQrCodeParams): Promise<void> {
    return await ChatKitClient.nim.aiService?.bindUserAIBotToQrCode(params)
  }
}
