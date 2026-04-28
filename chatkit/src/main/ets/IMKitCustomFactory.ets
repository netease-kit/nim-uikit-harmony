/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { MessageCallback } from './listener/MessageCallback'
import { ChatRepo } from './repo/ChatRepo'

/**
 * IMKit 自定义工厂类，提供个性化定制能力口子
 * 包括发送消息定制、群组定制、用户信息定制等能力
 */
export class IMKitCustomFactory {
  /**
   * 设置消息发送前监听
   * 在消息发送前回调，用于修改发送消息的内容和发送参数
   * @param callback 消息发送回调
   */
  static setMessageSendCallback(callback: MessageCallback): void {
    ChatRepo.sendCallback = callback
  }

  /**
   * 移除消息发送前监听
   */
  static removeMessageSendCallback(): void {
    ChatRepo.sendCallback = undefined
  }
}
