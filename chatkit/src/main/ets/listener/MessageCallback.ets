/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMMessage, V2NIMSendMessageParams } from '@nimsdk/base'

/**
 * 消息发送参数
 */
export interface MessageSendParams {
  /** 会话 ID */
  conversationId: string
  /** 消息体 */
  message: V2NIMMessage
  /** 发送参数 */
  params?: V2NIMSendMessageParams
}

/**
 * 消息发送回调接口
 * 用于在消息发送前进行拦截和修改
 */
export interface MessageCallback {
  /**
   * 消息发送前回调
   * @param param 消息发送参数
   * @returns 修改后的消息发送参数，返回 undefined 则拦截该消息不发送
   */
  beforeSend(param: MessageSendParams): MessageSendParams | undefined
}
