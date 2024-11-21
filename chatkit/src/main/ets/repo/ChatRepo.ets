/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMAddCollectionParams,
  V2NIMCollection,
  V2NIMCollectionOption,
  V2NIMMessage,
  V2NIMMessageDeletedNotification,
  V2NIMMessageListOption,
  V2NIMMessagePin,
  V2NIMMessagePinNotification,
  V2NIMMessageRefer,
  V2NIMMessageRevokeNotification,
  V2NIMMessageRevokeParams,
  V2NIMMessageSearchParams,
  V2NIMP2PMessageReadReceipt,
  V2NIMSendMessageParams,
  V2NIMSendMessageResult,
  V2NIMTeamMessageReadReceipt,
  V2NIMTeamMessageReadReceiptDetail
} from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';

export class ChatRepo {
  /**
   * 发送消息
   * @param sendFn 消息接受处理方法
   */
  static onSendMessage(sendFn: (message: V2NIMMessage) => void) {
    ChatKitClient.nim.messageService?.on("onSendMessage", sendFn);
  }

  /**
   * 发送消息
   * @param receiveFn 消息接受处理方法
   */
  static offSendMessage(receiveFn: (message: V2NIMMessage) => void) {
    ChatKitClient.nim.messageService?.off("onSendMessage", receiveFn);
  }

  /**
   * 接受消息
   * @param receiveFn 消息接受处理方法
   */
  static onReceiverMessage(receiveFn: (messageList: V2NIMMessage[]) => void) {
    ChatKitClient.nim.messageService?.on("onReceiveMessages", receiveFn);
  }

  /**
   * 接受消息
   * @param receiveFn 消息接受处理方法
   */
  static offReceiverMessage(receiveFn: (messageList: V2NIMMessage[]) => void) {
    ChatKitClient.nim.messageService?.off("onReceiveMessages", receiveFn);
  }

  /**
   * 删除消息
   * @param receiveFn 消息接受处理方法
   */
  static onDeleteMessage(deleteFn: (messageList: V2NIMMessageDeletedNotification[]) => void) {
    ChatKitClient.nim.messageService?.on("onMessageDeletedNotifications", deleteFn);
  }

  /**
   * 删除消息
   * @param receiveFn 消息接受处理方法
   */
  static offDeleteMessage(deleteFn: (messageList: V2NIMMessageDeletedNotification[]) => void) {
    ChatKitClient.nim.messageService?.off("onMessageDeletedNotifications", deleteFn);
  }

  /**
   * 注册撤回消息监听
   * @param receiveFn 消息接受处理方法
   */
  static onRevokeMessage(revokeFn: (messageList: V2NIMMessageRevokeNotification[]) => void) {
    ChatKitClient.nim.messageService?.on("onMessageRevokeNotifications", revokeFn);
  }

  /**
   * 取消注册撤回消息监听
   * @param receiveFn 消息接受处理方法
   */
  static offRevokeMessage(revokeFn: (messageList: V2NIMMessageRevokeNotification[]) => void) {
    ChatKitClient.nim.messageService?.off("onMessageRevokeNotifications", revokeFn);
  }

  /**
   * 注册单聊消息已读回执监听
   * @param receiptsFn 单聊消息已读回执处理方法
   */
  static onP2PMessageReadReceipts(receiptsFn: (messageList: V2NIMP2PMessageReadReceipt[]) => void) {
    ChatKitClient.nim.messageService?.on("onReceiveP2PMessageReadReceipts", receiptsFn);
  }

  /**
   * 取消注册单聊消息已读回执监听
   * @param receiptsFn 单聊消息已读回执处理方法
   */
  static offP2PMessageReadReceipts(receiptsFn: (messageList: V2NIMP2PMessageReadReceipt[]) => void) {
    ChatKitClient.nim.messageService?.off("onReceiveP2PMessageReadReceipts", receiptsFn);
  }

  /**
   * 注册群消息已读回执监听
   * @param receiptsFn 群消息已读回执处理方法
   */
  static onReceiveTeamMessageReadReceipts(receiptsFn: (messageList: V2NIMTeamMessageReadReceipt[]) => void) {
    ChatKitClient.nim.messageService?.on("onReceiveTeamMessageReadReceipts", receiptsFn);
  }

  /**
   * 取消注册群消息已读回执监听
   * @param receiptsFn 群消息已读回执处理方法
   */
  static offReceiveTeamMessageReadReceipts(receiptsFn: (messageList: V2NIMTeamMessageReadReceipt[]) => void) {
    ChatKitClient.nim.messageService?.off("onReceiveTeamMessageReadReceipts", receiptsFn);
  }

  /**
   * 注册PIN消息监听
   * @param pinFn PIN消息监听处理方法
   */
  static onMessagePinNotification(pinFn: (notification: V2NIMMessagePinNotification) => void) {
    ChatKitClient.nim.messageService?.on("onMessagePinNotification", pinFn);
  }

  /**
   * 取消注册PIN消息监听
   * @param pinFn PIN消息监听处理方法
   */
  static offMessagePinNotification(pinFn: (notification: V2NIMMessagePinNotification) => void) {
    ChatKitClient.nim.messageService?.off("onMessagePinNotification", pinFn);
  }

  /**
   * 撤回消息
   * @param receiveFn 消息接受处理方法
   */
  static removeAllListeners(revokeFn: (messageList: V2NIMMessageRevokeNotification[]) => void) {
    ChatKitClient.nim.messageService?.removeAllListeners("onMessageRevokeNotifications");
  }

  /**
   * 查询消息
   * @param option
   * @returns
   */
  static async getMessageList(option: V2NIMMessageListOption): Promise<V2NIMMessage[]> {
    let messageList = await ChatKitClient.nim.messageService!!.getMessageList(option)
    return messageList;
  }

  /**
   * 根据 messageRefers 批量查询消息
   * @param option
   * @returns
   */
  static async getMessageListByRefers(messageRefers: V2NIMMessageRefer[]): Promise<V2NIMMessage[]> {
    let messageList = await ChatKitClient.nim.messageService!!.getMessageListByRefers(messageRefers)
    return messageList ?? [];
  }

  /**
   * 检索云端的消息
   *
   * @param params 检索参数
   */
  static async searchCloudMessages(params: V2NIMMessageSearchParams): Promise<V2NIMMessage[]> {
    let messageList = await ChatKitClient.nim.messageService!!.searchCloudMessages(params)
    return messageList ?? [];
  }

  /**
   * 发送消息
   *
   * @param message 消息体, 由 V2NIMMessageCreator 的对应方法创建
   * @param conversationId 会话 id
   * @param params 发送消息相关配置参数
   * @param progress 发送消息进度回调. 作用于需要上传的文件，图片，音视频消息
   */
  static async sendMessage(
    message: V2NIMMessage,
    conversationId: string,
    params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void
  ): Promise<V2NIMSendMessageResult | undefined> {
    return ChatKitClient.nim.messageService?.sendMessage(message, conversationId, params, progress);
  }

  /**
   * 回复消息
   *
   * @param message 需要发送的消息体, 由 V2NIMMessageCreator 的对应方法创建
   * @param replyMessage 被回复的消息
   * @param params 发送消息相关配置参数
   * @param progress 发送消息进度回调. 作用于需要上传的文件，图片，音视频消息
   */
  static async replyMessage(message: V2NIMMessage, replyMessage: V2NIMMessage, params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void): Promise<V2NIMSendMessageResult> {
    const res = await ChatKitClient.nim.messageService?.replyMessage(message, replyMessage, params, progress);
    return res!;
  }

  /**
   * 插入一条本地消息， 该消息不会发送。该消息不会多端同步，只是本端显示
   * @param message 需要插入的消息体
   * @param conversationId 会话 ID
   * @param senderId 消息发送者账号
   * @param createTime 指定插入消息时间
   * @returns 插入成功的 message
   */
  static async insertMessageToLocal(message: V2NIMMessage, conversationId: string, senderId?: string, createTime?: number): Promise<V2NIMMessage> {
    const res = ChatKitClient.nim.messageService?.insertMessageToLocal(message, conversationId, senderId, createTime);
    return res!;
  }

  /**
   * 撤回消息
   *
   * @param message 需要撤回的消息
   * @param params 撤回消息相关参数
   */
  static async revokeMessage(message: V2NIMMessage, params?: V2NIMMessageRevokeParams): Promise<void> {
    const res = await ChatKitClient.nim.messageService?.revokeMessage(message, params);
    return res!;
  }

  /**
   * 删除单条消息
   *
   * 注: 操作成功后, SDK 会抛出事件 {@link V2NIMMessageListener.onMessageDeletedNotifications | V2NIMMessageListener.onMessageDeletedNotifications}
   *
   * @param message 需要删除的消息
   * @param serverExtension 扩展字段
   */
  static async deleteMessage(message: V2NIMMessage, serverExtension?: string,
    onlyDeleteLocal?: boolean): Promise<void> {
    const res = await ChatKitClient.nim.messageService?.deleteMessage(message, serverExtension, onlyDeleteLocal);
    return res!;
  }

  /**
   * 批量删除消息
   *
   * 注: 操作成功后, SDK 会抛出事件 {@link V2NIMMessageListener.onMessageDeletedNotifications | V2NIMMessageListener.onMessageDeletedNotifications} <br/>
   * - 所删除的消息必须是同一会话的消息 <br/>
   * - 限制一次最多删除 50 条消息
   *
   * @param messages 需要删除的消息
   * @param serverExtension 扩展字段
   */
  static async deleteMessages(messages: V2NIMMessage[], serverExtension?: string,
    onlyDeleteLocal?: boolean): Promise<void> {
    const res = await ChatKitClient.nim.messageService?.deleteMessages(messages, serverExtension, onlyDeleteLocal);
    return res!;
  }

  /**
   * pin 一条消息
   *
   * @param message 需要被 pin 的消息体
   * @param serverExtension 扩展字段
   *
   * 注: 操作成功后, SDK 会抛出事件 {@link V2NIMMessageListener.onMessagePinNotification | V2NIMMessageListener.onMessagePinNotification}
   */
  static async pinMessage(message: V2NIMMessage, serverExtension?: string): Promise<void> {
    const res = await ChatKitClient.nim.messageService?.pinMessage(message, serverExtension);
    return res!;
  }

  /**
   * 取消一条Pin消息
   *
   * @param messageRefer 需要被取消 pin 的消息摘要
   * @param serverExtension 扩展字段
   */
  static async unpinMessage(messageRefer: V2NIMMessageRefer, serverExtension?: string): Promise<void> {
    const res = await ChatKitClient.nim.messageService?.unpinMessage(messageRefer, serverExtension);
    return res!;
  }

  /**
   * 获取 pin 消息列表
   *
   * @param conversationId 会话 ID
   */
  static async getPinnedMessageList(conversationId: string): Promise<V2NIMMessagePin[]> {
    const res = ChatKitClient.nim.messageService?.getPinnedMessageList(conversationId);
    return res!;
  }

  /**
   * 添加一个收藏
   *
   * @param params 添加收藏的相关参数
   */
  static async addCollection(params: V2NIMAddCollectionParams): Promise<V2NIMCollection> {
    const res = await ChatKitClient.nim.messageService?.addCollection(params)
    return res!;
  }

  /**
   * 移除相关收藏
   *
   * @param collections 需要移除的相关收藏
   */
  static async removeCollections(collections: V2NIMCollection[]): Promise<number> {
    const res = await ChatKitClient.nim.messageService?.removeCollections(collections)
    return res!;
  }

  /**
   * 按条件分页获取收藏信息
   *
   * @param option 查询参数
   */
  static async getCollectionListByOption(option: V2NIMCollectionOption): Promise<V2NIMCollection[]>{
    const res = ChatKitClient.nim.messageService?.getCollectionListByOption(option)
    return res!;
  }

  /**
   * 构造文本消息
   *
   * @param text 文本内容. 不允许为空字符串
   *
   * @example
   * ```
   * const message = nim.V2NIMMessageCreator.createTextMessage('hello world')
   * ```
   */
  static createTextMessage(text: string): V2NIMMessage {
    return ChatKitClient.nim.messageCreator.createTextMessage(text);
  }

  /**
   * 构造图片消息
   *
   * @param imagePath 图片文件路径
   * @param name 文件显示名称
   * @param sceneName 场景名
   * @param width 图片宽度.
   * @param height 图片高度.
   */
  static async createImageMessage(imagePath: string, name?: string, sceneName?: string, width?: number,
    height?: number): Promise<V2NIMMessage> {
    return ChatKitClient.nim.messageCreator.createImageMessage(imagePath, name, sceneName, width, height);
  }

  /**
   * 构造语音消息
   *
   * @param audioPath 语音文件地址
   * @param name 文件显示名称
   * @param sceneName 场景名
   * @param duration 音频时长
   */
  static async createAudioMessage(audioPath: string, name?: string, sceneName?: string,
    duration?: number): Promise<V2NIMMessage> {
    return ChatKitClient.nim.messageCreator.createAudioMessage(audioPath, name, sceneName, duration);
  }

  /**
   * 构造视频消息
   *
   * @param videoPath 视频文件地址
   * @param name 文件显示名称
   * @param sceneName 场景名
   * @param duration 视频时长
   * @param width 视频宽度
   * @param height 视频高度
   */
  static async createVideoMessage(videoPath: string, name?: string, sceneName?: string, duration?: number,
    width?: number, height?: number): Promise<V2NIMMessage> {
    return ChatKitClient.nim.messageCreator.createVideoMessage(videoPath, name, sceneName, duration, width, height);
  }

  /**
   * 构造文件消息
   *
   * @param filePath 文件地址
   * @param name 文件显示名称
   * @param sceneName 场景名
   */
  static async createFileMessage(filePath: string, name?: string, sceneName?: string): Promise<V2NIMMessage> {
    return ChatKitClient.nim.messageCreator.createFileMessage(filePath, name, sceneName);
  }

  /**
   * 构造地理位置消息
   *
   * @param latitude 纬度
   * @param longitude 经度
   * @param address 详细位置信息
   */
  static createLocationMessage(latitude: number, longitude: number, address: string): V2NIMMessage {
    return ChatKitClient.nim.messageCreator.createLocationMessage(latitude, longitude, address);
  }

  /**
   * 构造自定义消息消息
   *
   * @param text 文本
   * @param rawAttachment 自定义的附件内容
   */
  static createCustomMessage(text: string, rawAttachment: string): V2NIMMessage {
    return ChatKitClient.nim.messageCreator.createCustomMessage(text, rawAttachment);
  }

  /**
   * 构造转发消息，消息内容与原消息一样
   *
   * https://overmind.hz.netease.com/206/requirement/issues/OMIM-50521
   *
   * 其它端怕抛 error 导致应用崩溃，所以这里不抛 error，而是返回 null
   *
   * @param message 需要转发的消息体
   */
  static createForwardMessage(message: V2NIMMessage): V2NIMMessage | null {
    return ChatKitClient.nim.messageCreator.createForwardMessage(message);
  }

  /**
   * 构造提示消息
   *
   * @param text 提示文本
   */
  static createTipsMessage(text: string): V2NIMMessage {
    return ChatKitClient.nim.messageCreator.createTipsMessage(text);
  }

  /**
   * 插入一条本地消息， 该消息不会发送。该消息不会多端同步，只是本端显示
   * @param message 需要插入的消息体
   * @param conversationId 会话 ID
   */
  static saveLocalMessage(msg: V2NIMMessage, conversationId: string, senderId: string, createTime: number) {
    ChatKitClient.nim.messageService?.insertMessageToLocal(msg, conversationId, senderId, createTime)
  }

  /**
   * 查询点对点消息已读回执
   * @param conversationId 会话 id
   */
  static async getP2PMessageReceipt(conversationId: string): Promise<V2NIMP2PMessageReadReceipt | undefined> {
    return await ChatKitClient.nim.messageService?.getP2PMessageReceipt(conversationId)
  }

  /**
   * 获取群消息已读回执状态详情
   *
   * @param msg 需要查询已读回执状态的消息
   * @param memberAccountIds 查找指定的账号列表已读未读
   *                              为空表示查询全部
   *                              同时作用于已读未读账号列表和人数
   */
  static getTeamMessageReceiptDetail(msg: V2NIMMessage,
    memberAccountIds?: string[]): Promise<V2NIMTeamMessageReadReceiptDetail> {
    return ChatKitClient.nim.messageService!!.getTeamMessageReceiptDetail(
      msg, memberAccountIds
    )
  }

  /**
   * 发送消息已读回执
   *
   * @param message 点对点会话收到的对方最后一条消息
   */
  static async sendP2PMessageReceipt(message: V2NIMMessage): Promise<void> {
    return ChatKitClient.nim.messageService?.sendP2PMessageReceipt(message)
  }

  /**
   * 获取群消息已读回执状态
   *
   * @param messages 获取群消息已读回执状态. 限制一批最多 50 个且所有消息必须属于同一个会话
   */
  static async getTeamMessageReceipts(messages: V2NIMMessage[]): Promise<V2NIMTeamMessageReadReceipt[] | undefined> {
    return ChatKitClient.nim.messageService?.getTeamMessageReceipts(messages)
  }

  /**
   * 发送群消息已读回执
   *
   * @param messages 需要发送已读回执的消息列表. 限制一批最多 50 个且所有消息必须属于同一个会话
   */
  static async sendTeamMessageReceipt(messages: V2NIMMessage[]): Promise<void> {
    return ChatKitClient.nim.messageService?.sendTeamMessageReceipts(messages)
  }
}