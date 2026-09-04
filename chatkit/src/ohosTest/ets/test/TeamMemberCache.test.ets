/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { V2NIMTeam, V2NIMTeamMember, V2NIMTeamMemberRole } from '@nimsdk/base'
import { TeamMemberCache } from '../../../main/ets/cache/TeamMemberCache'
import { TeamMemberWithUser } from '../../../main/ets/model/TeamMemberWithUser'

class MockTeam {
  teamId: string = ''
  memberCount: number = 0
}

class MockTeamMember {
  teamId: string = ''
  accountId: string = ''
  memberRole: V2NIMTeamMemberRole = V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
  joinTime: number = 0
}

function createTeam(teamId: string, memberCount: number = 0): V2NIMTeam {
  const team = new MockTeam()
  team.teamId = teamId
  team.memberCount = memberCount
  return team as V2NIMTeam
}

function createMember(teamId: string, accountId: string): TeamMemberWithUser {
  const member = new MockTeamMember()
  member.teamId = teamId
  member.accountId = accountId
  return new TeamMemberWithUser(member as V2NIMTeamMember)
}

export default function teamMemberCacheTest() {
  describe('TeamMemberCache_active_team', () => {
    it('should_reset_member_and_paging_state_when_team_changes', 0, () => {
      const cache = TeamMemberCache.getInstance()
      cache.clear()
      cache.intTeamInfo('team_a', createTeam('team_a'))
      cache.membersMap.set('user_a', createMember('team_a', 'user_a'))
      cache.nextToken = 'team_a_token'
      cache.isFinish = true

      cache.intTeamInfo('team_b', createTeam('team_b'))

      expect(cache.teamId).assertEqual('team_b')
      expect(cache.membersMap.size).assertEqual(0)
      expect(cache.nextToken).assertEqual('')
      expect(cache.isFinish).assertFalse()
      expect(cache.team?.teamId).assertEqual('team_b')
      cache.clear()
    })

    it('should_not_report_complete_when_cached_count_is_less_than_team_count', 0, () => {
      const cache = TeamMemberCache.getInstance()
      cache.clear()
      cache.intTeamInfo('team_a', createTeam('team_a', 2))
      cache.membersMap.set('user_a', createMember('team_a', 'user_a'))
      cache.isFinish = true

      expect(cache.haveLoadAllMember('team_a')).assertFalse()
      cache.clear()
    })

    it('should_not_return_active_team_data_for_stale_team_read', 0, async () => {
      const cache = TeamMemberCache.getInstance()
      cache.clear()
      cache.intTeamInfo('team_a', createTeam('team_a', 1))
      cache.mineTeamMember = createMember('team_a', 'mine_a').teamMember

      cache.intTeamInfo('team_b', createTeam('team_b', 1))
      cache.mineTeamMember = createMember('team_b', 'mine_b').teamMember

      expect(await cache.getTeam('team_a') === undefined).assertTrue()
      expect(await cache.getMineMember('team_a') === undefined).assertTrue()
      expect(cache.getAllMembers('team_a').length).assertEqual(0)
      expect(cache.teamId).assertEqual('team_b')
      expect(cache.mineTeamMember?.accountId).assertEqual('mine_b')
      cache.clear()
    })

    it('should_reset_paging_state_when_member_left_after_full_load', 0, () => {
      const cache = TeamMemberCache.getInstance()
      cache.clear()
      cache.intTeamInfo('team_a', createTeam('team_a', 2))
      cache.membersMap.set('user_a', createMember('team_a', 'user_a'))
      cache.membersMap.set('user_b', createMember('team_a', 'user_b'))
      cache.nextToken = 'finished_token'
      cache.isFinish = true

      cache.onTeamMemberLeft([createMember('team_a', 'user_b').teamMember])

      expect(cache.membersMap.has('user_b')).assertFalse()
      expect(cache.isFinish).assertFalse()
      expect(cache.nextToken).assertEqual('')
      expect(cache.needFetchMember('team_a')).assertTrue()
      cache.clear()
    })

    it('should_reset_paging_state_when_member_kicked_after_full_load', 0, () => {
      const cache = TeamMemberCache.getInstance()
      cache.clear()
      cache.intTeamInfo('team_a', createTeam('team_a', 2))
      cache.membersMap.set('user_a', createMember('team_a', 'user_a'))
      cache.membersMap.set('user_b', createMember('team_a', 'user_b'))
      cache.nextToken = 'finished_token'
      cache.isFinish = true

      cache.onTeamMemberKicked('operator', [createMember('team_a', 'user_b').teamMember])

      expect(cache.membersMap.has('user_b')).assertFalse()
      expect(cache.isFinish).assertFalse()
      expect(cache.nextToken).assertEqual('')
      expect(cache.needFetchMember('team_a')).assertTrue()
      cache.clear()
    })
  })
}
