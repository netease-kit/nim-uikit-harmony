/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { V2NIMConversation } from '@nimsdk/base';

@ObservedV2
export default class ConversationListData implements IDataSource {
  @Trace
  private dataArray: V2NIMConversation[] = [];
  //被@的会话
  @Trace aitConversationList: Set<string> = new Set()
  private listeners: DataChangeListener[] = [];


  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      console.info('add listener');
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      console.info('remove listener');
      this.listeners.splice(pos, 1);
    }
  }


  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): V2NIMConversation {
    return this.dataArray[index];
  }

  public addData(index: number, data: V2NIMConversation): void {
    this.dataArray.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  public pushData(data: V2NIMConversation): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    })
  }
}