import { Logger } from '@nimkit/common';
import { ConversationItem } from '../strategy/ConversationStrategy'

@ObservedV2
export default class ConversationData<T extends ConversationItem = ConversationItem> implements IDataSource {
  @Trace conversationList: T[] = []
  private listeners: DataChangeListener[] = []

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      Logger.info('ConversationKit', 'add listener')
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener)
    if (pos >= 0) {
      Logger.info('ConversationKit', 'remove listener')
      this.listeners.splice(pos, 1)
    }
  }

  public totalCount(): number {
    return this.conversationList.length
  }

  public getData(index: number): T {
    return this.conversationList[index]
  }

  public replaceData(index: number, data: T): void {
    this.conversationList.splice(index, 1, data)
    this.notifyDataChange(index)
  }

  public addData(index: number, data: T): void {
    this.conversationList.splice(index, 0, data)
    this.notifyDataAdd(index)
  }

  public pushData(data: T): void {
    this.conversationList.push(data)
    this.notifyDataAdd(this.conversationList.length - 1)
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
      listener.onDataAdd(index)
    })
  }

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index)
    })
  }

  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index)
    })
  }

  notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to)
    })
  }

  notifyDatasetChange(operation: DataAddOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operation)
    })
  }

  notifyDatasetReload(operation: DataReloadOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operation)
    })
  }

  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded()
    })
  }
}
