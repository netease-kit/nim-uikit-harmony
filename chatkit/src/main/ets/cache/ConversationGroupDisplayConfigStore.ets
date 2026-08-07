/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import common from '@ohos.app.ability.common'
import { preferences } from '@kit.ArkData'

export const CONVERSATION_GROUP_DEFAULT_ALL_KEY: string = 'default_all'
export const CONVERSATION_GROUP_DEFAULT_AIT_KEY: string = 'default_ait'
export const CONVERSATION_GROUP_DEFAULT_UNREAD_KEY: string = 'default_unread'
const CONVERSATION_GROUP_DISPLAY_CONFIG_VERSION: number = 1
const CONVERSATION_GROUP_DISPLAY_CONFIG_KEY_PREFIX: string = 'conversation_group_display_config_'
const CONVERSATION_GROUP_PREFERENCES_NAME: string = 'imkit_data'

export enum ConversationGroupCreateSource {
  LOCAL = 'local',
  REMOTE = 'remote'
}

export interface ConversationGroupDisplayConfig {
  version: number
  accountId: string
  visibleGroupKeys: string[]
  hiddenGroupKeys: string[]
  updateTime: number
}

export interface ConversationGroupDisplayConfigStorage {
  getString(key: string): string | undefined
  putString(key: string, value: string): void
  flush(): void
}

class ConversationGroupDisplayNormalizeResult {
  config: ConversationGroupDisplayConfig
  changed: boolean

  constructor(config: ConversationGroupDisplayConfig, changed: boolean) {
    this.config = config
    this.changed = changed
  }
}

export class PreferencesConversationGroupDisplayConfigStorage implements ConversationGroupDisplayConfigStorage {
  private preferences: preferences.Preferences

  constructor(context: common.Context) {
    this.preferences = preferences.getPreferencesSync(context, { name: CONVERSATION_GROUP_PREFERENCES_NAME })
  }

  getString(key: string): string | undefined {
    const value = this.preferences.getSync(key, undefined)
    if (typeof value === 'string') {
      return value
    }
    return undefined
  }

  putString(key: string, value: string): void {
    this.preferences.putSync(key, value)
  }

  flush(): void {
    this.preferences.flush()
  }
}

export class ConversationGroupDisplayConfigStore {
  private storage: ConversationGroupDisplayConfigStorage
  private now: () => number
  private configs: Map<string, ConversationGroupDisplayConfig> = new Map()
  private cloudGroupIdsByAccount: Map<string, string[]> = new Map()

  constructor(storage: ConversationGroupDisplayConfigStorage, now: () => number = () => Date.now()) {
    this.storage = storage
    this.now = now
  }

  load(accountId: string, cloudGroupIds: string[]): ConversationGroupDisplayConfig {
    this.cloudGroupIdsByAccount.set(accountId, this.uniqueCustomGroupKeys(cloudGroupIds, cloudGroupIds))
    const config = this.readConfig(accountId)
    const normalized = this.normalizeConfig(accountId, config)
    this.configs.set(accountId, normalized.config)
    if (config === undefined || normalized.changed) {
      this.save(accountId)
    }
    return this.cloneConfig(normalized.config)
  }

  getSnapshot(accountId: string): ConversationGroupDisplayConfig | undefined {
    const config = this.configs.get(accountId)
    if (config === undefined) {
      return undefined
    }
    return this.cloneConfig(config)
  }

  normalize(accountId: string, cloudGroupIds: string[]): ConversationGroupDisplayConfig {
    this.cloudGroupIdsByAccount.set(accountId, this.uniqueCustomGroupKeys(cloudGroupIds, cloudGroupIds))
    let config = this.configs.get(accountId)
    if (config === undefined) {
      config = this.readConfig(accountId)
    }
    const normalized = this.normalizeConfig(accountId, config)
    this.configs.set(accountId, normalized.config)
    if (config === undefined || normalized.changed) {
      this.save(accountId)
    }
    return this.cloneConfig(normalized.config)
  }

  moveToVisible(accountId: string, groupKey: string): ConversationGroupDisplayConfig {
    const config = this.ensureLoadedConfig(accountId)
    if (groupKey === CONVERSATION_GROUP_DEFAULT_ALL_KEY) {
      return this.cloneConfig(config)
    }
    this.removeKey(config.visibleGroupKeys, groupKey)
    this.removeKey(config.hiddenGroupKeys, groupKey)
    config.visibleGroupKeys.push(groupKey)
    this.commitNormalized(accountId, config)
    return this.cloneConfig(this.ensureLoadedConfig(accountId))
  }

  moveToHidden(accountId: string, groupKey: string): ConversationGroupDisplayConfig {
    const config = this.ensureLoadedConfig(accountId)
    if (groupKey === CONVERSATION_GROUP_DEFAULT_ALL_KEY) {
      return this.cloneConfig(config)
    }
    this.removeKey(config.visibleGroupKeys, groupKey)
    this.removeKey(config.hiddenGroupKeys, groupKey)
    config.hiddenGroupKeys.push(groupKey)
    this.commitNormalized(accountId, config)
    return this.cloneConfig(this.ensureLoadedConfig(accountId))
  }

  reorderVisible(accountId: string, groupKeys: string[]): ConversationGroupDisplayConfig {
    const config = this.ensureLoadedConfig(accountId)
    config.visibleGroupKeys = groupKeys.slice()
    this.commitNormalized(accountId, config)
    return this.cloneConfig(this.ensureLoadedConfig(accountId))
  }

  onGroupCreated(accountId: string, groupId: string, source: ConversationGroupCreateSource): ConversationGroupDisplayConfig {
    const config = this.ensureLoadedConfig(accountId)
    this.addCloudGroupId(accountId, groupId)
    if (config.visibleGroupKeys.includes(groupId) || config.hiddenGroupKeys.includes(groupId)) {
      return this.cloneConfig(config)
    }
    if (source === ConversationGroupCreateSource.LOCAL) {
      config.visibleGroupKeys.push(groupId)
    } else {
      config.hiddenGroupKeys.push(groupId)
    }
    this.commitNormalized(accountId, config)
    return this.cloneConfig(this.ensureLoadedConfig(accountId))
  }

  onLocalGroupCreated(accountId: string, groupId: string): ConversationGroupDisplayConfig {
    this.addCloudGroupId(accountId, groupId)
    return this.moveToVisible(accountId, groupId)
  }

  onGroupDeleted(accountId: string, groupId: string): ConversationGroupDisplayConfig {
    const config = this.ensureLoadedConfig(accountId)
    if (!config.visibleGroupKeys.includes(groupId) && !config.hiddenGroupKeys.includes(groupId)) {
      return this.cloneConfig(config)
    }
    const cloudGroupIds = this.cloudGroupIdsByAccount.get(accountId) ?? []
    this.cloudGroupIdsByAccount.set(accountId, cloudGroupIds.filter((item: string): boolean => item !== groupId))
    this.removeKey(config.visibleGroupKeys, groupId)
    this.removeKey(config.hiddenGroupKeys, groupId)
    this.commitNormalized(accountId, config)
    return this.cloneConfig(this.ensureLoadedConfig(accountId))
  }

  private ensureLoadedConfig(accountId: string): ConversationGroupDisplayConfig {
    let config = this.configs.get(accountId)
    if (config === undefined) {
      config = this.load(accountId, this.cloudGroupIdsByAccount.get(accountId) ?? [])
      this.configs.set(accountId, config)
    }
    return config
  }

  private readConfig(accountId: string): ConversationGroupDisplayConfig | undefined {
    const raw = this.storage.getString(this.storageKey(accountId))
    if (!raw) {
      return undefined
    }
    try {
      const value = JSON.parse(raw) as ConversationGroupDisplayConfig
      if (value.accountId !== accountId || !Array.isArray(value.visibleGroupKeys) ||
        !Array.isArray(value.hiddenGroupKeys)) {
        return undefined
      }
      return {
        version: CONVERSATION_GROUP_DISPLAY_CONFIG_VERSION,
        accountId: accountId,
        visibleGroupKeys: value.visibleGroupKeys.slice(),
        hiddenGroupKeys: value.hiddenGroupKeys.slice(),
        updateTime: typeof value.updateTime === 'number' ? value.updateTime : this.now()
      }
    } catch (e) {
      return undefined
    }
  }

  private commitNormalized(accountId: string, config: ConversationGroupDisplayConfig): void {
    const normalized = this.normalizeConfig(accountId, config)
    this.configs.set(accountId, normalized.config)
    this.save(accountId)
  }

  private normalizeConfig(accountId: string,
    sourceConfig?: ConversationGroupDisplayConfig): ConversationGroupDisplayNormalizeResult {
    const cloudGroupIds = this.cloudGroupIdsByAccount.get(accountId) ?? []
    const sourceVisible = sourceConfig?.visibleGroupKeys ?? [
      CONVERSATION_GROUP_DEFAULT_ALL_KEY,
      CONVERSATION_GROUP_DEFAULT_AIT_KEY,
      CONVERSATION_GROUP_DEFAULT_UNREAD_KEY
    ]
    const sourceHidden = sourceConfig?.hiddenGroupKeys ?? []
    const visible: string[] = []
    const hidden: string[] = []

    visible.push(CONVERSATION_GROUP_DEFAULT_ALL_KEY)
    this.appendValidKeys(visible, sourceVisible, cloudGroupIds, [CONVERSATION_GROUP_DEFAULT_ALL_KEY])
    this.appendValidKeys(hidden, sourceHidden, cloudGroupIds, visible)

    if (!visible.includes(CONVERSATION_GROUP_DEFAULT_AIT_KEY) && !hidden.includes(CONVERSATION_GROUP_DEFAULT_AIT_KEY)) {
      visible.push(CONVERSATION_GROUP_DEFAULT_AIT_KEY)
    }
    if (!visible.includes(CONVERSATION_GROUP_DEFAULT_UNREAD_KEY) &&
      !hidden.includes(CONVERSATION_GROUP_DEFAULT_UNREAD_KEY)) {
      visible.push(CONVERSATION_GROUP_DEFAULT_UNREAD_KEY)
    }
    cloudGroupIds.forEach((groupId: string) => {
      if (!visible.includes(groupId) && !hidden.includes(groupId)) {
        hidden.push(groupId)
      }
    })

    const updateTime = this.now()
    const config: ConversationGroupDisplayConfig = {
      version: CONVERSATION_GROUP_DISPLAY_CONFIG_VERSION,
      accountId: accountId,
      visibleGroupKeys: visible,
      hiddenGroupKeys: hidden,
      updateTime: updateTime
    }
    const changed = sourceConfig === undefined ||
      !this.arrayEquals(sourceConfig.visibleGroupKeys, visible) ||
      !this.arrayEquals(sourceConfig.hiddenGroupKeys, hidden) ||
      sourceConfig.version !== CONVERSATION_GROUP_DISPLAY_CONFIG_VERSION
    return new ConversationGroupDisplayNormalizeResult(config, changed)
  }

  private appendValidKeys(target: string[], source: string[], cloudGroupIds: string[], excludes: string[]): void {
    source.forEach((groupKey: string) => {
      if (!this.isValidGroupKey(groupKey, cloudGroupIds)) {
        return
      }
      if (target.includes(groupKey) || excludes.includes(groupKey)) {
        return
      }
      target.push(groupKey)
    })
  }

  private isValidGroupKey(groupKey: string, cloudGroupIds: string[]): boolean {
    return groupKey === CONVERSATION_GROUP_DEFAULT_ALL_KEY ||
      groupKey === CONVERSATION_GROUP_DEFAULT_AIT_KEY ||
      groupKey === CONVERSATION_GROUP_DEFAULT_UNREAD_KEY ||
      cloudGroupIds.includes(groupKey)
  }

  private save(accountId: string): void {
    const config = this.configs.get(accountId)
    if (config === undefined) {
      return
    }
    config.updateTime = this.now()
    this.storage.putString(this.storageKey(accountId), JSON.stringify(config))
    this.storage.flush()
  }

  private storageKey(accountId: string): string {
    return `${CONVERSATION_GROUP_DISPLAY_CONFIG_KEY_PREFIX}${accountId}`
  }

  private addCloudGroupId(accountId: string, groupId: string): void {
    const cloudGroupIds = this.cloudGroupIdsByAccount.get(accountId) ?? []
    if (!cloudGroupIds.includes(groupId)) {
      cloudGroupIds.push(groupId)
      this.cloudGroupIdsByAccount.set(accountId, cloudGroupIds)
    }
  }

  private uniqueCustomGroupKeys(source: string[], cloudGroupIds: string[]): string[] {
    const result: string[] = []
    source.forEach((groupId: string) => {
      if (!groupId || result.includes(groupId)) {
        return
      }
      if (groupId === CONVERSATION_GROUP_DEFAULT_ALL_KEY ||
        groupId === CONVERSATION_GROUP_DEFAULT_AIT_KEY ||
        groupId === CONVERSATION_GROUP_DEFAULT_UNREAD_KEY) {
        return
      }
      if (!cloudGroupIds.includes(groupId)) {
        return
      }
      result.push(groupId)
    })
    return result
  }

  private removeKey(source: string[], groupKey: string): void {
    let index = source.indexOf(groupKey)
    while (index >= 0) {
      source.splice(index, 1)
      index = source.indexOf(groupKey)
    }
  }

  private cloneConfig(config: ConversationGroupDisplayConfig): ConversationGroupDisplayConfig {
    return {
      version: config.version,
      accountId: config.accountId,
      visibleGroupKeys: config.visibleGroupKeys.slice(),
      hiddenGroupKeys: config.hiddenGroupKeys.slice(),
      updateTime: config.updateTime
    }
  }

  private arrayEquals(left: string[], right: string[]): boolean {
    if (left.length !== right.length) {
      return false
    }
    for (let index = 0; index < left.length; index++) {
      if (left[index] !== right[index]) {
        return false
      }
    }
    return true
  }
}
