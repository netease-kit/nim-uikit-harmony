/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, AIRepo, NEAIUserCache, NEUserWithFriend } from '@nimkit/chatkit'
import { V2NIMAIUser, V2NIMUser } from '@nimsdk/base'
import { SearchListModel } from '../model/SearchListModel'


export enum AI_USER_EXT_KEY {
  /**
   * 是否默认置顶,1 置顶，0 不置顶
   */
  KEY_PIN_DEFAULT = 'pinDefault',
  /**
   * 是否ai聊,1是，0否
   */
  KEY_AI_CHAT = 'aiChat',
  /**
   * 欢迎语
   */
  KEY_WELCOME_TEXT = 'welcomeText'
}

export enum MINE_EXT_AI_KEY {
  /**
   * 不被 PIN 的数字人列表 KEY
   */
  KEY_NOT_PIN_AI_USER_LIST = 'unpinAIUsers'
}

export class V2NIMAIUserEx {
  /**
   * user 源数据
   */
  user: V2NIMAIUser
  /**
   * 是否默认置顶,1 置顶，0 不置顶
   */
  pinDefault: boolean
  /**
   * 是否ai聊,1是，0否
   */
  aiChat: boolean
  /**
   * 欢迎语
   */
  welcomeText: string

  constructor(user: V2NIMAIUser, unPinList: string[]) {
    this.user = user
    this.pinDefault = false
    this.aiChat = false
    this.welcomeText = 'hello world'
    if (user.serverExtension) {
      let obj: object | undefined = undefined
      try {
        obj = JSON.parse(user.serverExtension)
      } catch (e) {
        // ignore syntax error
      }
      if (obj) {
        this.pinDefault = obj[AI_USER_EXT_KEY.KEY_PIN_DEFAULT] === '1'
        this.aiChat = obj[AI_USER_EXT_KEY.KEY_AI_CHAT] === '1'
        this.welcomeText = obj[AI_USER_EXT_KEY.KEY_WELCOME_TEXT] ?? 'hello world'
      }
    }
    if (this.pinDefault && unPinList.includes(user.accountId)) {
      this.pinDefault = false
    }
  }
}

@ObservedV2
export class AIUsersViewModel {
  @Trace aiUserList: V2NIMAIUserEx[] = []
  @Trace searchAIUsersData: SearchListModel[] = []

  onDataLoaded = () => {
    const aiUserList: V2NIMAIUser[] = NEAIUserCache.getAIUserList()
    const mineUser: V2NIMUser | undefined = NEAIUserCache.getMineUser()
    let unPinList: string[] = []
    if (mineUser && mineUser.serverExtension) {
      let obj: object | undefined = undefined
      try {
        obj = JSON.parse(mineUser.serverExtension)
      } catch (e) {
        // ignore syntax error
      }
      if (obj && obj[MINE_EXT_AI_KEY.KEY_NOT_PIN_AI_USER_LIST]) {
        unPinList = obj[MINE_EXT_AI_KEY.KEY_NOT_PIN_AI_USER_LIST] as string[]
      }
    }
    const exList = aiUserList.map((user) => {
      return new V2NIMAIUserEx(user, unPinList)
    })
    this.aiUserList = exList
    return
  }

  // 搜索（本地）
  doSearchAI(text?: string) {
    // 清除上一次搜索结果
    this.searchAIUsersData = []

    if (text) {
      // 搜索好友
      this.aiUserList.forEach((aiUser: V2NIMAIUserEx) => {
        if (aiUser.user) {
          if (aiUser.user.name.includes(text)
            || aiUser.user.accountId.includes(text))
          {
            const aiUserSearch: NEUserWithFriend = new NEUserWithFriend({
              user:  aiUser.user,
              friend: undefined
            })
            const model = new SearchListModel({
              userInfo: aiUserSearch
            })
            this.searchAIUsersData.push(model)
          }
        }
      })

    }

    this.searchAIUsersData.sort((s1: SearchListModel, s2: SearchListModel) => {
      if ((s1.userInfo?.showName() ?? "") < (s2.userInfo?.showName() ?? "")) {
        return -1
      }
      if ((s1.userInfo?.showName() ?? "") > (s2.userInfo?.showName() ?? "")) {
        return 1
      }
      return 0
    })
  }

  public loadAIUserCache(): void {
    this.onDataLoaded()
  }

  public loadAIUsers(): void {
    NEAIUserCache.load()
  }

  constructor() {
    AIRepo.listener.on('onLoadAIUserComplete', this.onDataLoaded)
  }

  onDestroy() {
    AIRepo.listener.off('onLoadAIUserComplete', this.onDataLoaded)
  }
}
