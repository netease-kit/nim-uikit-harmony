/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMFriend, V2NIMTeamMember, V2NIMTeamMemberRole, V2NIMUser } from '@nimsdk/base';
import { TeamMemberCache, TeamMemberWithUser } from '@nimkit/chatkit';
import { TeamMemberListViewModel } from '../../../main/ets/viewModel/TeamMemberListViewModel';

/**
 * TeamMemberWithUser 测试数据构造辅助类
 * ArkTS 约束：不能使用对象字面量，通过 class 实例化后逐字段赋值
 */
class MockTeamMemberData {
  accountId: string = ""
  memberRole: V2NIMTeamMemberRole = V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
  joinTime: number = 0
  teamId: string = "test_team"
  teamType: number = 0
  inTeam: boolean = true
  teamNick?: string = undefined
}

class MockFriendData {
  accountId: string = ""
  alias?: string = undefined
}

class MockUserData {
  accountId: string = ""
  name?: string = undefined
}

function createMember(
  accountId: string,
  memberRole: V2NIMTeamMemberRole,
  joinTime: number,
  teamNick?: string,
  alias?: string,
  userName?: string
): TeamMemberWithUser {
  let data = new MockTeamMemberData()
  data.accountId = accountId
  data.memberRole = memberRole
  data.joinTime = joinTime
  data.teamNick = teamNick

  let friend = new MockFriendData()
  friend.accountId = accountId
  friend.alias = alias

  let user = new MockUserData()
  user.accountId = accountId
  user.name = userName

  return new TeamMemberWithUser(
    data as V2NIMTeamMember,
    friend as V2NIMFriend,
    user as V2NIMUser
  )
}

/**
 * 群成员排序逻辑冒烟测试
 *
 * 排序规则：群主 > 管理员 > 普通成员，同角色按入群时间升序
 */
export default function teamMemberListViewModelTest() {
  describe('TeamMemberListViewModel_sortTeamMember', () => {
    let vm: TeamMemberListViewModel = new TeamMemberListViewModel()

    /**
     * 同角色 - 按 joinTime 升序
     */
    it('should_sort_by_join_time_when_same_role', 0, () => {
      let a = createMember("user_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, 200)
      let b = createMember("user_b", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, 100)
      expect(vm.sortTeamMember(a, b) > 0).assertTrue()
      expect(vm.sortTeamMember(b, a) < 0).assertTrue()
      expect(vm.sortTeamMember(a, a)).assertEqual(0)
    })

    /**
     * 群主按各种比较
     */
    it('should_place_owner_before_manager', 0, () => {
      let owner = createMember("owner", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, 200)
      let manager = createMember("manager", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100)
      expect(vm.sortTeamMember(owner, manager) < 0).assertTrue()
    })

    it('should_place_owner_before_normal', 0, () => {
      let owner = createMember("owner", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, 200)
      let normal = createMember("normal", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, 100)
      expect(vm.sortTeamMember(owner, normal) < 0).assertTrue()
    })

    it('should_place_manager_after_owner', 0, () => {
      let manager = createMember("manager", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100)
      let owner = createMember("owner", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, 200)
      expect(vm.sortTeamMember(manager, owner) > 0).assertTrue()
    })

    /**
     * 管理员 vs 普通成员
     */
    it('should_place_manager_before_normal', 0, () => {
      let manager = createMember("manager", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 200)
      let normal = createMember("normal", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, 100)
      expect(vm.sortTeamMember(manager, normal) < 0).assertTrue()
    })

    it('should_place_normal_after_manager', 0, () => {
      let normal = createMember("normal", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, 100)
      let manager = createMember("manager", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 200)
      expect(vm.sortTeamMember(normal, manager) > 0).assertTrue()
    })

    /**
     * 同角色群主按 joinTime 排序
     */
    it('should_sort_owners_by_join_time', 0, () => {
      let ownerA = createMember("owner_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, 200)
      let ownerB = createMember("owner_b", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, 100)
      expect(vm.sortTeamMember(ownerA, ownerB) > 0).assertTrue()
      expect(vm.sortTeamMember(ownerB, ownerA) < 0).assertTrue()
    })

    /**
     * 同角色管理员按 joinTime 排序
     */
    it('should_sort_managers_by_join_time', 0, () => {
      let mgrA = createMember("mgr_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 300)
      let mgrB = createMember("mgr_b", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100)
      expect(vm.sortTeamMember(mgrA, mgrB) > 0).assertTrue()
      expect(vm.sortTeamMember(mgrB, mgrA) < 0).assertTrue()
    })
  })

  describe('TeamMemberListViewModel_searchTeamMembers', () => {
    it('should_search_all_cached_members_before_they_are_revealed_by_paging', 0, async () => {
      const cache = TeamMemberCache.getInstance()
      cache.clear()
      cache.intTeamInfo('test_team')
      const visibleMember = createMember(
        'visible_user', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, 1)
      const hiddenMember = createMember(
        'HiddenAccount101', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, 101)
      cache.membersMap.set(visibleMember.getAccId(), visibleMember)
      cache.membersMap.set(hiddenMember.getAccId(), hiddenMember)
      cache.isFinish = true

      let vm = new TeamMemberListViewModel()
      vm.teamId = 'test_team'
      vm.memberList = [visibleMember]

      await vm.searchTeamMembers('hiddenaccount101')

      expect(vm.getDisplayList().length).assertEqual(1)
      expect(vm.getDisplayList()[0].getAccId()).assertEqual('HiddenAccount101')
      cache.clear()
    })

    it('should_match_alias_team_nick_user_name_and_account_id', 0, async () => {
      let vm = new TeamMemberListViewModel()
      let aliasMember = createMember(
        "alias_user",
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL,
        1,
        undefined,
        "好友备注"
      )
      let teamNickMember = createMember(
        "team_nick_user",
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL,
        2,
        "群昵称"
      )
      let userNameMember = createMember(
        "name_user",
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL,
        3,
        undefined,
        undefined,
        "用户名称"
      )
      let accountMember = createMember(
        "Account_130",
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL,
        4
      )
      vm.memberList = [aliasMember, teamNickMember, userNameMember, accountMember]

      await vm.searchTeamMembers("备注")
      expect(vm.getDisplayList()[0] === aliasMember).assertTrue()
      await vm.searchTeamMembers("群昵")
      expect(vm.getDisplayList()[0] === teamNickMember).assertTrue()
      await vm.searchTeamMembers("名称")
      expect(vm.getDisplayList()[0] === userNameMember).assertTrue()
      await vm.searchTeamMembers("account_130")
      expect(vm.getDisplayList()[0] === accountMember).assertTrue()
    })

    it('should_normalize_keyword_and_restore_full_list_when_cleared', 0, async () => {
      let vm = new TeamMemberListViewModel()
      let member = createMember("Account_130", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, 1)
      vm.memberList = [member]

      await vm.searchTeamMembers("  130  ")
      expect(vm.searchKeyword).assertEqual("130")
      expect(vm.getDisplayList().length).assertEqual(1)

      await vm.searchTeamMembers("   ")
      expect(vm.searchKeyword).assertEqual("")
      expect(vm.getDisplayList()[0] === member).assertTrue()
    })

    it('should_derive_search_result_from_latest_member_profile', 0, async () => {
      let vm = new TeamMemberListViewModel()
      let member = createMember(
        "user_a",
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL,
        1,
        undefined,
        "旧备注"
      )
      vm.memberList = [member]
      await vm.searchTeamMembers("新备注")
      expect(vm.getDisplayList().length).assertEqual(0)

      let friend = new MockFriendData()
      friend.accountId = "user_a"
      friend.alias = "新备注"
      member.friendInfo = friend as V2NIMFriend

      expect(vm.getDisplayList()[0] === member).assertTrue()
    })

    it('should_refresh_render_key_when_keyword_or_name_changes', 0, async () => {
      let vm = new TeamMemberListViewModel()
      let member = createMember(
        "130",
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL,
        1,
        "群昵称",
        "好友备注",
        "用户名称"
      )

      const initialKey = vm.getMemberRenderKey(member)
      await vm.searchTeamMembers("  1  ")
      const searchKey = vm.getMemberRenderKey(member)
      const stableSearchKey = vm.getMemberRenderKey(member)
      let updatedMember = createMember(
        "130",
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL,
        1,
        "群昵称",
        "新备注",
        "用户名称"
      )
      const updatedNameKey = vm.getMemberRenderKey(updatedMember)

      expect(initialKey === searchKey).assertFalse()
      expect(searchKey).assertEqual(stableSearchKey)
      expect(searchKey === updatedNameKey).assertFalse()
    })
  })
}
