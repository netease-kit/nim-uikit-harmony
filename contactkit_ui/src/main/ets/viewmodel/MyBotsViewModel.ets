/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatKitClient, UserAIBotManager } from '@nimkit/chatkit'
import { NECommonUtils } from '@nimkit/common'
import { V2NIMGetUserAIBotListResult, V2NIMUserAIBot } from '@nimsdk/base'

@ObservedV2
export class MyBotsViewModel {
  @Trace botList: V2NIMUserAIBot[] = []
  @Trace isLoading: boolean = false

  private static readonly MAX_BOT_COUNT = 10
  private static memoryBotList: V2NIMUserAIBot[] = []

  constructor() {
    if (MyBotsViewModel.memoryBotList.length > 0) {
      this.botList = [...MyBotsViewModel.memoryBotList]
    }
  }

  private static sortBots(bots: V2NIMUserAIBot[]): V2NIMUserAIBot[] {
    return [...bots].sort((a, b) => {
      const timeA = a.createTime ?? 0
      const timeB = b.createTime ?? 0
      if (timeA < timeB) {
        return 1
      }
      if (timeA > timeB) {
        return -1
      }
      return 0
    })
  }

  private restoreMemoryBotList(): boolean {
    if (MyBotsViewModel.memoryBotList.length > 0) {
      this.botList = [...MyBotsViewModel.memoryBotList]
      return true
    }
    return false
  }

  async loadBotList(): Promise<void> {
    this.isLoading = true
    try {
      if (ChatKitClient.connectBroken()) {
        this.restoreMemoryBotList()
        NECommonUtils.showToast($r('app.string.chat_network_error_tips'))
        return
      }

      const allBots: V2NIMUserAIBot[] = []
      let pageToken: string | undefined = undefined
      let hasMore = true

      while (hasMore) {
        const result: V2NIMGetUserAIBotListResult | undefined = await UserAIBotManager.getUserAIBotList(
          pageToken ? { pageToken: pageToken, limit: 100 } : { limit: 100 }
        )
        if (result && result.bots) {
          for (const bot of result.bots) {
            allBots.push(bot)
          }
          hasMore = result.hasMore
          pageToken = result.nextToken
        } else {
          hasMore = false
        }
      }

      Logger.info('ContactKit', 'MyBotsViewModel loadBotList result count: ' + allBots.length +
        ', first bot name: ' + (allBots.length > 0 ? (allBots[0].name ?? 'undefined') : 'empty'))
      const sortedBots = MyBotsViewModel.sortBots(allBots)
      this.botList = sortedBots
      MyBotsViewModel.memoryBotList = [...sortedBots]
    } catch (err) {
      Logger.error('ContactKit', 'loadBotList error: ' + JSON.stringify(err))
      const restored = this.restoreMemoryBotList()
      if (ChatKitClient.connectBroken()) {
        NECommonUtils.showToast($r('app.string.chat_network_error_tips'))
      } else if (!restored) {
        this.botList = []
      }
    } finally {
      this.isLoading = false
    }
  }

  isLimitReached(): boolean {
    return this.botList.length >= MyBotsViewModel.MAX_BOT_COUNT
  }

  removeBot(accid: string): void {
    for (let index = 0; index < this.botList.length; index++) {
      if (this.botList[index].accid === accid) {
        this.botList.splice(index, 1)
        break
      }
    }
    MyBotsViewModel.memoryBotList = [...this.botList]
  }

  updateBot(bot: V2NIMUserAIBot): boolean {
    for (let index = 0; index < this.botList.length; index++) {
      if (this.botList[index].accid === bot.accid) {
        this.botList.splice(index, 1, bot)
        MyBotsViewModel.memoryBotList = [...this.botList]
        return true
      }
    }
    return false
  }

  addBot(bot: V2NIMUserAIBot): void {
    this.botList.unshift(bot)
    MyBotsViewModel.memoryBotList = MyBotsViewModel.sortBots(this.botList)
  }
}
