/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium'
import { V2NIMConversation, V2NIMConversationType } from '@nimsdk/base'
import ConversationData from '../../../main/ets/viewmodel/ConversationData'

class TestConversation implements V2NIMConversation {
  readonly conversationId: string
  readonly type: V2NIMConversationType
  readonly stickTop: boolean
  readonly serverExtension: string
  readonly unreadCount: number
  readonly sortOrder: number
  readonly createTime: number
  readonly updateTime: number
  readonly lastReadTime: number

  constructor(id: string) {
    this.conversationId = id
    this.type = V2NIMConversationType.V2NIM_CONVERSATION_TYPE_UNKNOWN
    this.stickTop = false
    this.serverExtension = ''
    this.unreadCount = 0
    this.sortOrder = 0
    this.createTime = 0
    this.updateTime = 0
    this.lastReadTime = 0
  }
}

class MockListener implements DataChangeListener {
  addCount: number = 0
  deleteCount: number = 0
  changeCount: number = 0
  reloadCount: number = 0
  moveCount: number = 0
  datasetChangeCount: number = 0
  lastAddIndex: number = -1
  lastDeleteIndex: number = -1
  lastChangeIndex: number = -1
  lastMoveFrom: number = -1
  lastMoveTo: number = -1

  onDataAdd(index: number): void {
    this.addCount++
    this.lastAddIndex = index
  }

  onDataAdded(index: number): void {
    this.onDataAdd(index)
  }

  onDataDelete(index: number): void {
    this.deleteCount++
    this.lastDeleteIndex = index
  }

  onDataDeleted(index: number): void {
    this.onDataDelete(index)
  }

  onDataChange(index: number): void {
    this.changeCount++
    this.lastChangeIndex = index
  }

  onDataChanged(index: number): void {
    this.onDataChange(index)
  }

  onDataMove(from: number, to: number): void {
    this.moveCount++
    this.lastMoveFrom = from
    this.lastMoveTo = to
  }

  onDataMoved(from: number, to: number): void {
    this.onDataMove(from, to)
  }

  onDatasetChange(operation: DataAddOperation[]): void {
    this.datasetChangeCount++
  }

  onDataReloaded(): void {
    this.reloadCount++
  }
}

export default function conversationDataTest() {
  describe('ConversationDataTest', () => {
    // ---- 基础方法 ----

    it('should_return_zero_total_count_for_empty_list', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      expect(data.totalCount()).assertEqual(0)
    })

    it('should_return_correct_total_count_after_push', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let item: TestConversation = new TestConversation('conv1')
      data.pushData(item)
      expect(data.totalCount()).assertEqual(1)
    })

    it('should_get_data_at_valid_index', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let item: TestConversation = new TestConversation('conv1')
      data.conversationList.push(item)
      let result: TestConversation = data.getData(0)
      expect(result.conversationId).assertEqual('conv1')
    })

    it('should_push_data_to_end_and_notify', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      let item: TestConversation = new TestConversation('conv1')
      data.pushData(item)
      expect(data.totalCount()).assertEqual(1)
      expect(listener.addCount).assertEqual(1)
      expect(listener.lastAddIndex).assertEqual(0)
    })

    it('should_add_data_at_specific_index_and_notify', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let item1: TestConversation = new TestConversation('conv1')
      let item2: TestConversation = new TestConversation('conv2')
      data.conversationList.push(item1)
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.addData(0, item2)
      expect(data.totalCount()).assertEqual(2)
      expect(data.getData(0).conversationId).assertEqual('conv2')
      expect(data.getData(1).conversationId).assertEqual('conv1')
      expect(listener.addCount).assertEqual(1)
      expect(listener.lastAddIndex).assertEqual(0)
    })

    it('should_replace_data_at_index_and_notify', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let item1: TestConversation = new TestConversation('conv1')
      let item2: TestConversation = new TestConversation('conv2')
      data.conversationList.push(item1)
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.replaceData(0, item2)
      expect(data.totalCount()).assertEqual(1)
      expect(data.getData(0).conversationId).assertEqual('conv2')
      expect(listener.changeCount).assertEqual(1)
      expect(listener.lastChangeIndex).assertEqual(0)
    })

    it('should_remove_data_at_index_and_notify', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let item1: TestConversation = new TestConversation('conv1')
      let item2: TestConversation = new TestConversation('conv2')
      data.conversationList.push(item1)
      data.conversationList.push(item2)
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.removeData(0)
      expect(data.totalCount()).assertEqual(1)
      expect(data.getData(0).conversationId).assertEqual('conv2')
      expect(listener.deleteCount).assertEqual(1)
      expect(listener.lastDeleteIndex).assertEqual(0)
    })

    it('should_reload_data_and_notify_listeners', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.reloadData()
      expect(listener.reloadCount).assertEqual(1)
    })

    // ---- 监听器管理 ----

    it('should_register_data_change_listener', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener1: MockListener = new MockListener()
      let listener2: MockListener = new MockListener()
      data.registerDataChangeListener(listener1)
      data.registerDataChangeListener(listener2)
      data.reloadData()
      expect(listener1.reloadCount).assertEqual(1)
      expect(listener2.reloadCount).assertEqual(1)
    })

    it('should_not_register_duplicate_listener', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.registerDataChangeListener(listener)
      data.reloadData()
      expect(listener.reloadCount).assertEqual(1)
    })

    it('should_unregister_existing_listener', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener1: MockListener = new MockListener()
      let listener2: MockListener = new MockListener()
      data.registerDataChangeListener(listener1)
      data.registerDataChangeListener(listener2)
      data.unregisterDataChangeListener(listener1)
      data.reloadData()
      expect(listener1.reloadCount).assertEqual(0)
      expect(listener2.reloadCount).assertEqual(1)
    })

    it('should_handle_unregister_non_existent_listener', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.unregisterDataChangeListener(listener)
      data.reloadData()
      expect(listener.reloadCount).assertEqual(0)
    })

    // ---- 直接调用通知方法 ----

    it('should_directly_notify_data_add', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.notifyDataAdd(5)
      expect(listener.addCount).assertEqual(1)
      expect(listener.lastAddIndex).assertEqual(5)
    })

    it('should_directly_notify_data_delete', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.notifyDataDelete(3)
      expect(listener.deleteCount).assertEqual(1)
      expect(listener.lastDeleteIndex).assertEqual(3)
    })

    it('should_directly_notify_data_change', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.notifyDataChange(7)
      expect(listener.changeCount).assertEqual(1)
      expect(listener.lastChangeIndex).assertEqual(7)
    })

    it('should_directly_notify_data_move', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.notifyDataMove(2, 5)
      expect(listener.moveCount).assertEqual(1)
      expect(listener.lastMoveFrom).assertEqual(2)
      expect(listener.lastMoveTo).assertEqual(5)
    })

    it('should_directly_notify_data_reload', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.notifyDataReload()
      expect(listener.reloadCount).assertEqual(1)
    })

    it('should_directly_notify_dataset_change', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.notifyDatasetChange([])
      expect(listener.datasetChangeCount).assertEqual(1)
    })

    it('should_directly_notify_dataset_reload', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.notifyDatasetReload([])
      expect(listener.datasetChangeCount).assertEqual(1)
    })

    // ---- 边界 ----

    it('should_handle_push_multiple_items', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      let item1: TestConversation = new TestConversation('conv1')
      let item2: TestConversation = new TestConversation('conv2')
      let item3: TestConversation = new TestConversation('conv3')
      data.pushData(item1)
      data.pushData(item2)
      data.pushData(item3)
      expect(data.totalCount()).assertEqual(3)
      expect(data.getData(0).conversationId).assertEqual('conv1')
      expect(data.getData(2).conversationId).assertEqual('conv3')
      expect(listener.addCount).assertEqual(3)
      expect(listener.lastAddIndex).assertEqual(2)
    })

    it('should_handle_add_data_at_end', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let item1: TestConversation = new TestConversation('conv1')
      data.conversationList.push(item1)
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      let item2: TestConversation = new TestConversation('conv2')
      data.addData(1, item2)
      expect(data.totalCount()).assertEqual(2)
      expect(data.getData(1).conversationId).assertEqual('conv2')
      expect(listener.addCount).assertEqual(1)
      expect(listener.lastAddIndex).assertEqual(1)
    })

    it('should_not_notify_after_listener_unregistered', 0, () => {
      let data: ConversationData<TestConversation> = new ConversationData<TestConversation>()
      let listener: MockListener = new MockListener()
      data.registerDataChangeListener(listener)
      data.unregisterDataChangeListener(listener)
      data.notifyDataAdd(0)
      data.notifyDataDelete(0)
      data.notifyDataChange(0)
      data.notifyDataMove(0, 1)
      data.notifyDataReload()
      data.notifyDatasetChange([])
      expect(listener.addCount).assertEqual(0)
      expect(listener.deleteCount).assertEqual(0)
      expect(listener.changeCount).assertEqual(0)
      expect(listener.moveCount).assertEqual(0)
      expect(listener.reloadCount).assertEqual(0)
      expect(listener.datasetChangeCount).assertEqual(0)
    })
  })
}
