/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { V2NIMMessagePushConfig } from '@nimsdk/base'
import { IMKitConfigCenter } from './IMKitConfigCenter'

/**
 * 推送配置管理类
 * 单例模式，负责推送配置的解析和管理
 * 配置存储由外部通过 AppStorage 管理，与其他设置项保持一致
 */
export class PushConfigManager {
  private static _instance: PushConfigManager

  private readonly defaultConfig: string = JSON.stringify({
    pushNickEnabled: true,
    pushEnabled: true,
    payload: "{\"harmonyField\":{\"payload\": {\"notification\": {\"category\": \"IM\",\"clickAction\": {\"actionType\": 0}}},\"pushOptions\": {\"testMessage\": true}},\"harmonyPushType\":0}",
  }, null, 2)

  private constructor() {
  }

  static getInstance(): PushConfigManager {
    if (!PushConfigManager._instance) {
      PushConfigManager._instance = new PushConfigManager()
    }
    return PushConfigManager._instance
  }

  /**
   * 初始化推送配置（从 AppStorage 读取并同步到 IMKitConfigCenter）
   * @param enabled 开关状态
   * @param configContent 配置内容
   */
  initConfig(enabled: boolean, configContent: string): void {
    IMKitConfigCenter.enablePushConfig = enabled
    if (enabled && configContent.length > 0) {
      IMKitConfigCenter.pushConfig = this.parseConfig(configContent)
    } else {
      IMKitConfigCenter.pushConfig = undefined
    }
    Logger.info('ChatKit', `PushConfigManager | initConfig | enabled: ${enabled}`)
  }

  /**
   * 设置开关状态（立即生效）
   * @param enabled 开关状态
   * @param configContent 当前配置内容
   */
  setEnabled(enabled: boolean, configContent: string): void {
    IMKitConfigCenter.enablePushConfig = enabled
    if (enabled && configContent.length > 0) {
      IMKitConfigCenter.pushConfig = this.parseConfig(configContent)
    } else {
      IMKitConfigCenter.pushConfig = undefined
    }
    Logger.info('ChatKit', `PushConfigManager | setEnabled | enabled: ${enabled}`)
  }

  /**
   * 更新配置内容（立即生效）
   * @param configContent 配置内容
   * @returns 是否解析成功
   */
  updateConfig(configContent: string): boolean {
    if (!configContent || configContent.length === 0) {
      IMKitConfigCenter.pushConfig = undefined
      return true
    }

    const parsedConfig = this.parseConfig(configContent)
    if (!parsedConfig) {
      return false
    }

    if (IMKitConfigCenter.enablePushConfig) {
      IMKitConfigCenter.pushConfig = parsedConfig
    }
    Logger.info('ChatKit', `PushConfigManager | updateConfig | success`)
    return true
  }

  /**
   * 获取当前推送配置（供消息发送时调用）
   * 仅当开关开启且配置有效时返回配置对象
   */
  getPushConfig(): V2NIMMessagePushConfig | undefined {
    return IMKitConfigCenter.pushConfig
  }

  /**
   * 获取开关状态
   */
  isEnabled(): boolean {
    return IMKitConfigCenter.enablePushConfig
  }

  /**
   * 获取默认配置模板
   */
  getDefaultConfig(): string {
    return this.defaultConfig
  }

  /**
   * 解析 JSON 为推送配置
   */
  parseConfig(configJson: string): V2NIMMessagePushConfig | undefined {
    if (!configJson || configJson.length === 0) {
      return undefined
    }

    try {
      const cleanedConfig = configJson.replace(/[\n\t]/g, '')
      const dataJson = JSON.parse(cleanedConfig) as Record<string, Object>

      const pushConfig: V2NIMMessagePushConfig = {}

      if (typeof dataJson['pushNickEnabled'] === 'boolean') {
        pushConfig.pushNickEnabled = dataJson['pushNickEnabled'] as boolean
      }
      if (typeof dataJson['pushEnabled'] === 'boolean') {
        pushConfig.pushEnabled = dataJson['pushEnabled'] as boolean
      }
      if (typeof dataJson['forcePush'] === 'boolean') {
        pushConfig.forcePush = dataJson['forcePush'] as boolean
      }
      if (typeof dataJson['content'] === 'string' && (dataJson['content'] as string).length > 0) {
        pushConfig.pushContent = dataJson['content'] as string
      }
      if (typeof dataJson['payload'] === 'string' && (dataJson['payload'] as string).length > 0) {
        pushConfig.pushPayload = dataJson['payload'] as string
      }
      if (typeof dataJson['forcePushContent'] === 'string' && (dataJson['forcePushContent'] as string).length > 0) {
        pushConfig.forcePushContent = dataJson['forcePushContent'] as string
      }

      return pushConfig
    } catch (err) {
      Logger.error('ChatKit', `PushConfigManager | parseConfig error: ${err}`)
      return undefined
    }
  }
}
