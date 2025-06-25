/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { AIRepo, ChatKitClient } from '@nimkit/chatkit'
import { V2NIMAIUser, } from '@nimsdk/base'
import { Constant } from '../loader/Constant'

@ObservedV2
export class ConversationAIViewModel {
  static logTag = 'ConversationAIViewModel'
  //是否已经加载完成
  public isFinished: boolean = false
  //会话列表数据
  @Trace aiUsers?: V2NIMAIUser[]
  @Trace isFinishedSyncLoad?: boolean = false
  // 网络连接状态
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()

  initAIUsers() {
    // 首先拉取一次
    this.loadAIUsers()

    // // 添加监听
    // ChatKitClient.nim.localConversationService?.on('onSyncFinished',
    //   async () => {
    //     //同步完成拉一次
    //     ChatKitClient.logger?.debug(`${ConversationAIViewModel.logTag} onSyncFinished`)
    //     await this.loadAIUsers(0)
    //     this.isFinishedSyncLoad = true
    //   }
    // )
  }

  /**
   * 请求回话列表
   * @param offset
   */
  async loadAIUsers() {
    try {
      if (!this.aiUsers) {
        this.aiUsers = []
      }
      console.debug(`Performance Test start  loadLocalConversation`)
      this.aiUsers?.splice(0, this.aiUsers.length);
      const result: V2NIMAIUser[] = await AIRepo.getAIUserList()
      if (result) {
        this.aiUsers?.splice(0, this.aiUsers.length);
        this.isFinished = true
        this.isFinishedSyncLoad = true
        this.aiUsers?.push(...result)
        // this.aiUsers?.sort((left, right) => this.sortConversation(a, b)) // no need to sort
        console.debug(`Performance Test finish  loadLocalConversation`)
      }
    } catch (e) {
      // ignore
    }
  }
}