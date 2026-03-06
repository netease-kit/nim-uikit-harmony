/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatRepo, getAitModelFromJson } from '@nimkit/chatkit';
import { ChatKitClient, currentConversationChanged } from '@nimkit/chatkit/src/main/ets/ChatKitClient';
import { V2NIMConversation, V2NIMConversationType, V2NIMLocalConversation, V2NIMMessage, V2NIMMessageRevokeNotification } from '@nimsdk/base';
import { AitDatabase } from './AitDatabaseHelper';

export const AitSessionChangeEvent: string = 'AitSessionChangeEvent'

/**
 * 管理session列表的@消息处理
 */
export class AitServer {
  private static _instance: AitServer | undefined = undefined;

  public static get instance(): AitServer {
    return this._instance ?? (this._instance = new AitServer());
  }

  private constructor() {

  }

  //有@的会话及对应的@消息列表，缓存
  private aitConversationMap: Map<string, Set<string>> = new Map()
  /// 当前会话id, 用于判断是否需要保存@消息
  private _currentSessionId: string | null = null;

  public init() {
    this.initListener()
  }

  private initListener(): void {

    //当前会话设置变更的回到
    getContext().eventHub.on(currentConversationChanged, (conversationId: string) => {
      this._currentSessionId = conversationId
      if (conversationId.length > 0) {
        this.clearAitMessage(conversationId)
        this.aitConversationMap.delete(conversationId)
        this.sendAitChange({
          sessionId: conversationId,
          messageId: undefined,
          isAit: false
        })
      }
    })

    // 注册消息接受监听
    ChatRepo.onReceiverMessage(this.onReceiveFun.bind(this))

    // 注册消息撤回监听
    ChatRepo.onRevokeMessage(this.onRevokeFun.bind(this))

    //云端会话已读未读数的变化（其他端 clearUnread 时触发）
    ChatKitClient.nim.conversationService?.on('onConversationChanged', (updateList: V2NIMConversation[]) => {
      this.handleConversationUnreadChanged(updateList)
    })
  }

  /**
   * 处理会话未读数变化，当未读数为0时清除@消息
   * 支持云端会话和本地会话
   * @param updateList 变化的会话列表
   */
  private handleConversationUnreadChanged(updateList: (V2NIMConversation | V2NIMLocalConversation)[]): void {
    updateList.forEach((conversation) => {
      if (conversation.unreadCount === 0 &&
      this.aitConversationMap.has(conversation.conversationId)) {
        this.clearAitMessage(conversation.conversationId)
        this.sendAitChange({
          sessionId: conversation.conversationId,
          isAit: false
        })
      }
    })
  }

  //接收到消息
  onReceiveFun = (messages: V2NIMMessage[]) => {
    let myAccId = ChatKitClient.getLoginUserId()
    messages.forEach(msg => {
      if (!msg.isSelf
        && msg.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM
        && msg.conversationId != this._currentSessionId) {
        if (msg.serverExtension) {
          ChatKitClient.logger?.debug(`AitService`, `onReceiveFun  text = ${msg.text} id = ${msg.messageClientId}`)
          let aitModel = getAitModelFromJson(msg.serverExtension)
          if (aitModel && aitModel.isUserBeenAit(myAccId)) {
            ChatKitClient.logger?.debug(`AitService`, `onReceiveFun been ait ConversationID = ${msg.conversationId}`)
            // 回调
            this.sendAitChange({
              sessionId: msg.conversationId,
              messageId: msg.messageClientId,
              isAit: true
            })
            this.saveAitMessage(msg.conversationId, msg.messageClientId)
          }
        }
      }
    })
  }
  // 撤回消息
  onRevokeFun = (messages: V2NIMMessageRevokeNotification[]) => {
    let myAccId = ChatKitClient.getLoginUserId()
    messages.forEach(msg => {
      if (msg.messageRefer.senderId != myAccId
        && msg.messageRefer.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM
        && msg.messageRefer.conversationId != this._currentSessionId) {
        this.handleRevokeAitMessage(msg, myAccId)

      }
    })
  }

  /**
   * 发送变更通知
   * @param aitSession
   */
  sendAitChange(aitSession: AitSession) {
    getContext().eventHub.emit(AitSessionChangeEvent, aitSession)
  }

  /**
   * 处理@消息的撤回
   * @param msg
   * @param myAccId
   */
  async handleRevokeAitMessage(msg: V2NIMMessageRevokeNotification, myAccId: string) {
    const conversationId = msg.messageRefer.conversationId
    const messageId = msg.messageRefer.messageClientId

    // 从缓存中移除该消息
    this.removeAitMessageFromCache(conversationId, messageId)

    // 从数据库中删除该消息
    await AitDatabase.instance.deleteMessage(conversationId, messageId, myAccId)

    // 检查该会话是否还有其他@消息
    const aitMessageSet = this.aitConversationMap.get(conversationId)
    const hasOtherAitMessages = aitMessageSet && aitMessageSet.size > 0

    if (!hasOtherAitMessages) {
      // 只有当该会话中没有其他@消息时，才隐藏"有人@我"标识
      this.aitConversationMap.delete(conversationId)
      this.sendAitChange({
        sessionId: conversationId,
        messageId: messageId,
        isAit: false
      })
    }
  }

  /**
   * 从缓存中移除指定的@消息
   * @param sessionId
   * @param messageId
   */
  private removeAitMessageFromCache(sessionId: string, messageId: string): void {
    const aitMessageSet = this.aitConversationMap.get(sessionId)
    if (aitMessageSet) {
      aitMessageSet.delete(messageId)
      if (aitMessageSet.size === 0) {
        this.aitConversationMap.delete(sessionId)
      }
    }
  }

  /**
   * 添加@消息到缓存
   * @param sessionId
   * @param messageId
   */
  private addAitMessageToCache(sessionId: string, messageId: string): void {
    if (!this.aitConversationMap.has(sessionId)) {
      this.aitConversationMap.set(sessionId, new Set())
    }
    this.aitConversationMap.get(sessionId)!.add(messageId)
  }

  public async saveAitMessage(sessionId: string, messageId: string): Promise<boolean> {
    if (sessionId === this._currentSessionId) {
      return false;
    }
    const myId = ChatKitClient.getLoginUserId()
    if (!myId) {
      return false;
    }

    // 添加到缓存中
    this.addAitMessageToCache(sessionId, messageId)

    // 保存到数据库
    return ((await AitDatabase.instance.insertAitMessage(sessionId, messageId, myId)) ?? 0) > 0;
  }

  public async clearAitMessage(sessionId: string): Promise<number | undefined> {
    const myId = ChatKitClient.getLoginUserId()
    if (!myId) {
      return Promise.resolve(0);
    }

    // 从缓存中清除
    this.aitConversationMap.delete(sessionId)

    // 从数据库中清除
    return AitDatabase.instance.clearSessionAitMessage(sessionId, myId);
  }

  /**
   * 是否是Ait 会话
   * @param sessionId
   * @param myId
   * @returns
   */
  public async isAitSession(sessionId: string, myId: string): Promise<boolean> {
    // 优先检查缓存
    const aitMessageSet = this.aitConversationMap.get(sessionId)
    if (aitMessageSet && aitMessageSet.size > 0) {
      return true
    }

    // 如果缓存中没有，检查数据库
    const msgList = await AitDatabase.instance.queryMessageIdsBySessionId(sessionId, myId);
    if (msgList.length > 0) {
      // 将数据库中的数据同步到缓存
      const messageSet = new Set(msgList)
      this.aitConversationMap.set(sessionId, messageSet)
      return true
    }

    return false
  }

  public async getAllAitSession(myId: string): Promise<string[]> {
    return AitDatabase.instance.queryAllAitSession(myId);
  }
}

export interface AitSession {
  sessionId: string;
  messageId?: string;
  isAit: boolean;
}