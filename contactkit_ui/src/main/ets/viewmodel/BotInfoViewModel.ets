/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { UserAIBotManager } from '@nimkit/chatkit'
import { V2NIMGetUserAIBotListResult, V2NIMUserAIBot } from '@nimsdk/base'

@ObservedV2
export class BotInfoViewModel {
  @Trace bot: V2NIMUserAIBot | undefined = undefined
  @Trace isLoading: boolean = false
  @Trace lastToken: string = ''
  accid: string = ''

  async loadBot(): Promise<void> {
    this.isLoading = true
    try {
      let pageToken: string | undefined = undefined
      let found = false
      while (!found) {
        const result: V2NIMGetUserAIBotListResult | undefined =
          await UserAIBotManager.getUserAIBotList({ limit: 100, pageToken: pageToken })
        if (result && result.bots) {
          for (const bot of result.bots) {
            if (bot.accid === this.accid) {
              this.bot = bot
              found = true
              break
            }
          }
        }
        if (!found && result && result.hasMore && result.nextToken) {
          pageToken = result.nextToken
        } else {
          break
        }
      }
    } catch (err) {
      Logger.error('ContactKit', 'loadBot error: ' + JSON.stringify(err))
    } finally {
      this.isLoading = false
    }
  }

  async updateBotName(name: string): Promise<boolean> {
    try {
      await UserAIBotManager.updateUserAIBot({ accid: this.accid, name: name })
      if (this.bot) {
        const updated: V2NIMUserAIBot = {
          accid: this.bot.accid,
          appid: this.bot.appid,
          name: name,
          icon: this.bot.icon,
          sign: this.bot.sign,
          gender: this.bot.gender,
          email: this.bot.email,
          birth: this.bot.birth,
          mobile: this.bot.mobile,
          ex: this.bot.ex,
          type: this.bot.type,
          modelConfig: this.bot.modelConfig,
          yunxinConfig: this.bot.yunxinConfig,
          validFlag: this.bot.validFlag,
          createTime: this.bot.createTime,
          updateTime: this.bot.updateTime,
          business: this.bot.business,
          level: this.bot.level,
          ownerid: this.bot.ownerid
        }
        this.bot = updated
      }
      return true
    } catch (err) {
      Logger.error('ContactKit', 'updateBotName error: ' + JSON.stringify(err))
      return false
    }
  }

  async updateBotAvatar(icon: string): Promise<boolean> {
    try {
      await UserAIBotManager.updateUserAIBot({ accid: this.accid, icon: icon })
      if (this.bot) {
        const updated: V2NIMUserAIBot = {
          accid: this.bot.accid,
          appid: this.bot.appid,
          name: this.bot.name,
          icon: icon,
          sign: this.bot.sign,
          gender: this.bot.gender,
          email: this.bot.email,
          birth: this.bot.birth,
          mobile: this.bot.mobile,
          ex: this.bot.ex,
          type: this.bot.type,
          modelConfig: this.bot.modelConfig,
          yunxinConfig: this.bot.yunxinConfig,
          validFlag: this.bot.validFlag,
          createTime: this.bot.createTime,
          updateTime: this.bot.updateTime,
          business: this.bot.business,
          level: this.bot.level,
          ownerid: this.bot.ownerid
        }
        this.bot = updated
      }
      return true
    } catch (err) {
      Logger.error('ContactKit', 'updateBotAvatar error: ' + JSON.stringify(err))
      return false
    }
  }

  updateBotLocal(name: string, icon: string): void {
    if (this.bot) {
      const updated: V2NIMUserAIBot = {
        accid: this.bot.accid,
        appid: this.bot.appid,
        name: name,
        icon: icon.length > 0 ? icon : this.bot.icon,
        sign: this.bot.sign,
        gender: this.bot.gender,
        email: this.bot.email,
        birth: this.bot.birth,
        mobile: this.bot.mobile,
        ex: this.bot.ex,
        type: this.bot.type,
        modelConfig: this.bot.modelConfig,
        yunxinConfig: this.bot.yunxinConfig,
        validFlag: this.bot.validFlag,
        createTime: this.bot.createTime,
        updateTime: this.bot.updateTime,
        business: this.bot.business,
        level: this.bot.level,
        ownerid: this.bot.ownerid
      }
      this.bot = updated
      UserAIBotManager.mergeLocalUserAIBot(updated)
    }
  }

  async deleteBot(): Promise<boolean> {
    try {
      await UserAIBotManager.deleteUserAIBot({ accid: this.accid })
      return true
    } catch (err) {
      Logger.error('ContactKit', 'deleteBot error: ' + JSON.stringify(err))
      return false
    }
  }

  async refreshToken(): Promise<string | undefined> {
    try {
      const result = await UserAIBotManager.refreshUserAIBotToken({ accid: this.accid })
      if (result) {
        this.lastToken = result.token
        return result.token
      }
      return undefined
    } catch (err) {
      Logger.error('ContactKit', 'refreshToken error: ' + JSON.stringify(err))
      return undefined
    }
  }

  getMaskedToken(): string {
    if (this.lastToken.length <= 0) {
      return '******'
    }
    if (this.lastToken.length <= 8) {
      return this.lastToken.substring(0, 2) + '****' + this.lastToken.substring(this.lastToken.length - 2)
    }
    return this.lastToken.substring(0, 4) + '****' + this.lastToken.substring(this.lastToken.length - 4)
  }
}
