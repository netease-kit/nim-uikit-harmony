/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { getTeamMemberSearchRenderKey, TeamMemberWithUser } from '@nimkit/chatkit';
import { V2NIMAIUser, V2NIMFriend, V2NIMTeamMember, V2NIMTeamMemberRole, V2NIMUser } from '@nimsdk/base';
import {
  filterAitTeamMembers,
  getAitAIUserRenderKey,
  getAitAIUserShowName,
  isCurrentAitSearchRequest,
  resolveAitSearchViewState,
  resolveAitAIUserSearchTextPresentation,
  shouldLoadAllAitTeamMembers,
  shouldShowAitSpecialItems
} from '../main/ets/common/AitMemberSearchUtils';

class MockTeamMemberData {
  accountId: string = ''
  memberRole: V2NIMTeamMemberRole = V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
  joinTime: number = 0
  teamId: string = 'test_team'
  teamType: number = 0
  inTeam: boolean = true
  teamNick?: string = undefined
}

class MockFriendData {
  accountId: string = ''
  alias?: string = undefined
}

class MockUserData {
  accountId: string = ''
  name?: string = undefined
}

class MockAIUserData {
  accountId: string = ''
  name?: string = undefined
}

function createMember(accountId: string, teamNick?: string, alias?: string, userName?: string): TeamMemberWithUser {
  const teamMember = new MockTeamMemberData()
  teamMember.accountId = accountId
  teamMember.teamNick = teamNick

  const friend = new MockFriendData()
  friend.accountId = accountId
  friend.alias = alias

  const user = new MockUserData()
  user.accountId = accountId
  user.name = userName

  return new TeamMemberWithUser(
    teamMember as V2NIMTeamMember,
    friend as V2NIMFriend,
    user as V2NIMUser
  )
}

export default function aitMemberSearchUtilsTest() {
  describe('AitMemberSearchUtils', () => {
    it('should_return_original_members_when_keyword_is_empty', 0, () => {
      const members: TeamMemberWithUser[] = [createMember('user_1'), createMember('user_2')]

      const result: TeamMemberWithUser[] = filterAitTeamMembers(members, '   ')

      expect(result === members).assertTrue()
    })

    it('should_show_all_and_ai_items_only_without_search_keyword', 0, () => {
      expect(shouldShowAitSpecialItems('')).assertTrue()
      expect(shouldShowAitSpecialItems('   ')).assertTrue()
      expect(shouldShowAitSpecialItems('alice')).assertFalse()
    })

    it('should_load_all_members_only_for_non_empty_unfinished_team_search', 0, () => {
      expect(shouldLoadAllAitTeamMembers('alice', true, false)).assertTrue()
      expect(shouldLoadAllAitTeamMembers('', true, false)).assertFalse()
      expect(shouldLoadAllAitTeamMembers('alice', false, false)).assertFalse()
      expect(shouldLoadAllAitTeamMembers('alice', true, true)).assertFalse()
    })

    it('should_show_loading_below_results_until_full_search_finishes', 0, () => {
      const loadingState = resolveAitSearchViewState('alice', true, false, 1)
      const finishedState = resolveAitSearchViewState('alice', false, true, 2)

      expect(loadingState.showLoading).assertTrue()
      expect(loadingState.showEmpty).assertFalse()
      expect(finishedState.showLoading).assertFalse()
      expect(finishedState.showEmpty).assertFalse()
    })

    it('should_show_empty_state_only_after_successful_full_search', 0, () => {
      const loadingState = resolveAitSearchViewState('missing', true, false, 0)
      const failedState = resolveAitSearchViewState('missing', false, false, 0)
      const finishedState = resolveAitSearchViewState('missing', false, true, 0)
      const clearedState = resolveAitSearchViewState('', false, true, 0)

      expect(loadingState.showEmpty).assertFalse()
      expect(failedState.showEmpty).assertFalse()
      expect(finishedState.showEmpty).assertTrue()
      expect(clearedState.showEmpty).assertFalse()
    })

    it('should_accept_only_current_normalized_query_and_team_request', 0, () => {
      expect(isCurrentAitSearchRequest(3, 3, ' Alice ', 'alice', 'team_1', 'team_1')).assertTrue()
      expect(isCurrentAitSearchRequest(2, 3, 'alice', 'alice', 'team_1', 'team_1')).assertFalse()
      expect(isCurrentAitSearchRequest(3, 3, 'alice', 'bob', 'team_1', 'team_1')).assertFalse()
      expect(isCurrentAitSearchRequest(3, 3, 'alice', 'alice', 'team_1', 'team_2')).assertFalse()
    })

    it('should_match_team_nick_alias_user_name_and_account_id', 0, () => {
      const teamNickMember = createMember('user_1', '群昵称')
      const aliasMember = createMember('user_2', undefined, '好友备注')
      const userNameMember = createMember('user_3', undefined, undefined, '用户昵称')
      const accountMember = createMember('Account_ABC')
      const members: TeamMemberWithUser[] = [teamNickMember, aliasMember, userNameMember, accountMember]

      expect(filterAitTeamMembers(members, '群昵')[0] === teamNickMember).assertTrue()
      expect(filterAitTeamMembers(members, '备注')[0] === aliasMember).assertTrue()
      expect(filterAitTeamMembers(members, '用户')[0] === userNameMember).assertTrue()
      expect(filterAitTeamMembers(members, 'account_abc')[0] === accountMember).assertTrue()
    })

    it('should_refresh_ai_render_key_when_name_changes', 0, () => {
      const aiUser = new MockAIUserData()
      aiUser.accountId = 'AI_130'
      aiUser.name = 'AI Helper'

      const initialKey = getAitAIUserRenderKey(aiUser as V2NIMAIUser)
      aiUser.name = 'AI Assistant'
      const updatedNameKey = getAitAIUserRenderKey(aiUser as V2NIMAIUser)
      aiUser.accountId = 'AI_131'
      const updatedAccountKey = getAitAIUserRenderKey(aiUser as V2NIMAIUser)

      expect(initialKey === updatedNameKey).assertFalse()
      expect(updatedNameKey === updatedAccountKey).assertFalse()
    })

    it('should_fallback_to_account_id_when_ai_name_is_empty', 0, () => {
      const aiUser = new MockAIUserData()
      aiUser.accountId = 'AI_130'
      aiUser.name = 'AI Helper'
      expect(getAitAIUserShowName(aiUser as V2NIMAIUser)).assertEqual('AI Helper')

      aiUser.name = ''
      expect(getAitAIUserShowName(aiUser as V2NIMAIUser)).assertEqual('AI_130')

      aiUser.name = undefined
      expect(getAitAIUserShowName(aiUser as V2NIMAIUser)).assertEqual('AI_130')
    })

    it('should_use_account_id_as_primary_name_when_ai_name_is_empty', 0, () => {
      const aiUser = new MockAIUserData()
      aiUser.accountId = 'AI_130'
      aiUser.name = ''

      const presentation = resolveAitAIUserSearchTextPresentation(aiUser as V2NIMAIUser, '130')

      expect(presentation.primaryMatched).assertTrue()
      expect(presentation.secondaryText).assertEqual('')
    })

    it('should_ignore_case_and_keep_original_order_and_identity', 0, () => {
      const first = createMember('first', 'Alpha')
      const second = createMember('second', undefined, 'ALPHABET')
      const third = createMember('third', undefined, undefined, 'Beta')

      const result: TeamMemberWithUser[] = filterAitTeamMembers([first, second, third], 'alpha')

      expect(result.length).assertEqual(2)
      expect(result[0] === first).assertTrue()
      expect(result[1] === second).assertTrue()
    })

    it('should_refresh_team_member_render_key_when_keyword_or_name_changes', 0, () => {
      const member = createMember('130', '群昵称', '嘿嘿', '用户名称')

      const initialKey = getTeamMemberSearchRenderKey(member, '')
      const searchKey = getTeamMemberSearchRenderKey(member, '  1  ')
      const stableSearchKey = getTeamMemberSearchRenderKey(member, '1')
      const updatedMember = createMember('130', '群昵称', '新备注', '用户名称')
      const updatedAliasKey = getTeamMemberSearchRenderKey(updatedMember, '1')

      expect(initialKey === searchKey).assertFalse()
      expect(searchKey).assertEqual(stableSearchKey)
      expect(searchKey === updatedAliasKey).assertFalse()
    })

    it('should_not_add_pinyin_matching_or_mutate_members', 0, () => {
      const member = createMember('user_1', '哈利波特')
      const members: TeamMemberWithUser[] = [member]

      const result: TeamMemberWithUser[] = filterAitTeamMembers(members, 'hali')

      expect(result.length).assertEqual(0)
      expect(members.length).assertEqual(1)
      expect(members[0] === member).assertTrue()
    })
  })
}
