/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMConversationType,
  V2NIMLocalConversation,
  V2NIMLocalConversationFilter,
  V2NIMLocalConversationOperationResult,
  V2NIMLocalConversationOption,
  V2NIMLocalConversationResult,
} from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';

export class LocalConversationRepo {
  /**
   * 获取会话列表
   *
   * @param offset 分页偏移量. 首页应传 0, 其他页数据使用返回的 offset
   * @param limit 分页拉取数量，不建议超过 100
   */
  static async getConversationList(offset: number, limit: number): Promise<V2NIMLocalConversationResult | null> {
    return await ChatKitClient.nim.localConversationService?.getConversationList(offset, limit) ?? null
  }

  /**
   * 置顶会话
   *
   * 注: 在操作成功且是有效的操作时, 则触发事件 {@link V2NIMConversationListener.onConversationChanged | V2NIMConversationListener.onConversationChanged}
   *
   * @param conversationId 会话 id
   * @param stickTop 是否置顶. true: 置顶, false: 取消置顶.
   */
  static async stickTopConversation(conversationId: string, stickTop: boolean): Promise<void> {
    return await ChatKitClient.nim.localConversationService?.stickTopConversation(conversationId, stickTop)
  }

  /**
   * 删除会话
   *
   * 注: 在操作成功且是有效的操作时, 会抛出事件 {@link V2NIMConversationListener.onConversationDeleted | V2NIMConversationListener.onConversationCreated}
   *
   * @param conversationId 会话 id
   * @param clearMessage 是否删除会话对应的历史消息. 默认为 false
   */
  static async deleteConversation(conversationId: string, clearMessage?: boolean): Promise<void> {
    return await ChatKitClient.nim.localConversationService?.deleteConversation(conversationId, clearMessage)
  }

  /**
   * 获取会话列表. 可以指定筛选条件，按会话类型，未读等
   *
   * @param offset 会话标记. 首页应传 0, 其他页数据使用返回的 offset
   * @param limit 分页拉取数量, 不建议超过100
   * @param option 查询选项
   *
   */
  static async getConversationListByOption(offset: number, limit: number,
    option: V2NIMLocalConversationOption): Promise<V2NIMLocalConversationResult | undefined> {
    return await ChatKitClient.nim.localConversationService?.getConversationListByOption(offset, limit, option)
  }

  /**
   * 根据会话 id 获取单条会话
   *
   * @param conversationId 会话 id
   */
  static async getConversation(conversationId: string): Promise<V2NIMLocalConversation | undefined> {
    return await ChatKitClient.nim.localConversationService?.getConversation(conversationId)
  }

  /**
   * 根据会话 id 获取会话列表
   *
   * @param conversationIds 会话 id 列表
   *
   */
  static async getConversationListByIds(conversationIds: string[]): Promise<V2NIMLocalConversation[] | undefined> {
    return await ChatKitClient.nim.localConversationService?.getConversationListByIds(conversationIds)
  }

  /**
   * 创建会话
   *
   * 注: 在操作成功且是有效的操作时, 会抛出事件 {@link V2NIMConversationListener.onConversationCreated | V2NIMConversationListener.onConversationCreated}
   *
   * @param conversationId 会话 id
   *
   */
  static async createConversation(conversationId: string): Promise<V2NIMLocalConversation | undefined> {
    return await ChatKitClient.nim.localConversationService?.createConversation(conversationId)
  }

  /**
   * 批量删除会话
   *
   * 注: 在操作成功且是有效的操作时, 会抛出事件 {@link V2NIMConversationListener.onConversationDeleted | V2NIMConversationListener.onConversationDeleted}
   *
   * @param conversationIds 会话 id 列表
   * @param clearMessage 是否删除会话对应的历史消息. 默认为 false
   * @returns 返回操作失败的列表，列表的对象包含会话 id 以及错误信息.
   */
  static async deleteConversationListByIds(conversationIds: string[],
    clearMessage?: boolean): Promise<V2NIMLocalConversationOperationResult[] | undefined> {
    return await ChatKitClient.nim.localConversationService?.deleteConversationListByIds(conversationIds, clearMessage)
  }

  /**
   * 更新会话
   *
   * 注: 在操作成功且是有效的操作时, 触发事件 {@link V2NIMConversationListener.onConversationChanged | V2NIMConversationListener.onConversationChanged}
   *
   * @param conversationId 会话 id
   * @param updateInfo 欲更新的信息
   *
   */
  // static async updateConversation(conversationId: string, updateInfo: V2NIMLocalConversationUpdate): Promise<void> {
  //   return await ChatKitClient.nim.localConversationService?.updateConversation(conversationId, updateInfo)
  // }

  /**
   * 更新会话的本地扩展字段
   *
   * 注: 在操作成功且是有效的操作时, 触发事件 {@link V2NIMConversationListener.onConversationChanged | V2NIMConversationListener.onConversationChanged}
   *
   * 注2: 字段只能存在内存里, 不能持久化存储. 登出或者重新初始化后 localExtension 都会再次成为空字符串.
   *
   * @param conversationId 会话 id
   * @param localExtension 本地扩展信息
   *
   */
  static async updateConversationLocalExtension(conversationId: string, localExtension: string): Promise<void> {
    return await ChatKitClient.nim.localConversationService?.updateConversationLocalExtension(conversationId,
      localExtension)
  }

  /**
   * 获取全部会话的总的未读数
   *
   */
  static getTotalUnreadCount(): number | undefined {
    return ChatKitClient.nim.localConversationService?.getTotalUnreadCount()
  }

  /**
   * 根据 id 列表获取会话的未读数
   *
   * @param conversationIds 会话 id 列表
   *
   */
  static async getUnreadCountByIds(conversationIds: string[]): Promise<number | undefined> {
    return await ChatKitClient.nim.localConversationService?.getUnreadCountByIds(conversationIds)
  }

  /**
   * 根据过滤参数获取相应的未读信息
   *
   * @param filter 过滤条件
   */
  static async getUnreadCountByFilter(filter: V2NIMLocalConversationFilter): Promise<number | undefined> {
    return await ChatKitClient.nim.localConversationService?.getUnreadCountByFilter(filter)
  }

  /**
   * 清空所有会话总的未读数
   *
   * 注: 当该方法调用后，SDK 可能给开发者抛出以下的事件
   *
   * {@link V2NIMConversationListener.onConversationChanged | V2NIMConversationListener.onConversationChanged} <br/>
   * {@link V2NIMConversationListener.onTotalUnreadCountChanged | V2NIMConversationListener.onTotalUnreadCountChanged} <br/>
   * {@link V2NIMConversationListener.onUnreadCountChangedByFilter | V2NIMConversationListener.onUnreadCountChangedByFilter}
   */
  static async clearTotalUnreadCount(): Promise<void> {
    return await ChatKitClient.nim.localConversationService?.clearTotalUnreadCount()
  }

  /**
   * 根据会话 id 列表清空相应会话的未读数
   *
   * 注: 当该方法调用后，SDK 可能给开发者抛出以下的事件
   *
   * {@link V2NIMConversationListener.onConversationChanged | V2NIMConversationListener.onConversationChanged} <br/>
   * {@link V2NIMConversationListener.onTotalUnreadCountChanged | V2NIMConversationListener.onTotalUnreadCountChanged} <br/>
   * {@link V2NIMConversationListener.onUnreadCountChangedByFilter | V2NIMConversationListener.onUnreadCountChangedByFilter}
   *
   * @param conversationIds 会话 id 列表
   * @returns 返回操作失败结果的列表
   */
  static async clearUnreadCountByIds(conversationIds: string[]): Promise<V2NIMLocalConversationOperationResult[] | undefined> {
    return await ChatKitClient.nim.localConversationService?.clearUnreadCountByIds(conversationIds)
  }

  /**
   * 清除对应指定分组下的会话的未读数
   *
   * 注: 当该方法调用后，SDK 可能给开发者抛出以下的事件
   *
   * {@link V2NIMConversationListener.onConversationChanged | V2NIMConversationListener.onConversationChanged} <br/>
   * {@link V2NIMConversationListener.onTotalUnreadCountChanged | V2NIMConversationListener.onTotalUnreadCountChanged} <br/>
   * {@link V2NIMConversationListener.onUnreadCountChangedByFilter | V2NIMConversationListener.onUnreadCountChangedByFilter}
   *
   * @param groupId 指定的会话分组 id
   */
  // static async clearUnreadCountByGroupId(groupId: string): Promise<void> {
  //   return await ChatKitClient.nim.localConversationService?.clearUnreadCountByGroupId(groupId)
  // }

  /**
   * 清除对应指定类型下的会话的未读数
   *
   * 注: 当该方法调用后，SDK 可能给开发者抛出以下的事件
   *
   * {@link V2NIMConversationListener.onConversationChanged | V2NIMConversationListener.onConversationChanged} <br/>
   * {@link V2NIMConversationListener.onTotalUnreadCountChanged | V2NIMConversationListener.onTotalUnreadCountChanged} <br/>
   * {@link V2NIMConversationListener.onUnreadCountChangedByFilter | V2NIMConversationListener.onUnreadCountChangedByFilter}
   *
   * @param types 指定的会话类型列表
   */
  static async clearUnreadCountByTypes(types: V2NIMConversationType[]): Promise<void> {
    return await ChatKitClient.nim.localConversationService?.clearUnreadCountByTypes(types)
  }

  /**
   * 订阅指定过滤条件的会话未读数变化
   *
   * 注1: 当订阅该条件后，该 filter 下的未读数发生变化时, 触发 {@link V2NIMConversationListener.onUnreadCountChangedByFilter | V2NIMConversationListener.onUnreadCountChangedByFilter} 事件
   *
   * 注2: 同一种 filter 只能被订阅一次, 第二次的调用不会有任何效果
   *
   * @param filter 过滤条件
   */
  static subscribeUnreadCountByFilter(filter: V2NIMLocalConversationFilter) {
    return ChatKitClient.nim.localConversationService?.subscribeUnreadCountByFilter(filter)
  }

  /**
   * 取消订阅指定过滤条件的会话未读变化
   *
   * @param filter 过滤条件
   */
  static unsubscribeUnreadCountByFilter(filter: V2NIMLocalConversationFilter) {
    return ChatKitClient.nim.localConversationService?.unsubscribeUnreadCountByFilter(filter)
  }

  /**
   * 标记会话已读时间戳
   *
   * 注: 当该方法调用后，SDK 可能给多端账户抛出以下的事件
   *
   * {@link V2NIMConversationListener.onConversationReadTimeUpdated | V2NIMConversationListener.onConversationReadTimeUpdated} <br/>
   *
   */
  static async markConversationRead(conversationId: string): Promise<number | undefined> {
    return await ChatKitClient.nim.localConversationService?.markConversationRead(conversationId)
  }

  /**
   * 获取会话已读时间戳。该时间包含多端已读时间戳
   */
  static async getConversationReadTime(conversationId: string): Promise<number | undefined> {
    return await ChatKitClient.nim.localConversationService?.getConversationReadTime(conversationId)
  }

  /**
   * 移除会话的所有监听
   */
  static removeAllConversationListener() {
    //移除
    ChatKitClient.nim.localConversationService?.removeAllListeners('onSyncFinished')

    //会话创建
    ChatKitClient.nim.localConversationService?.removeAllListeners("onConversationCreated")

    //会话删除
    ChatKitClient.nim.localConversationService?.removeAllListeners("onConversationDeleted")
    //会话更新
    ChatKitClient.nim.localConversationService?.removeAllListeners("onConversationChanged")
  }
}