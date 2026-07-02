/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { assign, V2NIMSendMessageParams } from '@nimsdk/base'
import { PushConfigManager } from '@nimkit/chatkit'
import { ChatKitConfig } from '../ChatKitConfig'

/**
 * 构建消息发送参数，用于配置消息通用参数
 * 深拷贝 base (params)，然后用 override (ChatKitConfig/PushConfig) 覆盖
 * @param base 原始发送参数（base，如调用方设置的 pushConfig 等）
 * @returns 合并后的 V2NIMSendMessageParams；如果没有任何配置则返回 undefined
 */
export function buildSendMessageParams(base?: V2NIMSendMessageParams): V2NIMSendMessageParams | undefined {
  // 获取 override 配置
  const needReadReceipt = ChatKitConfig.messageReadState
  const pushConfig = PushConfigManager.getInstance().getPushConfig()

  // 如果没有 base 也没有 override，直接返回 undefined
  if (!base && !needReadReceipt && !pushConfig) {
    return undefined
  }

  // 深拷贝 base
  const override: V2NIMSendMessageParams = assign({}, base)

  // 应用 override: messageConfig.readReceiptEnabled
  if (needReadReceipt) {
    if (!override.messageConfig) {
      override.messageConfig = {}
    }
    override.messageConfig.readReceiptEnabled = true
  }

  // 应用 override: pushConfig
  if (pushConfig) {
    if (!override.pushConfig) {
      override.pushConfig = {}
    }
    // 逐字段覆盖，pushConfig 的配置优先
    if (pushConfig.pushEnabled !== undefined) {
      override.pushConfig.pushEnabled = pushConfig.pushEnabled
    }
    if (pushConfig.pushNickEnabled !== undefined) {
      override.pushConfig.pushNickEnabled = pushConfig.pushNickEnabled
    }
    if (pushConfig.pushContent !== undefined) {
      override.pushConfig.pushContent = pushConfig.pushContent
    }
    if (pushConfig.pushPayload !== undefined) {
      override.pushConfig.pushPayload = pushConfig.pushPayload
    }
    if (pushConfig.forcePush !== undefined) {
      override.pushConfig.forcePush = pushConfig.forcePush
    }
    if (pushConfig.forcePushContent !== undefined) {
      override.pushConfig.forcePushContent = pushConfig.forcePushContent
    }
    if (pushConfig.forcePushAccountIds !== undefined) {
      override.pushConfig.forcePushAccountIds = pushConfig.forcePushAccountIds
    }
  }

  return override
}
