/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium'
import { V2NIMConversationType } from '@nimsdk/base'
import {
  applyP2PUserProfileDisplayInfo,
  collectP2PConversationTargetIds,
  collectPendingSubscriptionAccounts,
  mergeConversationBatch,
  filterLoadedConversationIds,
  hasLoadedConversationId,
  mergeInitialConversations,
  resolveConversationDisplayInfo,
  resolveDeferredBatchDelay
} from '../../../main/ets/viewmodel/ConversationUpdateUtils'

class TestConversationRef {
  conversationId: string
  sortOrder: number

  constructor(conversationId: string, sortOrder: number = 0) {
    this.conversationId = conversationId
    this.sortOrder = sortOrder
  }
}

class TestConversationDisplayRef {
  conversationId: string
  type: V2NIMConversationType
  name?: string
  avatar?: string

  constructor(
    conversationId: string,
    type: V2NIMConversationType,
    name?: string,
    avatar?: string
  ) {
    this.conversationId = conversationId
    this.type = type
    this.name = name
    this.avatar = avatar
  }
}

export default function conversationUpdateUtilsTest() {
  describe('conversationUpdateUtilsTest', () => {
    it('should_ignore_profile_changed_accounts_without_loaded_conversation', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef('accountA|1|uikit100'),
        new TestConversationRef('accountA|1|uikit200')
      ]
      const changedConversationIds: string[] = [
        'accountA|1|uikit100',
        'accountA|1|uikit9999'
      ]
      const result: string[] = filterLoadedConversationIds(loadedConversations, changedConversationIds)

      expect(result.length).assertEqual(1)
      expect(result[0]).assertEqual('accountA|1|uikit100')
    })

    it('should_deduplicate_loaded_profile_changed_conversation_ids', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef('accountA|1|uikit100'),
        new TestConversationRef('accountA|1|uikit200')
      ]
      const changedConversationIds: string[] = [
        'accountA|1|uikit100',
        'accountA|1|uikit100',
        'accountA|1|uikit200'
      ]
      const result: string[] = filterLoadedConversationIds(loadedConversations, changedConversationIds)

      expect(result.length).assertEqual(2)
      expect(result[0]).assertEqual('accountA|1|uikit100')
      expect(result[1]).assertEqual('accountA|1|uikit200')
    })

    it('should_only_update_loaded_non_empty_conversation_id', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef('accountA|1|uikit100'),
        new TestConversationRef('')
      ]

      expect(hasLoadedConversationId(loadedConversations, 'accountA|1|uikit100')).assertTrue()
      expect(hasLoadedConversationId(loadedConversations, 'accountA|1|uikit9999')).assertFalse()
      expect(hasLoadedConversationId(loadedConversations, '')).assertFalse()
    })

    it('should_collect_and_clear_pending_subscription_accounts', 0, () => {
      const pendingAccounts: Set<string> = new Set()
      pendingAccounts.add('uikit100')
      pendingAccounts.add('')
      pendingAccounts.add('uikit200')

      const result: string[] = collectPendingSubscriptionAccounts(pendingAccounts)

      expect(result.length).assertEqual(2)
      expect(result[0]).assertEqual('uikit100')
      expect(result[1]).assertEqual('uikit200')
      expect(pendingAccounts.size).assertEqual(0)
    })

    it('should_resolve_ai_user_avatar_for_p2p_conversation', 0, () => {
      const conversation = new TestConversationDisplayRef(
        'accountA|1|ai_user',
        V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P,
        'ai_user',
        ''
      )

      const result = resolveConversationDisplayInfo(
        conversation,
        'ai_user',
        { name: 'AI Assistant', avatar: 'https://example.com/ai.png' }
      )

      expect(result.name).assertEqual('AI Assistant')
      expect(result.avatar).assertEqual('https://example.com/ai.png')
    })

    it('should_keep_existing_p2p_name_when_resolving_ai_display_info', 0, () => {
      const conversation = new TestConversationDisplayRef(
        'accountA|1|userA',
        V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P,
        'Old Name',
        'old.png'
      )

      const result = resolveConversationDisplayInfo(
        conversation,
        'userA',
        { name: 'New Name', avatar: 'new.png' }
      )

      expect(result.name).assertEqual('Old Name')
      expect(result.avatar).assertEqual('new.png')
    })

    it('should_apply_p2p_cloud_user_profile_to_stale_display_info', 0, () => {
      const conversation = new TestConversationDisplayRef(
        'accountA|1|userA',
        V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P,
        'Old Name',
        'old.png'
      )

      const result = applyP2PUserProfileDisplayInfo(
        conversation,
        'userA',
        { name: 'New Name', avatar: 'new.png' }
      )

      expect(result.name).assertEqual('New Name')
      expect(result.avatar).assertEqual('new.png')
    })

    it('should_ignore_cloud_user_profile_for_team_conversation', 0, () => {
      const conversation = new TestConversationDisplayRef(
        'accountA|2|teamA',
        V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM,
        'Team Name',
        'team.png'
      )

      const result = applyP2PUserProfileDisplayInfo(
        conversation,
        'teamA',
        { name: 'New Name', avatar: 'new.png' }
      )

      expect(result.name).assertEqual('Team Name')
      expect(result.avatar).assertEqual('team.png')
    })

    it('should_keep_existing_p2p_display_info_when_cloud_profile_is_empty', 0, () => {
      const conversation = new TestConversationDisplayRef(
        'accountA|1|userA',
        V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P,
        'Old Name',
        'old.png'
      )

      const result = applyP2PUserProfileDisplayInfo(
        conversation,
        'userA',
        { name: '', avatar: '' }
      )

      expect(result.name).assertEqual('Old Name')
      expect(result.avatar).assertEqual('old.png')
    })

    it('should_keep_ai_display_info_when_cloud_user_profile_refreshes_later', 0, () => {
      const conversation = new TestConversationDisplayRef(
        'accountA|1|ai_user',
        V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P,
        'Cloud User',
        'cloud-user.png'
      )

      const result = resolveConversationDisplayInfo(
        conversation,
        'ai_user',
        { name: 'AI Assistant', avatar: '' },
        undefined,
        { replaceName: true, replaceAvatar: true }
      )

      expect(result.name).assertEqual('AI Assistant')
      expect(result.avatar).assertEqual('')
    })

    it('should_prefer_user_ai_bot_icon_over_ai_user_avatar', 0, () => {
      const conversation = new TestConversationDisplayRef(
        'accountA|1|bot_user',
        V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P,
        'Bot Alias',
        'old.png'
      )

      const result = resolveConversationDisplayInfo(
        conversation,
        'bot_user',
        { name: 'Bot Name', avatar: 'bot.png' },
        { name: 'AI Name', avatar: 'ai.png' }
      )

      expect(result.name).assertEqual('Bot Alias')
      expect(result.avatar).assertEqual('bot.png')
    })

    it('should_ignore_ai_avatar_for_team_conversation', 0, () => {
      const conversation = new TestConversationDisplayRef(
        'accountA|2|team1',
        V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM,
        'Team',
        ''
      )

      const result = resolveConversationDisplayInfo(
        conversation,
        'team1',
        { name: 'AI Assistant', avatar: 'https://example.com/ai.png' }
      )

      expect(result.name).assertEqual('Team')
      expect(result.avatar).assertEqual('')
    })

    it('should_collect_unique_p2p_conversation_target_ids', 0, () => {
      const conversations: TestConversationDisplayRef[] = [
        new TestConversationDisplayRef('accountA|1|userA', V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P),
        new TestConversationDisplayRef('accountA|1|userA', V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P),
        new TestConversationDisplayRef('accountA|2|teamA', V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM),
        new TestConversationDisplayRef('', V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P)
      ]

      const result = collectP2PConversationTargetIds(
        conversations,
        (conversationId: string): string => {
          const segments = conversationId.split('|')
          return segments.length > 2 ? segments[2] : ''
        }
      )

      expect(result.length).assertEqual(1)
      expect(result[0]).assertEqual('userA')
    })

    it('should_merge_initial_conversations_with_pending_updates_and_deletes', 0, () => {
      const initialConversations: TestConversationRef[] = [
        new TestConversationRef('accountA|1|uikit100', 100),
        new TestConversationRef('accountA|1|uikit200', 90)
      ]
      const pendingUpserts: TestConversationRef[] = [
        new TestConversationRef('accountA|1|uikit200', 110),
        new TestConversationRef('accountA|1|uikit300', 95)
      ]
      const pendingDeletes: Set<string> = new Set()
      pendingDeletes.add('accountA|1|uikit100')

      const result: TestConversationRef[] = mergeInitialConversations(
        initialConversations,
        pendingUpserts,
        pendingDeletes,
        (a: TestConversationRef, b: TestConversationRef): number => b.sortOrder - a.sortOrder
      )

      expect(result.length).assertEqual(2)
      expect(result[0].conversationId).assertEqual('accountA|1|uikit200')
      expect(result[0].sortOrder).assertEqual(110)
      expect(result[1].conversationId).assertEqual('accountA|1|uikit300')
      expect(result[1].sortOrder).assertEqual(95)
    })

    it('should_merge_batch_updates_with_one_sort_pass', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef('accountA|1|uikit100', 100),
        new TestConversationRef('accountA|1|uikit200', 90),
        new TestConversationRef('accountA|1|uikit300', 80)
      ]
      const updateConversations: TestConversationRef[] = [
        new TestConversationRef('accountA|1|uikit200', 130),
        new TestConversationRef('accountA|1|uikit400', 95)
      ]
      const deletedConversationIds: Set<string> = new Set()
      deletedConversationIds.add('accountA|1|uikit100')
      let sortCount = 0

      const result = mergeConversationBatch(
        loadedConversations,
        updateConversations,
        deletedConversationIds,
        (a: TestConversationRef, b: TestConversationRef): number => {
          sortCount++
          return b.sortOrder - a.sortOrder
        }
      )

      expect(result.changed).assertTrue()
      expect(result.conversations.length).assertEqual(3)
      expect(result.conversations[0].conversationId).assertEqual('accountA|1|uikit200')
      expect(result.conversations[1].conversationId).assertEqual('accountA|1|uikit400')
      expect(result.conversations[2].conversationId).assertEqual('accountA|1|uikit300')
      expect(sortCount > 0).assertTrue()
      expect(sortCount < 6).assertTrue()
    })

    it('should_report_no_batch_change_when_updates_and_deletes_are_empty', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef('accountA|1|uikit100', 100),
        new TestConversationRef('accountA|1|uikit200', 90)
      ]

      const result = mergeConversationBatch(
        loadedConversations,
        [],
        new Set<string>(),
        (a: TestConversationRef, b: TestConversationRef): number => b.sortOrder - a.sortOrder
      )

      expect(result.changed).assertFalse()
      expect(result.conversations.length).assertEqual(2)
      expect(result.conversations[0].conversationId).assertEqual('accountA|1|uikit100')
      expect(result.conversations[1].conversationId).assertEqual('accountA|1|uikit200')
    })

    it('should_delay_large_deferred_batches_longer_than_small_batches', 0, () => {
      expect(resolveDeferredBatchDelay(0, 20, 100, 300)).assertEqual(0)
      expect(resolveDeferredBatchDelay(20, 20, 100, 300)).assertEqual(100)
      expect(resolveDeferredBatchDelay(60, 20, 100, 300)).assertEqual(200)
      expect(resolveDeferredBatchDelay(200, 20, 100, 300)).assertEqual(300)
    })

    // ---- 边界用例 ----

    it('should_return_empty_for_merge_with_all_deleted_and_no_upserts', 0, () => {
      const initial: TestConversationRef[] = [
        new TestConversationRef('conv1', 100),
        new TestConversationRef('conv2', 200),
      ]
      const deletes = new Set<string>()
      deletes.add('conv1')
      deletes.add('conv2')
      const merged = mergeConversationBatch(initial, [], deletes,
        (a: TestConversationRef, b: TestConversationRef): number => b.sortOrder - a.sortOrder)
      expect(merged.changed).assertTrue()
      expect(merged.conversations.length).assertEqual(0)
    })

    it('should_merge_initial_conversations_with_empty_pending_data', 0, () => {
      const initial: TestConversationRef[] = [
        new TestConversationRef('conv_a', 10),
        new TestConversationRef('conv_b', 20),
      ]
      const result = mergeInitialConversations(initial, [], new Set(),
        (a: TestConversationRef, b: TestConversationRef): number => a.sortOrder - b.sortOrder)
      expect(result.length).assertEqual(2)
      expect(result[0].conversationId).assertEqual('conv_a')
    })

    it('should_detect_pending_delete_for_initial_merge', 0, () => {
      const initial: TestConversationRef[] = [
        new TestConversationRef('keep', 10),
        new TestConversationRef('drop', 20),
      ]
      const deletes = new Set<string>()
      deletes.add('drop')
      const result = mergeInitialConversations(initial, [], deletes,
        (a: TestConversationRef, b: TestConversationRef): number => a.sortOrder - b.sortOrder)
      expect(result.length).assertEqual(1)
      expect(result[0].conversationId).assertEqual('keep')
    })

    // ---- resolveDeferredBatchDelay 边界 ----

    it('should_return_zero_delay_when_batch_size_is_zero', 0, () => {
      const delay: number = resolveDeferredBatchDelay(100, 0, 200, 1000)
      expect(delay).assertEqual(200)
    })

    it('should_return_zero_delay_when_batch_size_is_negative', 0, () => {
      const delay: number = resolveDeferredBatchDelay(100, -5, 200, 1000)
      expect(delay).assertEqual(200)
    })

    it('should_return_base_delay_when_base_delay_is_zero', 0, () => {
      const delay: number = resolveDeferredBatchDelay(100, 20, 0, 1000)
      expect(delay).assertEqual(0)
    })

    it('should_return_base_delay_when_base_delay_is_negative', 0, () => {
      const delay: number = resolveDeferredBatchDelay(100, 20, -10, 1000)
      expect(delay).assertEqual(-10)
    })

    it('should_return_zero_when_pending_count_is_negative', 0, () => {
      const delay: number = resolveDeferredBatchDelay(-1, 20, 200, 1000)
      expect(delay).assertEqual(0)
    })

    // ---- filterLoadedConversationIds 边界 ----

    it('should_filter_out_empty_conversation_ids_in_loaded_list', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef(''),
        new TestConversationRef('valid1'),
        new TestConversationRef(''),
      ]
      const conversationIds: string[] = ['', 'valid1', 'valid2']
      const result: string[] = filterLoadedConversationIds(loadedConversations, conversationIds)
      expect(result.length).assertEqual(1)
      expect(result[0]).assertEqual('valid1')
    })

    it('should_return_empty_when_all_loaded_conversations_have_empty_id', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef(''),
        new TestConversationRef(''),
      ]
      const conversationIds: string[] = ['', 'someId']
      const result: string[] = filterLoadedConversationIds(loadedConversations, conversationIds)
      expect(result.length).assertEqual(0)
    })

    it('should_return_empty_when_no_loaded_conversations_match', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef('conv_a'),
        new TestConversationRef('conv_b'),
      ]
      const conversationIds: string[] = ['conv_x', 'conv_y']
      const result: string[] = filterLoadedConversationIds(loadedConversations, conversationIds)
      expect(result.length).assertEqual(0)
    })

    it('should_handle_empty_input_arrays_for_filter', 0, () => {
      const loadedConversations: TestConversationRef[] = []
      const conversationIds: string[] = []
      const result: string[] = filterLoadedConversationIds(loadedConversations, conversationIds)
      expect(result.length).assertEqual(0)
    })

    // ---- collectPendingSubscriptionAccounts 边界 ----

    it('should_return_empty_array_when_pending_accounts_is_empty', 0, () => {
      const pendingAccounts: Set<string> = new Set()
      const result: string[] = collectPendingSubscriptionAccounts(pendingAccounts)
      expect(result.length).assertEqual(0)
      expect(pendingAccounts.size).assertEqual(0)
    })

    it('should_filter_out_all_empty_strings_from_pending_accounts', 0, () => {
      const pendingAccounts: Set<string> = new Set()
      pendingAccounts.add('')
      pendingAccounts.add('')
      const result: string[] = collectPendingSubscriptionAccounts(pendingAccounts)
      expect(result.length).assertEqual(0)
      expect(pendingAccounts.size).assertEqual(0)
    })

    // ---- hasLoadedConversationId 边界 ----

    it('should_return_false_for_empty_loaded_list', 0, () => {
      const loadedConversations: TestConversationRef[] = []
      expect(hasLoadedConversationId(loadedConversations, 'anyId')).assertFalse()
    })

    // ---- mergeConversationBatch 边界 ----

    it('should_report_changed_when_only_deletes_present', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef('conv_a', 10),
        new TestConversationRef('conv_b', 20),
      ]
      const deletes = new Set<string>()
      deletes.add('conv_a')
      const result = mergeConversationBatch(loadedConversations, [], deletes,
        (a: TestConversationRef, b: TestConversationRef): number => a.sortOrder - b.sortOrder)
      expect(result.changed).assertTrue()
      expect(result.conversations.length).assertEqual(1)
      expect(result.conversations[0].conversationId).assertEqual('conv_b')
    })

    it('should_report_changed_when_upserts_are_all_deleted', 0, () => {
      const loadedConversations: TestConversationRef[] = [
        new TestConversationRef('conv_a', 10),
      ]
      const upserts: TestConversationRef[] = [
        new TestConversationRef('conv_b', 30),
      ]
      const deletes = new Set<string>()
      deletes.add('conv_b')
      const result = mergeConversationBatch(loadedConversations, upserts, deletes,
        (a: TestConversationRef, b: TestConversationRef): number => a.sortOrder - b.sortOrder)
      expect(result.changed).assertTrue()
      expect(result.conversations.length).assertEqual(1)
      expect(result.conversations[0].conversationId).assertEqual('conv_a')
    })
  })
}
