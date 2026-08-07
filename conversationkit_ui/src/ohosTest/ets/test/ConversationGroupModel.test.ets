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
  ConversationGroupDisplayConfig
} from '@nimkit/chatkit'
import {
  V2NIMConversation,
  V2NIMConversationGroup,
  V2NIMConversationType,
  V2NIMError,
  V2NIMErrorMap
} from '@nimsdk/base'
import {
  buildConversationGroupInfoLists,
  buildConversationGroupSuccessNameList,
  ConversationGroupDefaultCounts,
  ConversationGroupDefaultNames,
  createDefaultUnreadConversationFilter,
  createInitialConversationGroupInfos,
  moveConversationGroupKeysByIndex,
  mergeConversationGroupMemberConversations,
  pickConversationsByIds,
  filterAddConversationCandidates,
  filterAddConversationCandidatesForGroup,
  filterConversationsByDefaultGroup,
  filterConversationsByKeyword,
  isConversationBelongedGroupLimitError,
  isConversationGroupLimitError,
  isConversationGroupNotExistError,
  isConversationNotExistError,
  isConversationsInGroupLimitError,
  resolveConversationGroupOperationFailureKind,
  ConversationGroupOperationFailureKind,
  isDefaultUnreadConversationFilter,
  toggleConversationSelection
} from '../../../main/ets/model/ConversationGroupModel'
import { ConversationItem } from '../../../main/ets/strategy/ConversationStrategy'

const DEFAULT_GROUP_NAMES: ConversationGroupDefaultNames = new ConversationGroupDefaultNames('All', 'Mentions', 'Unread')

function createConversation(conversationId: string, unreadCount: number, mute: boolean = false): ConversationItem {
  return {
    conversationId: conversationId,
    type: V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P,
    stickTop: false,
    serverExtension: '',
    unreadCount: unreadCount,
    mute: mute,
    sortOrder: 1,
    createTime: 1,
    updateTime: 1
  } as ConversationItem
}

function createCloudConversation(conversationId: string, name: string, groupIds?: string[],
  sortOrder: number = 1): V2NIMConversation {
  const conversation = createConversation(conversationId, 0) as V2NIMConversation
  conversation.name = name
  conversation.groupIds = groupIds
  conversation.sortOrder = sortOrder
  return conversation
}

function createGroup(groupId: string, name: string): V2NIMConversationGroup {
  return {
    groupId: groupId,
    name: name,
    serverExtension: '',
    createTime: 1,
    updateTime: 1
  } as V2NIMConversationGroup
}

function createError(code: number, message: string): V2NIMError {
  return {
    name: 'V2NIMError',
    message: message,
    code: code,
    desc: message,
    detail: {}
  } as V2NIMError
}

export default function conversationGroupModelTest() {
  describe('ConversationGroupModel', () => {
    it('should_build_visible_and_hidden_group_infos_from_display_config', 0, () => {
      const config: ConversationGroupDisplayConfig = {
        version: 1,
        accountId: 'accountA',
        visibleGroupKeys: [CONVERSATION_GROUP_DEFAULT_ALL_KEY, 'groupA', CONVERSATION_GROUP_DEFAULT_UNREAD_KEY],
        hiddenGroupKeys: [CONVERSATION_GROUP_DEFAULT_AIT_KEY, 'groupB'],
        updateTime: 1
      }
      const unreadMap: Map<string, number> = new Map()
      unreadMap.set('groupA', 3)
      unreadMap.set('groupB', 4)

      const result = buildConversationGroupInfoLists(config, [createGroup('groupA', '项目'),
        createGroup('groupB', '客户')], unreadMap, new ConversationGroupDefaultCounts(9, 2, 5), DEFAULT_GROUP_NAMES)

      expect(result.visibleGroups.length).assertEqual(3)
      expect(result.visibleGroups[0].name).assertEqual('All')
      expect(result.visibleGroups[1].name).assertEqual('项目')
      expect(result.visibleGroups[1].unreadCount).assertEqual(3)
      expect(result.hiddenGroups[0].name).assertEqual('Mentions')
      expect(result.hiddenGroups[1].name).assertEqual('客户')
    })

    it('should_create_initial_all_group_before_cloud_groups_loaded', 0, () => {
      const groups = createInitialConversationGroupInfos(new ConversationGroupDefaultCounts(8, 2, 3),
        DEFAULT_GROUP_NAMES)

      expect(groups.length).assertEqual(1)
      expect(groups[0].groupKey).assertEqual(CONVERSATION_GROUP_DEFAULT_ALL_KEY)
      expect(groups[0].name).assertEqual('All')
      expect(groups[0].unreadCount).assertEqual(8)
    })

    it('should_display_filtered_unread_count_for_unread_default_group', 0, () => {
      const counts = new ConversationGroupDefaultCounts(12, 3, 8)

      const all = createInitialConversationGroupInfos(counts, DEFAULT_GROUP_NAMES)[0]
      const unread = buildConversationGroupInfoLists({
        version: 1,
        accountId: 'accountA',
        visibleGroupKeys: [CONVERSATION_GROUP_DEFAULT_ALL_KEY, CONVERSATION_GROUP_DEFAULT_UNREAD_KEY],
        hiddenGroupKeys: [CONVERSATION_GROUP_DEFAULT_AIT_KEY],
        updateTime: 1
      }, [], new Map(), counts, DEFAULT_GROUP_NAMES).visibleGroups[1]

      expect(all.unreadCount).assertEqual(12)
      expect(unread.unreadCount).assertEqual(8)
    })

    it('should_match_default_unread_count_filter_only_when_ignoring_muted_without_custom_scope', 0, () => {
      const filter = createDefaultUnreadConversationFilter()

      expect(filter.ignoreMuted).assertTrue()
      expect(isDefaultUnreadConversationFilter(filter)).assertTrue()
      expect(isDefaultUnreadConversationFilter({
        ignoreMuted: true,
        conversationGroupId: 'groupA'
      })).assertFalse()
      expect(isDefaultUnreadConversationFilter({
        ignoreMuted: true,
        conversationTypes: [V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P]
      })).assertFalse()
      expect(isDefaultUnreadConversationFilter({
        ignoreMuted: false
      })).assertFalse()
    })

    it('should_identify_conversation_group_limit_error', 0, () => {
      expect(isConversationGroupLimitError(createError(
        V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_GROUP_LIMIT.code,
        'conversation group limit'
      ))).assertTrue()
      expect(isConversationGroupLimitError(createError(500, 'server error'))).assertFalse()
      expect(isConversationGroupLimitError(undefined)).assertFalse()
    })

    it('should_identify_conversation_group_not_exist_error', 0, () => {
      expect(isConversationGroupNotExistError(createError(
        V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_GROUP_NOT_EXIST.code,
        'conversation group not exist'
      ))).assertTrue()
      expect(isConversationGroupNotExistError(createError(500, 'server error'))).assertFalse()
      expect(isConversationGroupNotExistError(undefined)).assertFalse()
    })

    it('should_identify_add_conversation_operation_failure_reasons', 0, () => {
      expect(isConversationBelongedGroupLimitError(createError(
        V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_BELONGED_GROUP_LIMIT.code,
        'conversation belonged group limit'
      ))).assertTrue()
      expect(isConversationsInGroupLimitError(createError(
        V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATIONS_IN_GROUP_LIMIT.code,
        'conversations in group limit'
      ))).assertTrue()
      expect(isConversationNotExistError(createError(
        V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_NOT_EXIST.code,
        'conversation not exist'
      ))).assertTrue()
      expect(isConversationBelongedGroupLimitError(createError(500, 'server error'))).assertFalse()
      expect(isConversationsInGroupLimitError(undefined)).assertFalse()
      expect(isConversationNotExistError(undefined)).assertFalse()
    })

    it('should_resolve_operation_failure_kind_by_priority', 0, () => {
      const groupNotExist = createError(
        V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_GROUP_NOT_EXIST.code,
        'conversation group not exist'
      )
      const belongedLimit = createError(
        V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_BELONGED_GROUP_LIMIT.code,
        'conversation belonged group limit'
      )
      const conversationNotExist = createError(
        V2NIMErrorMap.V2NIM_ERROR_CODE_CONVERSATION_NOT_EXIST.code,
        'conversation not exist'
      )

      expect(resolveConversationGroupOperationFailureKind([belongedLimit, groupNotExist]))
        .assertEqual(ConversationGroupOperationFailureKind.GROUP_NOT_EXIST)
      expect(resolveConversationGroupOperationFailureKind([belongedLimit, conversationNotExist]))
        .assertEqual(ConversationGroupOperationFailureKind.BELONGED_GROUP_LIMIT)
      expect(resolveConversationGroupOperationFailureKind([conversationNotExist]))
        .assertEqual(ConversationGroupOperationFailureKind.CONVERSATION_NOT_EXIST)
      expect(resolveConversationGroupOperationFailureKind([createError(500, 'server error')]))
        .assertEqual(ConversationGroupOperationFailureKind.UNKNOWN)
    })

    it('should_filter_default_groups_from_loaded_conversations', 0, () => {
      const conversations: ConversationItem[] = [
        createConversation('c1', 0),
        createConversation('c2', 2),
        createConversation('c3', 1)
      ]
      const aitIds: Set<string> = new Set()
      aitIds.add('c3')

      const ait = filterConversationsByDefaultGroup(conversations, CONVERSATION_GROUP_DEFAULT_AIT_KEY, aitIds)
      const unread = filterConversationsByDefaultGroup(conversations, CONVERSATION_GROUP_DEFAULT_UNREAD_KEY, aitIds)

      expect(ait.length).assertEqual(1)
      expect(ait[0].conversationId).assertEqual('c3')
      expect(unread.length).assertEqual(2)
    })

    it('should_filter_ait_group_by_ait_and_unread_badge_state', 0, () => {
      const conversations: ConversationItem[] = [
        createConversation('c1', 0),
        createConversation('c2', 2),
        createConversation('c3', 1)
      ]
      const aitIds: Set<string> = new Set()
      aitIds.add('c1')
      aitIds.add('c2')

      const ait = filterConversationsByDefaultGroup(conversations, CONVERSATION_GROUP_DEFAULT_AIT_KEY, aitIds)

      expect(ait.length).assertEqual(1)
      expect(ait[0].conversationId).assertEqual('c2')
    })

    it('should_filter_unread_group_by_unread_and_not_muted', 0, () => {
      const conversations: ConversationItem[] = [
        createConversation('c1', 0),
        createConversation('c2', 2, false),
        createConversation('c3', 4, true)
      ]

      const unread = filterConversationsByDefaultGroup(conversations, CONVERSATION_GROUP_DEFAULT_UNREAD_KEY, new Set())

      expect(unread.length).assertEqual(1)
      expect(unread[0].conversationId).assertEqual('c2')
    })

    it('should_filter_add_conversation_candidates_by_current_group_members', 0, () => {
      const conversations: V2NIMConversation[] = [
        createConversation('c1', 0) as V2NIMConversation,
        createConversation('c2', 0) as V2NIMConversation
      ]
      const currentGroupConversationIds: Set<string> = new Set()
      currentGroupConversationIds.add('c1')

      const candidates = filterAddConversationCandidates(conversations, currentGroupConversationIds)

      expect(candidates.length).assertEqual(1)
      expect(candidates[0].conversationId).assertEqual('c2')
    })

    it('should_filter_add_candidates_by_loaded_members_and_conversation_group_ids', 0, () => {
      const conversations: V2NIMConversation[] = [
        createCloudConversation('c1', '会话一', ['groupA']),
        createCloudConversation('c2', '会话二', ['groupB']),
        createCloudConversation('c3', '会话三')
      ]
      const currentGroupConversationIds: Set<string> = new Set()
      currentGroupConversationIds.add('c2')

      const candidates = filterAddConversationCandidatesForGroup(conversations, currentGroupConversationIds, 'groupA')

      expect(candidates.length).assertEqual(1)
      expect(candidates[0].conversationId).assertEqual('c3')
    })

    it('should_filter_loaded_conversations_by_keyword', 0, () => {
      const conversations: V2NIMConversation[] = [
        createCloudConversation('p2p|alice', '产品用户'),
        createCloudConversation('team|project', '项目群'),
        createCloudConversation('p2p|bob', 'Bob')
      ]

      const byName = filterConversationsByKeyword(conversations, '项目')
      const byIdOnly = filterConversationsByKeyword(conversations, 'alice')
      const emptyKeyword = filterConversationsByKeyword(conversations, ' ')

      expect(byName.length).assertEqual(1)
      expect(byName[0].conversationId).assertEqual('team|project')
      expect(byIdOnly.length).assertEqual(0)
      expect(emptyKeyword.length).assertEqual(3)
    })

    it('should_pick_conversations_by_success_ids_in_selected_order', 0, () => {
      const conversations: V2NIMConversation[] = [
        createCloudConversation('c1', '会话一'),
        createCloudConversation('c2', '会话二'),
        createCloudConversation('c3', '会话三')
      ]

      const picked = pickConversationsByIds(conversations, ['c3', 'missing', 'c1'])

      expect(picked.length).assertEqual(2)
      expect(picked[0].conversationId).assertEqual('c3')
      expect(picked[1].conversationId).assertEqual('c1')
    })

    it('should_merge_group_members_without_duplicates_and_keep_recent_order', 0, () => {
      const source: V2NIMConversation[] = [
        createCloudConversation('c2', '旧会话二', ['groupA'], 20),
        createCloudConversation('c3', '会话三', ['groupA'], 10)
      ]
      const incoming: V2NIMConversation[] = [
        createCloudConversation('c1', '会话一', ['groupA'], 30),
        createCloudConversation('c2', '新会话二', ['groupA'], 20)
      ]

      const merged = mergeConversationGroupMemberConversations(source, incoming)

      expect(merged.length).assertEqual(3)
      expect(merged[0].conversationId).assertEqual('c1')
      expect(merged[1].conversationId).assertEqual('c2')
      expect(merged[1].name).assertEqual('新会话二')
      expect(merged[2].conversationId).assertEqual('c3')
    })

    it('should_build_success_name_list_with_success_names', 0, () => {
      const conversations: V2NIMConversation[] = [
        createCloudConversation('c1', 'Conversation A'),
        createCloudConversation('c2', 'Conversation B')
      ]

      const names = buildConversationGroupSuccessNameList(conversations, ', ', ' and more')

      expect(names).assertEqual('Conversation A, Conversation B')
    })

    it('should_build_success_name_list_with_max_ten_names_and_overflow_suffix', 0, () => {
      const conversations: V2NIMConversation[] = []
      for (let i = 1; i <= 11; i++) {
        conversations.push(createCloudConversation(`c${i}`, `Conversation ${i}`))
      }

      const names = buildConversationGroupSuccessNameList(conversations, ', ', ' and more')

      expect(names).assertEqual('Conversation 1, Conversation 2, Conversation 3, Conversation 4, Conversation 5, ' +
        'Conversation 6, Conversation 7, Conversation 8, Conversation 9, Conversation 10 and more')
    })

    it('should_toggle_selection_and_report_limit', 0, () => {
      const selectedIds: string[] = ['c1']

      const removed = toggleConversationSelection(selectedIds, 'c1', 2)
      const added = toggleConversationSelection(removed.selectedIds, 'c2', 2)
      const limited = toggleConversationSelection(added.selectedIds, 'c3', 2)

      expect(removed.selectedIds.length).assertEqual(0)
      expect(removed.reachedLimit).assertFalse()
      expect(added.selectedIds.length).assertEqual(1)
      expect(added.selectedIds[0]).assertEqual('c2')
      expect(limited.selectedIds.length).assertEqual(1)
      expect(limited.reachedLimit).assertFalse()

      const selectedTwo = toggleConversationSelection(added.selectedIds, 'c1', 2)
      const overLimit = toggleConversationSelection(selectedTwo.selectedIds, 'c3', 2)

      expect(selectedTwo.selectedIds.length).assertEqual(2)
      expect(overLimit.selectedIds.length).assertEqual(2)
      expect(overLimit.reachedLimit).assertTrue()
    })

    it('should_move_group_key_by_index', 0, () => {
      const result = moveConversationGroupKeysByIndex(['groupA', 'groupB', 'groupC'], 2, 0)

      expect(result[0]).assertEqual('groupC')
      expect(result[1]).assertEqual('groupA')
      expect(result[2]).assertEqual('groupB')
    })

    it('should_ignore_invalid_group_key_move_index', 0, () => {
      const groupKeys: string[] = ['groupA', 'groupB']
      const sameIndex = moveConversationGroupKeysByIndex(groupKeys, 1, 1)
      const outOfRange = moveConversationGroupKeysByIndex(groupKeys, 0, 2)

      expect(sameIndex[0]).assertEqual('groupA')
      expect(sameIndex[1]).assertEqual('groupB')
      expect(outOfRange[0]).assertEqual('groupA')
      expect(outOfRange[1]).assertEqual('groupB')
    })
  })
}
