/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  keyStickyMessageClientId,
  keyStickyMessageFrom,
  keyStickyMessageOperation,
  keyStickyMessageOperator,
  keyStickyMessageReceiverId,
  keyStickyMessageScene,
  keyStickyMessageServerId,
  keyStickyMessageTime,
  keyStickyMessageTo
} from '@nimkit/chatkit'

/**
 * 置顶消息数据模型
 * 对应 serverExtension.yxMessageTop 中的 JSON 结构
 * 与 Android TopStickyMessage 对齐
 */
export class TopStickyMessage {
  /** 消息客户端 ID */
  idClient: string = ''
  /** 会话类型 (1=群聊) */
  scene: number = 0
  /** 发送者 accountId */
  from: string = ''
  /** conversationId */
  to: string = ''
  /** 消息服务端 ID */
  idServer: string = ''
  /** 消息创建时间戳 */
  time: number = 0
  /** 操作者 accountId */
  operator: string = ''
  /** 操作类型 (0=添加, 1=移除) */
  operation: number = 0
  /** 接收者 teamId (兼容 Web 端) */
  receiverId: string = ''

  /**
   * 从 JSON 对象反序列化
   */
  static fromJson(json: object): TopStickyMessage {
    const msg = new TopStickyMessage()
    msg.idClient = (json[keyStickyMessageClientId] as string) ?? ''
    msg.scene = (json[keyStickyMessageScene] as number) ?? 0
    msg.from = (json[keyStickyMessageFrom] as string) ?? ''
    msg.to = (json[keyStickyMessageTo] as string) ?? ''
    msg.idServer = (json[keyStickyMessageServerId] as string) ?? ''
    msg.time = (json[keyStickyMessageTime] as number) ?? 0
    msg.operator = (json[keyStickyMessageOperator] as string) ?? ''
    msg.operation = (json[keyStickyMessageOperation] as number) ?? 0
    msg.receiverId = (json[keyStickyMessageReceiverId] as string) ?? ''
    return msg
  }

  /**
   * 序列化为 JSON 对象（用于添加置顶）
   */
  toJson(): Record<string, string | number> {
    const json: Record<string, string | number> = {}
    json[keyStickyMessageClientId] = this.idClient
    json[keyStickyMessageScene] = this.scene
    json[keyStickyMessageFrom] = this.from
    json[keyStickyMessageTo] = this.to
    json[keyStickyMessageServerId] = this.idServer
    json[keyStickyMessageTime] = this.time
    json[keyStickyMessageOperator] = this.operator
    json[keyStickyMessageOperation] = this.operation
    json[keyStickyMessageReceiverId] = this.receiverId
    return json
  }

  /**
   * 序列化为移除 JSON（仅含 idClient/operator/operation）
   */
  toRemoveJson(): Record<string, string | number> {
    const json: Record<string, string | number> = {}
    json[keyStickyMessageClientId] = this.idClient
    json[keyStickyMessageOperator] = this.operator
    json[keyStickyMessageOperation] = this.operation
    return json
  }
}
