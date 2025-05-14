/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatRepo, getAitModelFromJson } from '@nimkit/chatkit';
import { ChatKitClient, currentConversationChanged } from '@nimkit/chatkit/src/main/ets/ChatKitClient';
import { V2NIMConversation, V2NIMConversationType, V2NIMMessage, V2NIMMessageRevokeNotification } from '@nimsdk/base';
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

  //有@的会话，缓存
  private aitConversationSet: Set<string> = new Set()
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
        this.aitConversationSet.delete(conversationId)
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

    //会话已读未读数的变化
    ChatKitClient.nim.conversationService?.on('onConversationChanged', (updateList: V2NIMConversation[]) => {
      updateList.forEach((conversation) => {
        if (conversation.unreadCount === 0 &&
        this.aitConversationSet.has(conversation.conversationId)) {
          this.clearAitMessage(conversation.conversationId)
          this.sendAitChange({
            sessionId: conversation.conversationId,
            isAit: false
          })
        }
      })
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
    //查找出此Conversation 中所有的ait Message
    let aitMessageList = await AitDatabase.instance.queryMessageIdsBySessionId(msg.messageRefer.conversationId, myAccId)
    let aitMessageId = aitMessageList.find((e) => e === msg.messageRefer.messageClientId)
    if (aitMessageId) {
      await AitDatabase.instance.deleteMessage(msg.messageRefer.conversationId, msg.messageRefer.messageClientId,
        myAccId)
      let haveAit = await this.isAitSession(msg.messageRefer.conversationId, myAccId)
      //if (haveAit === false) {
        // 回调
        this.sendAitChange({
          sessionId: msg.messageRefer.conversationId,
          messageId: msg.messageRefer.messageClientId,
          isAit: false
        })
        this.aitConversationSet.delete(msg.messageRefer.conversationId)
      //}
    }

  }

  public async saveAitMessage(sessionId: string, messageId: string): Promise<boolean> {
    if (sessionId === this._currentSessionId) {
      return false;
    }
    const myId = ChatKitClient.getLoginUserId()
    if (!myId) {
      return false;
    }
    this.aitConversationSet.add(sessionId)
    return ((await AitDatabase.instance.insertAitMessage(sessionId, messageId, myId)) ?? 0) > 0;
  }

  public async clearAitMessage(sessionId: string): Promise<number | undefined> {
    const myId = ChatKitClient.getLoginUserId()
    if (!myId) {
      return Promise.resolve(0);
    }
    this.aitConversationSet.delete(sessionId)
    return AitDatabase.instance.clearSessionAitMessage(sessionId, myId);
  }

  /**
   * 是否是Ait 会话
   * @param sessionId
   * @param myId
   * @returns
   */
  public async isAitSession(sessionId: string, myId: string): Promise<boolean> {
    if (this.aitConversationSet.has(sessionId)) {
      return true
    }
    const msgList = await AitDatabase.instance.queryMessageIdsBySessionId(sessionId, myId);
    return msgList.length > 0;
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