/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  SearchTextPresentation,
  containsSearchKeyword,
  getContactSearchRenderKey,
  matchesContactSearchKeyword,
  matchesSearchKeyword,
  matchesTeamMemberSearchKeyword,
  normalizeSearchKeyword,
  resolveContactSearchTextPresentation,
  resolveSearchTextPresentation,
  resolveTeamMemberSearchTextPresentation
} from '../../../main/ets/utils/SearchTextUtils'
import { NEUserWithFriend } from '../../../main/ets/model/NEUserWithFriend'
import { TeamMemberWithUser } from '../../../main/ets/model/TeamMemberWithUser'
import { V2NIMFriend, V2NIMTeamMember, V2NIMTeamMemberRole, V2NIMUser } from '@nimsdk/base'

class MockFriend {
  accountId: string = 'account_abc'
  alias?: string = '好友备注'
}

class MockUser {
  accountId: string = 'account_abc'
  name?: string = 'User Alpha'
}

class MockTeamMember {
  accountId: string = 'account_abc'
  memberRole: V2NIMTeamMemberRole = V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
  joinTime: number = 0
  teamId: string = 'team_1'
  teamType: number = 0
  inTeam: boolean = true
  teamNick?: string = '群昵称'
}

export default function searchTextUtilsTest() {
  describe('SearchTextUtils', () => {
    it('should_normalize_whitespace_only_keyword_to_empty', 0, () => {
      expect(normalizeSearchKeyword('   ')).assertEqual('')
      expect(normalizeSearchKeyword('  Alpha  ')).assertEqual('Alpha')
    })

    it('should_match_keyword_without_case_sensitivity', 0, () => {
      expect(containsSearchKeyword('Account_ABC', 'account_abc')).assertTrue()
      expect(containsSearchKeyword('Alpha User', 'BETA')).assertFalse()
    })

    it('should_only_match_explicit_searchable_names', 0, () => {
      expect(matchesSearchKeyword(['好友备注', '群昵称', 'User Alpha'], 'ALPHA')).assertTrue()
      expect(matchesSearchKeyword(['好友备注', '群昵称', 'User Alpha'], 'account_abc')).assertFalse()
    })

    it('should_highlight_primary_without_secondary_when_primary_matches', 0, () => {
      const result: SearchTextPresentation = resolveSearchTextPresentation(
        '好友备注 Alpha',
        ['群昵称 Alpha', '好友备注 Alpha', '用户昵称 Alpha', 'account_alpha'],
        'ALPHA'
      )

      expect(result.primaryMatched).assertTrue()
      expect(result.secondaryText).assertEqual('')
    })

    it('should_return_first_matched_secondary_text_in_candidate_order', 0, () => {
      const result: SearchTextPresentation = resolveSearchTextPresentation(
        '好友备注',
        ['群昵称 Alpha', '好友备注', '用户昵称 Alpha', 'account_alpha'],
        'alpha'
      )

      expect(result.primaryMatched).assertFalse()
      expect(result.secondaryText).assertEqual('群昵称 Alpha')
    })

    it('should_ignore_duplicate_primary_candidate_and_handle_empty_keyword', 0, () => {
      const duplicateResult: SearchTextPresentation = resolveSearchTextPresentation(
        '好友备注',
        ['好友备注', '用户昵称'],
        '用户'
      )
      const emptyResult: SearchTextPresentation = resolveSearchTextPresentation(
        '好友备注',
        ['用户昵称'],
        '   '
      )

      expect(duplicateResult.secondaryText).assertEqual('用户昵称')
      expect(emptyResult.primaryMatched).assertFalse()
      expect(emptyResult.secondaryText).assertEqual('')
    })

    it('should_match_hidden_user_name_when_contact_alias_is_primary', 0, () => {
      const contact = new NEUserWithFriend({
        friend: new MockFriend() as V2NIMFriend,
        user: new MockUser() as V2NIMUser
      })

      const result = resolveContactSearchTextPresentation(contact, 'alpha')

      expect(result.primaryMatched).assertFalse()
      expect(result.secondaryText).assertEqual('User Alpha')
    })

    it('should_match_team_member_names_and_account_id', 0, () => {
      const member = new TeamMemberWithUser(
        new MockTeamMember() as V2NIMTeamMember,
        new MockFriend() as V2NIMFriend,
        new MockUser() as V2NIMUser
      )

      expect(matchesTeamMemberSearchKeyword(member, '群昵')).assertTrue()
      expect(matchesTeamMemberSearchKeyword(member, '好友')).assertTrue()
      expect(matchesTeamMemberSearchKeyword(member, 'alpha')).assertTrue()
      expect(matchesTeamMemberSearchKeyword(member, 'ACCOUNT_ABC')).assertTrue()
    })

    it('should_match_contact_names_and_account_id', 0, () => {
      const contact = new NEUserWithFriend({
        friend: new MockFriend() as V2NIMFriend,
        user: new MockUser() as V2NIMUser
      })

      expect(matchesContactSearchKeyword(contact, '好友')).assertTrue()
      expect(matchesContactSearchKeyword(contact, 'alpha')).assertTrue()
      expect(matchesContactSearchKeyword(contact, 'ACCOUNT_ABC')).assertTrue()
    })

    it('should_change_contact_render_key_when_keyword_or_name_changes', 0, () => {
      const contact = new NEUserWithFriend({
        friend: new MockFriend() as V2NIMFriend,
        user: new MockUser() as V2NIMUser
      })

      const initialKey: string = getContactSearchRenderKey(contact, 'alpha')
      const stableKey: string = getContactSearchRenderKey(contact, '  alpha  ')
      const updatedUser = new MockUser()
      updatedUser.name = 'Updated Alpha'
      contact.user = updatedUser as V2NIMUser
      const updatedNameKey: string = getContactSearchRenderKey(contact, 'alpha')
      const updatedKeywordKey: string = getContactSearchRenderKey(contact, 'updated')

      expect(initialKey).assertEqual(stableKey)
      expect(initialKey === updatedNameKey).assertFalse()
      expect(updatedNameKey === updatedKeywordKey).assertFalse()
    })

    it('should_keep_highlight_presentation_separate_from_filtering', 0, () => {
      const member = new TeamMemberWithUser(
        new MockTeamMember() as V2NIMTeamMember,
        new MockFriend() as V2NIMFriend,
        new MockUser() as V2NIMUser
      )

      expect(resolveTeamMemberSearchTextPresentation(member, '好友').primaryMatched).assertTrue()
      expect(resolveTeamMemberSearchTextPresentation(member, 'alpha').secondaryText).assertEqual('User Alpha')
      expect(resolveTeamMemberSearchTextPresentation(member, 'account_abc').secondaryText)
        .assertEqual('account_abc')
      expect(resolveContactSearchTextPresentation(new NEUserWithFriend({
        friend: new MockFriend() as V2NIMFriend,
        user: new MockUser() as V2NIMUser
      }), 'account_abc').secondaryText).assertEqual('account_abc')
    })
  })
}
