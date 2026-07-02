/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMMessage,
  V2NIMRemoveTopicsParams,
  V2NIMSendMessageParams,
  V2NIMSendMessageResult,
  V2NIMSendTopicMessageParams,
  V2NIMTopic,
  V2NIMTopicListOption,
  V2NIMTopicListResult,
  V2NIMTopicMessageListOption,
  V2NIMTopicMessageListResult,
  V2NIMTopicRefer,
  V2NIMUpdateTopicParams
} from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';

export class TopicRepo {
  /**
   * 注册 Topic 新增监听。
   *
   * @param callback Topic 新增回调
   */
  static onTopicAdded(callback: (topic: V2NIMTopic) => void): void {
    ChatKitClient.nim.topicService?.on('onTopicAdded', callback)
  }

  /**
   * 取消注册 Topic 新增监听。
   *
   * @param callback Topic 新增回调
   */
  static offTopicAdded(callback: (topic: V2NIMTopic) => void): void {
    ChatKitClient.nim.topicService?.off('onTopicAdded', callback)
  }

  /**
   * 注册 Topic 删除监听。
   *
   * @param callback Topic 删除回调，参数为被删除的 Topic 引用列表
   */
  static onTopicsRemoved(callback: (topics: V2NIMTopicRefer[]) => void): void {
    ChatKitClient.nim.topicService?.on('onTopicsRemoved', callback)
  }

  /**
   * 取消注册 Topic 删除监听。
   *
   * @param callback Topic 删除回调，参数为被删除的 Topic 引用列表
   */
  static offTopicsRemoved(callback: (topics: V2NIMTopicRefer[]) => void): void {
    ChatKitClient.nim.topicService?.off('onTopicsRemoved', callback)
  }

  /**
   * 注册 Topic 更新监听。
   *
   * @param callback Topic 更新回调
   */
  static onTopicUpdated(callback: (topic: V2NIMTopic) => void): void {
    ChatKitClient.nim.topicService?.on('onTopicUpdated', callback)
  }

  /**
   * 取消注册 Topic 更新监听。
   *
   * @param callback Topic 更新回调
   */
  static offTopicUpdated(callback: (topic: V2NIMTopic) => void): void {
    ChatKitClient.nim.topicService?.off('onTopicUpdated', callback)
  }

  /**
   * 分页查询 Topic 列表。
   *
   * @param option 查询选项，包含会话 ID、时间范围、分页 token、数量和查询方向
   * @returns Topic 列表查询结果，包含 topicList、nextToken 和 hasMore
   */
  static async getTopicListByOption(option: V2NIMTopicListOption): Promise<V2NIMTopicListResult> {
    return await ChatKitClient.nim.topicService!!.getTopicListByOption(option)
  }

  /**
   * 查询指定 Topic 下的消息列表。
   *
   * @param option 查询选项，包含 Topic、时间范围、锚点消息、数量、查询方向和排序方式
   * @returns Topic 消息查询结果，包含 replyList、nextToken 和 hasMore
   */
  static async getTopicMessageList(option: V2NIMTopicMessageListOption): Promise<V2NIMTopicMessageListResult> {
    return await ChatKitClient.nim.topicService!!.getTopicMessageList(option)
  }

  /**
   * 发送 Topic 消息。
   *
   * topic 为空时 SDK 会原子性创建 Topic 并发送第一条消息；topic 不为空时向已有 Topic 发送消息。
   *
   * @param message 待发送消息
   * @param conversationId 会话 ID，当前 Topic 仅支持 P2P 会话
   * @param topic 目标 Topic；不传时创建新 Topic
   * @param params Topic 消息发送参数
   * @param progress 文件或媒体消息上传进度回调
   * @returns 消息发送结果
   */
  static async sendTopicMessage(
    message: V2NIMMessage,
    conversationId: string,
    topic?: V2NIMTopic,
    params?: V2NIMSendTopicMessageParams,
    progress?: (percentage: number) => void
  ): Promise<V2NIMSendMessageResult> {
    return await ChatKitClient.nim.topicService!!.sendTopicMessage(message, conversationId, topic, params, progress)
  }

  /**
   * 回复 Topic 内消息。
   *
   * replyMessage 必须属于入参 topic。
   *
   * @param message 待发送回复消息
   * @param replyMessage 被回复的 Topic 消息
   * @param topic 目标 Topic
   * @param params 消息发送参数
   * @param progress 文件或媒体消息上传进度回调
   * @returns 消息发送结果
   */
  static async replyTopicMessage(
    message: V2NIMMessage,
    replyMessage: V2NIMMessage,
    topic: V2NIMTopic,
    params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void
  ): Promise<V2NIMSendMessageResult> {
    return await ChatKitClient.nim.topicService!!.replyTopicMessage(message, replyMessage, topic, params, progress)
  }

  /**
   * 更新 Topic。
   *
   * @param params 更新参数，其中 params.topic 用于定位 Topic
   * @returns 更新后的 Topic 对象
   */
  static async updateTopic(params: V2NIMUpdateTopicParams): Promise<V2NIMTopic> {
    return await ChatKitClient.nim.topicService!!.updateTopic(params)
  }

  /**
   * 批量删除 Topic。
   *
   * @param params 删除参数，包含待删除 Topic 列表
   */
  static async removeTopics(params: V2NIMRemoveTopicsParams): Promise<void> {
    return await ChatKitClient.nim.topicService!!.removeTopics(params)
  }

  /**
   * 通过 Topic 引用查询 Topic。
   *
   * SDK 优先查询本地缓存，未命中时再从服务端拉取。
   *
   * @param topicRefer Topic 引用，包含 conversationId、topicId 和 createTime
   * @returns 引用关联的 Topic；未命中时返回 undefined
   */
  static async getTopicByRefer(topicRefer: V2NIMTopicRefer): Promise<V2NIMTopic | undefined> {
    return await ChatKitClient.nim.topicService!!.getTopicByRefer(topicRefer)
  }
}
