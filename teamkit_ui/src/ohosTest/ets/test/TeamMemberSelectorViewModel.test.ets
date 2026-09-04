/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMFriend, V2NIMTeamMember, V2NIMTeamMemberRole, V2NIMUser } from '@nimsdk/base';
import { TeamMemberCache, TeamMemberSelectorMode, TeamMemberWithUser } from '@nimkit/chatkit';
import { TeamMemberSelectorViewModel } from '../../../main/ets/viewModel/TeamMemberSelectorViewModel';

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
  accountId: string = ''
  alias?: string = undefined
}

class MockUserData {
  accountId: string = ''
  name?: string = undefined
}

function createMember(accountId: string, memberRole: V2NIMTeamMemberRole, teamNick?: string): TeamMemberWithUser {
  let data = new MockTeamMemberData()
  data.accountId = accountId
  data.memberRole = memberRole
  data.teamNick = teamNick
  return new TeamMemberWithUser(data as V2NIMTeamMember, undefined, undefined)
}

/**
 * 群成员选择器 ViewModel 纯逻辑测试
 *
 * 测试范围：
 * - showManager / needNetwork 计算属性
 * - onMemberItemClick 选择状态机（单选/多选）
 * - getDisplayList 分发逻辑
 * - searchTeamMembers 本地筛选
 * - clearSearch / clearSelectedMembers 状态重置
 */
export default function teamMemberSelectorViewModelTest() {
  describe('TeamMemberSelectorViewModel_properties', () => {
    /**
     * showManager 取决于 mode
     */
    it('should_show_manager_when_fts_search_mode', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      expect(vm.showManager).assertTrue()
    })

    it('should_not_show_manager_when_add_manager_mode', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.ADD_MANAGER
      expect(vm.showManager).assertFalse()
    })

    /**
     * needNetwork 取决于 mode
     */
    it('should_need_network_when_add_manager_mode', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.ADD_MANAGER
      expect(vm.needNetwork).assertTrue()
    })

    it('should_not_need_network_when_fts_search_mode', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      expect(vm.needNetwork).assertFalse()
    })
  })

  describe('TeamMemberSelectorViewModel_onMemberItemClick', () => {
    /**
     * 单选模式 (selectLimit == 1): 点击选中，再次点击取消
     */
    it('should_select_single_member_when_limit_is_1', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.selectLimit = 1

      vm.onMemberItemClick("user_a")
      expect(vm.selectedMembers.has("user_a")).assertTrue()
      expect(vm.selectedCount).assertEqual(1)

      // 点击另一个，应该切换
      vm.onMemberItemClick("user_b")
      expect(vm.selectedMembers.has("user_a")).assertFalse()
      expect(vm.selectedMembers.has("user_b")).assertTrue()
      expect(vm.selectedCount).assertEqual(1)

      // 再次点击同一个，取消选中
      vm.onMemberItemClick("user_b")
      expect(vm.selectedMembers.has("user_b")).assertFalse()
      expect(vm.selectedCount).assertEqual(0)
    })

    /**
     * 多选模式 (selectLimit > 1): 点击选中，再次点击取消，可多个选中
     */
    it('should_toggle_multi_select_when_limit_gt_1', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.selectLimit = 5

      vm.onMemberItemClick("user_a")
      expect(vm.selectedMembers.has("user_a")).assertTrue()
      expect(vm.selectedCount).assertEqual(1)

      vm.onMemberItemClick("user_b")
      expect(vm.selectedMembers.has("user_a")).assertTrue()
      expect(vm.selectedMembers.has("user_b")).assertTrue()
      expect(vm.selectedCount).assertEqual(2)

      // 取消 user_a
      vm.onMemberItemClick("user_a")
      expect(vm.selectedMembers.has("user_a")).assertFalse()
      expect(vm.selectedMembers.has("user_b")).assertTrue()
      expect(vm.selectedCount).assertEqual(1)
    })

    /**
     * 单选模式，已有选中再点同一个取消
     */
    it('should_deselect_when_click_selected_single', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.selectLimit = 1
      vm.selectedMembers.add("user_x")
      vm.selectedCount = 1

      vm.onMemberItemClick("user_x")
      expect(vm.selectedMembers.has("user_x")).assertFalse()
      expect(vm.selectedCount).assertEqual(0)
    })
  })

  describe('TeamMemberSelectorViewModel_getDisplayList', () => {
    it('should_return_search_result_list_when_searching', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.searchKeyword = "test"

      let a = createMember("user_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)
      vm.searchResultList = [a]

      let result = vm.getDisplayList()
      expect(result.length).assertEqual(1)
      expect(result[0].getAccId()).assertEqual("user_a")
    })

    it('should_return_member_list_when_not_searching', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.searchKeyword = ""

      let a = createMember("user_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)
      vm.memberList = [a]

      let result = vm.getDisplayList()
      expect(result.length).assertEqual(1)
      expect(result[0].getAccId()).assertEqual("user_a")
    })

    it('should_return_member_list_when_keyword_only_spaces', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      let a = createMember("user_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)
      vm.memberList = [a]

      await vm.searchTeamMembers("   ")

      let result = vm.getDisplayList()
      expect(vm.searchKeyword).assertEqual("")
      expect(result.length).assertEqual(1)
    })
  })

  describe('TeamMemberSelectorViewModel_getMemberRenderKey', () => {
    it('should_change_member_render_key_when_search_keyword_changes', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      let member = createMember("user_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, "群昵称8")

      const initialKey = vm.getMemberRenderKey(member)
      vm.searchKeyword = "8"
      const searchKey = vm.getMemberRenderKey(member)
      const stableSearchKey = vm.getMemberRenderKey(member)

      expect(initialKey === searchKey).assertFalse()
      expect(searchKey).assertEqual(stableSearchKey)
    })

    it('should_change_member_render_key_when_member_name_changes', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.searchKeyword = "8"
      let member = createMember("user_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, "群昵称8")
      let updatedMember = createMember(
        "user_a",
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL,
        "新群昵称8"
      )

      const searchKey = vm.getMemberRenderKey(member)
      const updatedProfileKey = vm.getMemberRenderKey(updatedMember)

      expect(searchKey === updatedProfileKey).assertFalse()
    })
  })

  describe('TeamMemberSelectorViewModel_searchTeamMembers', () => {
    it('should_search_all_cached_members_before_they_are_revealed_by_paging', 0, async () => {
      const cache = TeamMemberCache.getInstance()
      cache.clear()
      cache.intTeamInfo('test_team')
      cache.membersMap.set('visible_user',
        createMember('visible_user', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL))
      cache.membersMap.set('HiddenAccount101',
        createMember('HiddenAccount101', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL))
      cache.isFinish = true

      let vm = new TeamMemberSelectorViewModel()
      vm.teamId = 'test_team'
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      vm.memberList = [createMember('visible_user', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)]

      await vm.searchTeamMembers('hiddenaccount101')

      expect(vm.searchResultList.length).assertEqual(1)
      expect(vm.searchResultList[0].getAccId()).assertEqual('HiddenAccount101')
      cache.clear()
    })

    /**
     * 空 keyword：清空搜索结果（空字符串和 falsy 值走同一分支）
     */
    it('should_clear_search_when_keyword_empty', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.searchResultList = [createMember("stale", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)]
      vm.isSearching = true

      await vm.searchTeamMembers("")
      expect(vm.searchResultList.length).assertEqual(0)
      expect(vm.isSearching).assertFalse()
    })

    it('should_match_account_id_in_fts_search_mode', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      vm.memberList = [createMember("HelloWorld", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER)]

      await vm.searchTeamMembers("hello")
      expect(vm.searchResultList.length).assertEqual(1)
      expect(vm.searchResultList[0].getAccId()).assertEqual("HelloWorld")
    })

    it('should_match_account_id_and_keep_role_filter_in_add_manager_mode', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.ADD_MANAGER
      vm.memberList = [
        createMember("NormalAccount", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL),
        createMember("OwnerAccount", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER)
      ]

      await vm.searchTeamMembers("account")
      expect(vm.searchResultList.length).assertEqual(1)
      expect(vm.searchResultList[0].getAccId()).assertEqual("NormalAccount")
    })

    /**
     * 无关 accountId 不匹配
     */
    it('should_not_match_irrelevant_account_id', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      vm.memberList = [createMember("abc", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)]

      await vm.searchTeamMembers("xyz")
      expect(vm.searchResultList.length).assertEqual(0)
    })

    /**
     * 按 teamNick (群昵称) 匹配
     */
    it('should_match_by_team_nick', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH

      let m = createMember("user_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, "张三")
      vm.memberList = [m]

      await vm.searchTeamMembers("张")
      expect(vm.searchResultList.length).assertEqual(1)
    })

    /**
     * 不显示管理员模式：过滤掉管理员和群主
     */
    it('should_filter_out_manager_and_owner_when_not_show_manager', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.ADD_MANAGER

      let normal = createMember("normal_u", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, "尼克")
      let owner = createMember("owner_u", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, "尼克")
      let manager = createMember("mgr_u", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, "尼克")
      vm.memberList = [normal, owner, manager]

      await vm.searchTeamMembers("尼克")
      expect(vm.searchResultList.length).assertEqual(1)
      expect(vm.searchResultList[0].getAccId()).assertEqual("normal_u")
    })

    /**
     * 显示管理员模式：保留管理员和群主
     */
    it('should_include_manager_and_owner_when_show_manager', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH

      let normal = createMember("normal_u", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, "测试")
      let owner = createMember("owner_u", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, "测试")
      let manager = createMember("mgr_u", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, "测试")
      vm.memberList = [normal, owner, manager]

      await vm.searchTeamMembers("测试")
      expect(vm.searchResultList.length).assertEqual(3)
    })

    /**
     * 搜索无匹配
     */
    it('should_return_empty_when_no_match', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      vm.memberList = [createMember("u1", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, "张三")]

      await vm.searchTeamMembers("nonexistent")
      expect(vm.searchResultList.length).assertEqual(0)
    })

    it('should_keep_selected_members_when_searching_and_clearing_search', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      vm.memberList = [createMember("user_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL, "张三")]
      vm.onMemberItemClick("user_a")

      await vm.searchTeamMembers("张")
      vm.clearSearch()

      expect(vm.selectedMembers.has("user_a")).assertTrue()
      expect(vm.selectedCount).assertEqual(1)
    })

    it('should_recalculate_active_search_when_user_name_changes', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      let member = createMember('user_a', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)
      let oldUser = new MockUserData()
      oldUser.accountId = 'user_a'
      oldUser.name = '旧名称'
      member.userInfo = oldUser as V2NIMUser
      vm.memberList = [member]

      await vm.searchTeamMembers('新名称')
      expect(vm.searchResultList.length).assertEqual(0)

      let updatedUser = new MockUserData()
      updatedUser.accountId = 'user_a'
      updatedUser.name = '新名称'
      vm.onUserProfileChanged([updatedUser as V2NIMUser])

      expect(vm.searchResultList.length).assertEqual(1)
      expect(vm.searchResultList[0].getAccId()).assertEqual('user_a')
    })

    it('should_recalculate_active_search_when_friend_alias_changes', 0, async () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.mode = TeamMemberSelectorMode.ADD_MANAGER
      let member = createMember('user_a', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)
      vm.memberList = [member]

      await vm.searchTeamMembers('新备注')
      expect(vm.searchResultList.length).assertEqual(0)

      let updatedFriend = new MockFriendData()
      updatedFriend.accountId = 'user_a'
      updatedFriend.alias = '新备注'
      vm.onFriendInfoChanged(updatedFriend as V2NIMFriend)

      expect(vm.searchResultList.length).assertEqual(1)
      expect(vm.selectedMembers.size).assertEqual(0)
    })

    it('should_keep_manager_visible_after_profile_update_in_fts_mode', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.teamId = 'test_team'
      vm.mode = TeamMemberSelectorMode.FTS_SEARCH
      let manager = createMember('manager', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, '旧群昵称')
      vm.memberList = [manager]

      let updatedMember = new MockTeamMemberData()
      updatedMember.accountId = 'manager'
      updatedMember.memberRole = V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
      updatedMember.teamNick = '新群昵称'
      vm.onTeamMemberInfoUpdated([updatedMember as V2NIMTeamMember])

      expect(vm.memberList.length).assertEqual(1)
      expect(vm.memberList[0].teamMember.teamNick).assertEqual('新群昵称')
    })
  })

  describe('TeamMemberSelectorViewModel_clearSearch', () => {
    it('should_reset_search_state', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.searchKeyword = "test"
      vm.searchResultList = [createMember("u1", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)]
      vm.isSearching = true

      vm.clearSearch()
      expect(vm.searchKeyword).assertEqual("")
      expect(vm.searchResultList.length).assertEqual(0)
      expect(vm.isSearching).assertFalse()
    })
  })

  describe('TeamMemberSelectorViewModel_clearSelectedMembers', () => {
    it('should_clear_all_selections', 0, () => {
      let vm = new TeamMemberSelectorViewModel()
      vm.selectedMembers.add("a")
      vm.selectedMembers.add("b")
      vm.selectedCount = 2

      vm.clearSelectedMembers()
      expect(vm.selectedMembers.size).assertEqual(0)
      expect(vm.selectedCount).assertEqual(0)
    })
  })
}
