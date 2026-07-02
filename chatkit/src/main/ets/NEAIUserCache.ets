/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { AIRepo } from './repo/AIRepo';
import { HashMap } from '@kit.ArkTS';
import { V2NIMAIUser, V2NIMUser } from '@nimsdk/base';
import { ContactRepo } from './repo/ContactRepo';
import { ChatKitClient } from './ChatKitClient';

@ObservedV2
export class NEAIUserCache {
  private aiUserMap: HashMap<string, V2NIMAIUser> = new HashMap()
  private mineUser: V2NIMUser | undefined = undefined

  private constructor() {
    AIRepo.addListener()
  }

  public static getInstance() {
    if (!AppStorage.get<NEAIUserCache>(NEAIUserCache.name)) {
      const instance: NEAIUserCache = new NEAIUserCache()
      AppStorage.setOrCreate<NEAIUserCache>(NEAIUserCache.name, instance);
    }
    return AppStorage.get<NEAIUserCache>(NEAIUserCache.name) as NEAIUserCache;
  }

  public static removeInstance() {
    AIRepo.removeListener()
    NEAIUserCache.clear()
    AppStorage.delete(NEAIUserCache.name)
  }

  public static getAIUser(accountId: string): V2NIMAIUser | undefined {
    const instance = NEAIUserCache.getInstance()
    return instance.aiUserMap.get(accountId)
  }

  public static getAIUserList(): V2NIMAIUser[] {
    const instance = NEAIUserCache.getInstance()
    return Array.from(instance.aiUserMap.values())
      .sort((left, right) => {
      // desc by create time
      return right.createTime - left.createTime
    })
  }

  public static setAIUser(aiUser: V2NIMAIUser): void {
    const instance = NEAIUserCache.getInstance()
    instance.aiUserMap.set(aiUser.accountId, aiUser)
  }

  public static clear(): void {
    const instance = NEAIUserCache.getInstance()
    instance.aiUserMap.clear()
    instance.mineUser = undefined
  }

  public static clearAIUsers(): void {
    const instance = NEAIUserCache.getInstance()
    instance.aiUserMap.clear()
  }

  public static getMineUser(): V2NIMUser | undefined {
    const instance = NEAIUserCache.getInstance()
    return instance.mineUser
  }

  public static setMineUser(me: V2NIMUser): void {
    const instance = NEAIUserCache.getInstance()
    instance.mineUser = me
  }

  public static load(): void {
    const instance = NEAIUserCache.getInstance()
    instance.load()
  }

  public async load(): Promise<void> {
    // search from cloud
    const aiUsers: V2NIMAIUser[] = await AIRepo.getAIUserList()
    const userList: V2NIMUser[] = await ContactRepo.getUserListFromCloud([ChatKitClient.getLoginUserId()])
    NEAIUserCache.clear()
    userList.map((user) => {
      if (user.accountId === ChatKitClient.getLoginUserId()) {
        NEAIUserCache.setMineUser(user)
      }
    })
    aiUsers.map((aiUser) => {
      NEAIUserCache.setAIUser(aiUser)
    })

    // send load complete event
    AIRepo.listener.emit('onLoadAIUserComplete')
  }
}
