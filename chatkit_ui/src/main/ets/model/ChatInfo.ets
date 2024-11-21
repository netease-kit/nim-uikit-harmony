/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient } from '@nimkit/chatkit';
import { V2NIMMessagePin } from '@nimsdk/base';
import { V2NIMMessage, V2NIMMessageSendingState } from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService';
import { NIMMessageInfo } from '../model/NIMMessageInfo';

@ObservedV2
export class ChatInfo {
  @Trace conversationName: string | undefined = undefined;
  @Trace msgList: MessageDataSource = new MessageDataSource();
  @Trace downloadProgressMap: Map<string, number> = new Map();
  @Trace isReceiveMsg: boolean = false;
  @Trace scrollIndex: number = -1; // 是否需要滚动到指定位置
  msgMap: Map<string, NIMMessageInfo> = new Map();
  @Trace msgPinMap: Map<string, V2NIMMessagePin> = new Map();
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

  setScrollIndex(index: number) {
    this.scrollIndex = index
  }

  getConversationName(): string {
    return '';
  };

  getChatUserAvatarUrl(param?: string | V2NIMMessage): string {
    return '';
  };

  getChatUserAvatarName(param?: string | V2NIMMessage): string {
    if (param as V2NIMMessage) {
      return (param as V2NIMMessage).senderId
    }
    return param as string;
  };

  getChatUserShowName(param?: string | V2NIMMessage, alias: boolean = true, teamNick: boolean = true): string {
    if (param as V2NIMMessage) {
      return (param as V2NIMMessage).senderId
    }
    return param as string;
  };

  getCurrentUserShowName(): string {
    return this.targetId;
  };

  getCurrentUserAvatarUrl(message?: V2NIMMessage): string {
    return '';
  };

  getCurrentUserAvatarName(): string {
    return this.targetId;
  };

  updateMessageStatus(message: V2NIMMessage): boolean {
    if (message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
      return false
    }
    let targetMessage =
      this.msgList.getMessageList().find(msg => msg.message.messageClientId === message.messageClientId);
    if (targetMessage !== undefined) {
      targetMessage.updateMessageStatus(message)
      return true
    } else {
      this.insertMessage(message)
      return false
    }
  }

  addPinMessage(pinMsg: V2NIMMessagePin[]) {
    pinMsg.forEach(pin => {
      this.msgPinMap.set(pin.messageRefer.messageClientId, pin)
      this.msgMap.get(pin.messageRefer.messageClientId)?.setPinMessage(pin)
    })
  }

  resetPinMessage(pinMsg: V2NIMMessagePin[]) {
    this.msgPinMap.clear()
    this.msgList.messageData.forEach(msg => {
      msg.setPinMessage(undefined)
    })
    pinMsg.forEach(pin => {
      this.msgPinMap.set(pin.messageRefer.messageClientId, pin)
      this.msgMap.get(pin.messageRefer.messageClientId)?.setPinMessage(pin)
    })
  }

  removePinMessage(pinMsg: V2NIMMessagePin[]) {
    pinMsg.forEach(pin => {
      this.msgPinMap.delete(pin.messageRefer.messageClientId)
      this.msgMap.get(pin.messageRefer.messageClientId)?.setPinMessage(undefined)
    })
  }

  updateMessageReadReceipt(message: NIMMessageInfo) {

  }

  insertMessage(message: V2NIMMessage): NIMMessageInfo {
    let addIndex = this.msgList.searchInsertPosition(message.createTime)
    if (addIndex > this.msgList.totalCount()) {
      let result = this.pushMessage(message)
      this.setReceiveMsg(true)
      return result
    } else {
      let lastMessageTime = 0
      if (addIndex > 0) {
        lastMessageTime = this.msgList.getMessageList()[addIndex - 1]?.message.createTime;
      }
      let msgInfo = new NIMMessageInfo(message)
      msgInfo.setLastMessageTime(lastMessageTime)
      this.updateMessageReadReceipt(msgInfo)
      this.msgMap.set(message.messageClientId, msgInfo)
      if (this.msgPinMap.has(message.messageClientId)) {
        msgInfo.setPinMessage(this.msgPinMap.get(message.messageClientId))
      }
      this.msgList.addData(addIndex, msgInfo)
      return msgInfo;
    }
  }

  pushMessage(message: V2NIMMessage): NIMMessageInfo {
    let current = this.getMessage(message.messageClientId)
    if (current !== undefined) {
      return current;
    }
    let lastMessageTime = 0
    if (this.msgList.totalCount() > 0) {
      lastMessageTime = this.msgList.getMessageList()[this.msgList.totalCount() - 1]?.message.createTime;
    }
    let msgInfo = new NIMMessageInfo(message)
    msgInfo.setLastMessageTime(lastMessageTime)
    this.updateMessageReadReceipt(msgInfo)
    this.msgList.push(msgInfo);
    this.msgMap.set(message.messageClientId, msgInfo)
    if (this.msgPinMap.has(message.messageClientId)) {
      msgInfo.setPinMessage(this.msgPinMap.get(message.messageClientId))
    }
    return msgInfo;
  }

  pushMessageInfo(msgInfo: NIMMessageInfo) {
    let current = this.getMessage(msgInfo.message.messageClientId)
    if (current !== undefined) {
      return;
    }
    let lastMessageTime = this.msgList.getMessageList()[this.msgList.totalCount() - 1]?.message.createTime;
    msgInfo.setLastMessageTime(lastMessageTime)
    this.updateMessageReadReceipt(msgInfo)
    this.msgMap.set(msgInfo.message.messageClientId, msgInfo)
    if (this.msgPinMap.has(msgInfo.message.messageClientId)) {
      msgInfo.setPinMessage(this.msgPinMap.get(msgInfo.message.messageClientId))
    }
    this.msgList.push(msgInfo);
  }

  unshiftMessage(messageList: V2NIMMessage[]): NIMMessageInfo[] {
    let result: NIMMessageInfo[] = [];
    for (let index = 0; index < messageList.length; index++) {
      let msg = new NIMMessageInfo(messageList[index]);
      if (index < messageList.length - 1) {
        msg.setLastMessageTime(messageList[index+1].createTime);
      }
      this.msgMap.set(msg.message.messageClientId, msg)
      if (this.msgPinMap.has(msg.message.messageClientId)) {
        msg.setPinMessage(this.msgPinMap.get(msg.message.messageClientId))
      }
      this.msgList.unshift(msg)
      result.push(msg);
    }

    return result;
  }

  deleteMessage(msgClientId: string) {
    this.msgList.delete(msgClientId)
    this.msgMap.delete(msgClientId)
  }

  revokeMessage(msgClientId: string) {
    this.deleteMessage(msgClientId)
  }

  getMessage(msgClientId: string): NIMMessageInfo | undefined {
    return this.msgMap.get(msgClientId)
  }

  searchPosition(msgClientId: string): number {
    return this.msgList.searchPosition(msgClientId)
  }

  public cleanMessage() {
    this.msgList.clean()
    this.msgMap.clear()
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

  public searchInsertPosition(creatTime: number): number {
    for (let index = this.messageData.length - 1; index >= 0; index--) {
      if (creatTime > this.messageData[index].getCreateTime()) {
        return index + 1;
      }
    }
    return 0;
  }

  public searchPosition(clientId: string): number {
    for (let index = this.messageData.length - 1; index >= 0; index--) {
      if (clientId == this.messageData[index].getMessageClientId()) {
        return index;
      }
    }
    return -1;
  }

  public clean() {
    while (this.messageData.length > 0) {
      this.messageData.pop()
    }
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