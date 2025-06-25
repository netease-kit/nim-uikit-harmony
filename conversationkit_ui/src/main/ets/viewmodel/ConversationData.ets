/**
 * LocalConversationData
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−06-03
 *
 * Copyright © 2025 Netease. All rights reserved.
 */
import { V2NIMConversation } from '@nimsdk/base';

@ObservedV2
export default class ConversationData implements IDataSource {
  @Trace conversationList: V2NIMConversation[] = [];
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
    return this.conversationList.length;
  }

  public getData(index: number): V2NIMConversation {
    return this.conversationList[index];
  }

  public replaceData(index: number, data: V2NIMConversation): void {
    this.conversationList.splice(index, 1, data);
    this.notifyDataChange(index);
  }

  public addData(index: number, data: V2NIMConversation): void {
    this.conversationList.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  public pushData(data: V2NIMConversation): void {
    this.conversationList.push(data);
    this.notifyDataAdd(this.conversationList.length - 1);
  }

  public removeData(index: number): void {
    this.conversationList.splice(index, 1)
    this.notifyDataDelete(index)
  }

  public reloadData(): void {
    this.notifyDataReload()
  }


  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    })
  }

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  // 通知LazyForEach组件在index对应索引处数据有变化，需要重建该子组件
  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
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

  // 通知LazyForEach组件重新加载
  notifyDatasetReload(operation: DataReloadOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operation);
    })
  }

  // 通知LazyForEach组件需要重载所有子组件
  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
  }
}