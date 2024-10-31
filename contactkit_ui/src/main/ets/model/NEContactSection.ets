/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEUserWithFriend } from '@nimkit/chatkit';

@ObservedV2
export class SelectUserWithFriend extends NEUserWithFriend {
  @Trace selected?: boolean;

  constructor(userWithFriend?: NEUserWithFriend) {
    super({
      user: userWithFriend?.user,
      friend: userWithFriend?.friend
    });
    this.selected = false
  }
}

@ObservedV2
export class SelectUserWithFriendDataSource implements IDataSource {
  /**
   * 同一标题下的好友子列表
   */
  @Trace contacts: SelectUserWithFriend[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.contacts.length
  }

  getData(index: number): SelectUserWithFriend {
    return this.contacts[index]
  }

  public addData(index: number, data: SelectUserWithFriend): void {
    this.contacts.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  public push(data: SelectUserWithFriend): void {
    this.contacts.push(data);
    this.notifyDataAdd(this.contacts.length - 1);
  }

  public unshift(data: SelectUserWithFriend): void {
    this.contacts.unshift(data);
    this.notifyDataAdd(0);
  }

  public unshiftList(data: SelectUserWithFriend[]): void {
    data.forEach(element => {
      this.contacts.unshift(element);
    })

    this.notifyDatasetChange([{
      type: DataOperationType.ADD,
      index: 0,
      count: data.length
    }]);
  }

  public pushList(data: SelectUserWithFriend[]): void {
    data.forEach(element => {
      this.contacts.push(element);
    });
    this.notifyDataAdd(this.contacts.length - 1);
  }

  public delete(accountId: string) {
    this.contacts.forEach((value, index) => {
      if (accountId === value.user?.accountId) {
        this.contacts.splice(index, 1)
        this.notifyDataDelete(index)
        return
      }
    })
  }

  // 该方法为框架侧调用，为LazyForEach组件向其数据源处添加listener监听
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      console.info('add listener');
      this.listeners.push(listener);
    }
  }

  // 该方法为框架侧调用，为对应的LazyForEach组件在数据源处去除listener监听
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      console.info('remove listener');
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

  // 通知LazyForEach组件数据有变化
  notifyDatasetChange(operation: DataAddOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operation);
    })
  }
}

@ObservedV2
export class NEContactSection {
  /**
   * 标题
   */
  @Trace initial: string = "#";
  /**
   * 同一标题下的好友子列表
   */
  @Trace contacts: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();

  constructor(initial: string, contacts: SelectUserWithFriend[]) {
    this.initial = initial
    this.contacts.contacts = contacts
  }
}

export class NEContactSectionDataSource implements IDataSource {
  listeners: DataChangeListener[] = [];
  contactSections: NEContactSection[] = [];

  public totalCount(): number {
    return this.contactSections.length;
  }

  public getData(index: number): NEContactSection {
    return this.contactSections[index];
  }

  public addData(index: number, data: NEContactSection): void {
    this.contactSections.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  public push(data: NEContactSection): void {
    this.contactSections.push(data);
    this.notifyDataAdd(this.contactSections.length - 1);
  }

  public unshift(data: NEContactSection): void {
    this.contactSections.unshift(data);
    this.notifyDataAdd(0);
  }

  public unshiftList(data: NEContactSection[]): void {
    data.forEach(element => {
      this.contactSections.unshift(element);
    })

    this.notifyDatasetChange([{
      type: DataOperationType.ADD,
      index: 0,
      count: data.length
    }]);
  }

  public pushList(data: NEContactSection[]): void {
    data.forEach(element => {
      this.contactSections.push(element);
    });
    this.notifyDataAdd(this.contactSections.length - 1);
  }

  public delete(initial: string) {
    this.contactSections.forEach((value, index) => {
      if (initial === value.initial) {
        this.contactSections.splice(index, 1)
        this.notifyDataDelete(index)
        return
      }
    })
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

  // 通知LazyForEach组件数据有变化
  notifyDatasetChange(operation: DataAddOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operation);
    })
  }
}