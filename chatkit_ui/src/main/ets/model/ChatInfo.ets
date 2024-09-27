/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ImagesIndexModel } from '@nimkit/common';
import { V2NIMMessageImageAttachment, V2NIMMessageType, V2NIMMessageVideoAttachment } from '@nimsdk/base';
import { ChatKitClient } from '@nimkit/chatkit';
import { V2NIMMessage, V2NIMMessageSendingState } from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService';
import { NIMMessageInfo } from '../model/NIMMessageInfo';

@ObservedV2
export class ChatInfo {
  @Trace conversationName: string | undefined = undefined;
  @Trace msgList: MessageDataSource = new MessageDataSource();
  @Trace downloadProgressMap: Map<string, number> = new Map();
  @Trace isReceiveMsg: boolean = false;
  conversationId: string = '';
  targetId: string = '';

  constructor(conversationId: string) {
    this.conversationId = conversationId;
    this.targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
  }

  setConversationId(conversationId: string) {
    this.conversationId = conversationId;
    this.targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
  }

  setReceiveMsg(receiveMsg: boolean) {
    this.isReceiveMsg = receiveMsg;
  }

  getConversationName(): string {
    return '';
  };

  getChatUserAvatarUrl(accountId: string): string {
    return '';
  };

  getChatUserAvatarName(accountId: string): string {
    return accountId;
  };

  getChatUserShowName(accountId: string): string {
    return accountId;
  };

  getCurrentUserShowName(): string {
    return this.targetId;
  };

  getCurrentUserAvatarUrl(): string {
    return '';
  };

  getCurrentUserAvatarName(): string {
    return this.targetId;
  };


  updateMessageStatus(message: V2NIMMessage) {
    if (message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
      return;
    }
    let targetMessage =
      this.msgList.getMessageList().find(msg => msg.message.messageClientId === message.messageClientId);
    if (targetMessage !== undefined) {
      targetMessage.updateMessageStatus(message)
    } else {
      this.addMessage(message)
      this.setReceiveMsg(true)
    }
  }

  addMessage(message: V2NIMMessage): NIMMessageInfo {
    let current = this.getMessage(message.messageClientId)
    if (current !== undefined) {
      return current;
    }
    let lastMessageTime = 0
    if (this.msgList.totalCount() > 0) {
      lastMessageTime = this.msgList.getMessageList()[this.msgList.totalCount() - 1]?.message.createTime;
    }
    let msgInfo = new NIMMessageInfo(message);
    msgInfo.setLastMessageTime(lastMessageTime)
    this.msgList.push(msgInfo);
    return msgInfo;
  }

  pushMessage(message: NIMMessageInfo) {
    let current = this.getMessage(message.message.messageClientId)
    if (current !== undefined) {
      return;
    }
    let lastMessageTime = this.msgList.getMessageList()[this.msgList.totalCount() - 1]?.message.createTime;
    // let msgInfo = new NIMMessageInfo(message);
    message.setLastMessageTime(lastMessageTime)
    this.msgList.push(message);
  }

  deleteMessage(msgClientId: string) {
    this.msgList.delete(msgClientId)
  }

  revokeMessage(msgClientId: string) {
    this.deleteMessage(msgClientId)
  }

  insertMessage(message: V2NIMMessage) {
    let isRecent = false;
    for (let index = this.msgList.totalCount() - 1; index >= 0; index--) {
      if (this.msgList.getData(index).getCreateTime() > message.createTime) {
        isRecent = true;
      }
    }
  }

  getMessage(msgClientId: string): NIMMessageInfo | undefined {
    return this.msgList.getMessageList().find(msg => msg.message.messageClientId === msgClientId)
  }
}


// Basic implementation of IDataSource to handle data listener
export class MessageDataSource implements IDataSource {
  messageData: NIMMessageInfo[] = [];
  private listeners: DataChangeListener[] = [];

  public totalCount(): number {
    return this.messageData.length;
  }

  public getData(index: number): NIMMessageInfo {
    return this.messageData[index];
  }

  public addData(index: number, data: NIMMessageInfo): void {
    this.messageData.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  public push(data: NIMMessageInfo): void {
    this.messageData.push(data);
    this.notifyDataAdd(this.messageData.length - 1);
  }

  public unshift(data: NIMMessageInfo): void {
    this.messageData.unshift(data);
    this.notifyDataAdd(0);
  }

  public unshiftList(data: NIMMessageInfo[]): void {
    data.forEach(element => {
      this.messageData.unshift(element);
    })

    this.notifyDatasetChange([{
      type: DataOperationType.ADD,
      index: 0,
      count: data.length
    }]);
  }

  public pushList(data: NIMMessageInfo[]): void {
    data.forEach(element => {
      this.messageData.push(element);
    });
    this.notifyDataAdd(this.messageData.length - 1);
  }

  public delete(msgClientId: string) {
    this.messageData.forEach((msg, index, msgList) => {
      if (msgClientId === msg.message.messageClientId) {
        this.messageData.splice(index, 1)
        this.notifyDataDelete(index)
        return
      }
    })
  }

  public getMessageList(): NIMMessageInfo[] {
    return this.messageData;
  }

  // 该方法为框架侧调用，为LazyForEach组件向其数据源处添加listener监听
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  // 该方法为框架侧调用，为对应的LazyForEach组件在数据源处去除listener监听
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  // 通知LazyForEach组件需要重载所有子组件
  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
  }

  // 通知LazyForEach组件需要在index对应索引处添加子组件
  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    })
  }

  // 通知LazyForEach组件在index对应索引处数据有变化，需要重建该子组件
  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    })
  }

  // 通知LazyForEach组件需要在index对应索引处删除该子组件
  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  // 通知LazyForEach组件将from索引和to索引处的子组件进行交换
  notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
    })
  }

  // 通知LazyForEach组件将from索引和to索引处的子组件进行交换
  notifyDatasetChange(operation: DataAddOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operation);
    })
  }
}