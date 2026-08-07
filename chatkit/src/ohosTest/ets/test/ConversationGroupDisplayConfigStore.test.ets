/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  CONVERSATION_GROUP_DEFAULT_AIT_KEY,
  CONVERSATION_GROUP_DEFAULT_ALL_KEY,
  CONVERSATION_GROUP_DEFAULT_UNREAD_KEY,
  ConversationGroupCreateSource,
  ConversationGroupDisplayConfigStorage,
  ConversationGroupDisplayConfigStore
} from '../../../main/ets/cache/ConversationGroupDisplayConfigStore'

class MemoryDisplayConfigStorage implements ConversationGroupDisplayConfigStorage {
  values: Map<string, string> = new Map()
  flushCount: number = 0

  getString(key: string): string | undefined {
    return this.values.get(key)
  }

  putString(key: string, value: string): void {
    this.values.set(key, value)
  }

  flush(): void {
    this.flushCount++
  }
}

function createStore(storage: MemoryDisplayConfigStorage): ConversationGroupDisplayConfigStore {
  return new ConversationGroupDisplayConfigStore(storage, () => 1000)
}

export default function conversationGroupDisplayConfigStoreTest() {
  describe('ConversationGroupDisplayConfigStore', () => {
    it('should_initialize_default_groups_visible_and_cloud_groups_hidden', 0, () => {
      const storage = new MemoryDisplayConfigStorage()
      const store = createStore(storage)

      const config = store.load('accountA', ['groupA', 'groupB'])

      expect(config.visibleGroupKeys.length).assertEqual(3)
      expect(config.visibleGroupKeys[0]).assertEqual(CONVERSATION_GROUP_DEFAULT_ALL_KEY)
      expect(config.visibleGroupKeys[1]).assertEqual(CONVERSATION_GROUP_DEFAULT_AIT_KEY)
      expect(config.visibleGroupKeys[2]).assertEqual(CONVERSATION_GROUP_DEFAULT_UNREAD_KEY)
      expect(config.hiddenGroupKeys.length).assertEqual(2)
      expect(config.hiddenGroupKeys[0]).assertEqual('groupA')
      expect(config.hiddenGroupKeys[1]).assertEqual('groupB')
      expect(storage.flushCount).assertEqual(1)
    })

    it('should_normalize_all_group_first_remove_duplicates_and_stale_cloud_groups', 0, () => {
      const storage = new MemoryDisplayConfigStorage()
      storage.putString('conversation_group_display_config_accountA', JSON.stringify({
        version: 1,
        accountId: 'accountA',
        visibleGroupKeys: ['groupGone', 'groupA', CONVERSATION_GROUP_DEFAULT_UNREAD_KEY,
          CONVERSATION_GROUP_DEFAULT_ALL_KEY, 'groupA'],
        hiddenGroupKeys: [CONVERSATION_GROUP_DEFAULT_AIT_KEY, 'groupGone', 'groupB', 'groupB'],
        updateTime: 1
      }))
      const store = createStore(storage)

      const config = store.load('accountA', ['groupA', 'groupB'])

      expect(config.visibleGroupKeys.length).assertEqual(3)
      expect(config.visibleGroupKeys[0]).assertEqual(CONVERSATION_GROUP_DEFAULT_ALL_KEY)
      expect(config.visibleGroupKeys[1]).assertEqual('groupA')
      expect(config.visibleGroupKeys[2]).assertEqual(CONVERSATION_GROUP_DEFAULT_UNREAD_KEY)
      expect(config.hiddenGroupKeys.length).assertEqual(2)
      expect(config.hiddenGroupKeys[0]).assertEqual(CONVERSATION_GROUP_DEFAULT_AIT_KEY)
      expect(config.hiddenGroupKeys[1]).assertEqual('groupB')
      expect(storage.flushCount).assertEqual(1)
    })

    it('should_put_local_created_group_visible_and_remote_created_group_hidden', 0, () => {
      const storage = new MemoryDisplayConfigStorage()
      const store = createStore(storage)

      store.load('accountA', [])
      store.onGroupCreated('accountA', 'localGroup', ConversationGroupCreateSource.LOCAL)
      store.onGroupCreated('accountA', 'remoteGroup', ConversationGroupCreateSource.REMOTE)
      const config = store.getSnapshot('accountA')

      expect(config?.visibleGroupKeys.includes('localGroup')).assertTrue()
      expect(config?.hiddenGroupKeys.includes('remoteGroup')).assertTrue()
      expect(config?.visibleGroupKeys.includes('remoteGroup')).assertFalse()
      expect(storage.flushCount).assertEqual(3)
    })

    it('should_ignore_created_group_when_group_already_exists_in_display_config', 0, () => {
      const storage = new MemoryDisplayConfigStorage()
      const store = createStore(storage)

      store.load('accountA', ['groupA', 'groupB'])
      store.moveToVisible('accountA', 'groupA')
      const beforeFlushCount = storage.flushCount
      store.onGroupCreated('accountA', 'groupA', ConversationGroupCreateSource.REMOTE)
      store.onGroupCreated('accountA', 'groupB', ConversationGroupCreateSource.LOCAL)
      const config = store.getSnapshot('accountA')

      expect(config?.visibleGroupKeys.includes('groupA')).assertTrue()
      expect(config?.hiddenGroupKeys.includes('groupA')).assertFalse()
      expect(config?.hiddenGroupKeys.includes('groupB')).assertTrue()
      expect(config?.visibleGroupKeys.includes('groupB')).assertFalse()
      expect(storage.flushCount).assertEqual(beforeFlushCount)
    })

    it('should_move_locally_created_group_to_visible_when_remote_callback_arrives_first', 0, () => {
      const storage = new MemoryDisplayConfigStorage()
      const store = createStore(storage)

      store.load('accountA', [])
      store.onGroupCreated('accountA', 'newGroup', ConversationGroupCreateSource.REMOTE)
      store.onLocalGroupCreated('accountA', 'newGroup')
      const config = store.getSnapshot('accountA')

      expect(config?.visibleGroupKeys[config.visibleGroupKeys.length - 1]).assertEqual('newGroup')
      expect(config?.hiddenGroupKeys.includes('newGroup')).assertFalse()
    })

    it('should_ignore_deleted_group_when_group_does_not_exist_in_display_config', 0, () => {
      const storage = new MemoryDisplayConfigStorage()
      const store = createStore(storage)

      store.load('accountA', ['groupA'])
      const beforeFlushCount = storage.flushCount
      store.onGroupDeleted('accountA', 'groupGone')
      const config = store.getSnapshot('accountA')

      expect(config?.visibleGroupKeys.length).assertEqual(3)
      expect(config?.hiddenGroupKeys.length).assertEqual(1)
      expect(config?.hiddenGroupKeys[0]).assertEqual('groupA')
      expect(storage.flushCount).assertEqual(beforeFlushCount)
    })

    it('should_move_and_reorder_groups_with_immediate_persistence', 0, () => {
      const storage = new MemoryDisplayConfigStorage()
      const store = createStore(storage)

      store.load('accountA', ['groupA', 'groupB'])
      store.moveToVisible('accountA', 'groupA')
      store.reorderVisible('accountA', ['groupA', CONVERSATION_GROUP_DEFAULT_UNREAD_KEY,
        CONVERSATION_GROUP_DEFAULT_ALL_KEY, CONVERSATION_GROUP_DEFAULT_AIT_KEY])
      store.moveToHidden('accountA', CONVERSATION_GROUP_DEFAULT_AIT_KEY)
      const config = store.getSnapshot('accountA')

      expect(config?.visibleGroupKeys[0]).assertEqual(CONVERSATION_GROUP_DEFAULT_ALL_KEY)
      expect(config?.visibleGroupKeys[1]).assertEqual('groupA')
      expect(config?.visibleGroupKeys[2]).assertEqual(CONVERSATION_GROUP_DEFAULT_UNREAD_KEY)
      expect(config?.hiddenGroupKeys.includes(CONVERSATION_GROUP_DEFAULT_AIT_KEY)).assertTrue()
      expect(storage.flushCount).assertEqual(4)
    })

    it('should_remove_deleted_group_from_visible_and_hidden', 0, () => {
      const storage = new MemoryDisplayConfigStorage()
      const store = createStore(storage)

      store.load('accountA', ['groupA', 'groupB'])
      store.moveToVisible('accountA', 'groupA')
      store.onGroupDeleted('accountA', 'groupA')
      const config = store.getSnapshot('accountA')

      expect(config?.visibleGroupKeys.includes('groupA')).assertFalse()
      expect(config?.hiddenGroupKeys.includes('groupA')).assertFalse()
      expect(config?.hiddenGroupKeys.includes('groupB')).assertTrue()
      expect(storage.flushCount).assertEqual(3)
    })
  })
}
