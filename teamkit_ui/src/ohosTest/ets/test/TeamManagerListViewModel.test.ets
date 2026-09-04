/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMTeamMember, V2NIMTeamMemberRole } from '@nimsdk/base';
import { TeamMemberWithUser } from '@nimkit/chatkit';
import { TeamMangerListViewModel } from '../../../main/ets/viewModel/TeamManagerListViewModel';

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
}

function createMember(accountId: string, memberRole: V2NIMTeamMemberRole, joinTime: number): TeamMemberWithUser {
  let data = new MockTeamMemberData()
  data.accountId = accountId
  data.memberRole = memberRole
  data.joinTime = joinTime
  return new TeamMemberWithUser(data as V2NIMTeamMember, undefined, undefined)
}

/**
 * 管理员列表 ViewModel 纯逻辑测试
 *
 * 测试范围：
 * - needFillNextPage 分页判断
 * - appendManagerList 追加并排序（过滤群主和重复项）
 * - removeManagersFromList 按 ID 移除
 */
export default function teamManagerListViewModelTest() {
  describe('TeamManagerListViewModel_needFillNextPage', () => {
    /**
     * 默认值：isFinish=false, managerList=[], teamMemberLimit=100
     * 期望：true（未结束且列表未满）
     */
    it('should_need_fill_when_not_finished_and_list_below_limit', 0, () => {
      let vm = new TeamMangerListViewModel()
      expect(vm.needFillNextPage()).assertTrue()
    })

    /**
     * 分页已完成：不应再填充
     */
    it('should_not_need_fill_when_finished', 0, () => {
      let vm = new TeamMangerListViewModel()
      vm.isFinish = true
      expect(vm.needFillNextPage()).assertFalse()
    })

    /**
     * 列表已达到 limit：不应再填充
     */
    it('should_not_need_fill_when_list_reaches_limit', 0, () => {
      let vm = new TeamMangerListViewModel()
      vm.teamMemberLimit = 3
      vm.managerList = [
        createMember("u1", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100),
        createMember("u2", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 200),
        createMember("u3", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 300)
      ]
      expect(vm.needFillNextPage()).assertFalse()
    })

    /**
     * 列表超过 limit：不应再填充
     */
    it('should_not_need_fill_when_list_exceeds_limit', 0, () => {
      let vm = new TeamMangerListViewModel()
      vm.teamMemberLimit = 2
      vm.managerList = [
        createMember("u1", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100),
        createMember("u2", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 200),
        createMember("u3", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 300)
      ]
      expect(vm.needFillNextPage()).assertFalse()
    })

    /**
     * 已完成且列表为空：不应填充
     */
    it('should_not_need_fill_when_finished_and_empty', 0, () => {
      let vm = new TeamMangerListViewModel()
      vm.isFinish = true
      vm.managerList = []
      expect(vm.needFillNextPage()).assertFalse()
    })
  })

  describe('TeamManagerListViewModel_appendManagerList', () => {
    /**
     * 追加新管理员，应过滤掉群主
     */
    it('should_filter_out_owner', 0, () => {
      let vm = new TeamMangerListViewModel()

      let owner = createMember("owner", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, 100)
      let mgr = createMember("mgr", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 200)

      vm.appendManagerList([owner, mgr])
      expect(vm.managerList.length).assertEqual(1)
      expect(vm.managerList[0].getAccId()).assertEqual("mgr")
    })

    /**
     * 追加重复管理员，应去重
     */
    it('should_deduplicate_existing_managers', 0, () => {
      let vm = new TeamMangerListViewModel()

      let existing = createMember("mgr_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100)
      vm.managerList = [existing]

      let member = createMember("mgr_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 200)
      vm.appendManagerList([member])
      expect(vm.managerList.length).assertEqual(1)
    })

    /**
     * 追加空列表无影响
     */
    it('should_handle_empty_input', 0, () => {
      let vm = new TeamMangerListViewModel()

      let existing = createMember("mgr_a", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100)
      vm.managerList = [existing]

      vm.appendManagerList([])
      expect(vm.managerList.length).assertEqual(1)
    })

    /**
     * 追加后自动按优先级排序：群主 > 管理员(joinTime)
     * 注意：appendManagerList 已过滤群主，这里验证管理员按 joinTime 排序
     */
    it('should_sort_by_join_time_after_append', 0, () => {
      let vm = new TeamMangerListViewModel()

      let mgrLate = createMember("mgr_late", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 300)
      let mgrEarly = createMember("mgr_early", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100)

      vm.appendManagerList([mgrLate, mgrEarly])
      expect(vm.managerList.length).assertEqual(2)
      expect(vm.managerList[0].getAccId()).assertEqual("mgr_early")
      expect(vm.managerList[1].getAccId()).assertEqual("mgr_late")
    })

    /**
     * 全部是群主，追加后列表为空
     */
    it('should_have_empty_list_when_all_owners', 0, () => {
      let vm = new TeamMangerListViewModel()

      let owner1 = createMember("owner1", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, 100)
      let owner2 = createMember("owner2", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER, 200)

      vm.appendManagerList([owner1, owner2])
      expect(vm.managerList.length).assertEqual(0)
    })
  })

  describe('TeamManagerListViewModel_removeManagersFromList', () => {
    /**
     * 移除指定的管理员
     */
    it('should_remove_specified_members', 0, () => {
      let vm = new TeamMangerListViewModel()
      vm.isFinish = true // 避免触发自动加载
      vm.managerList = [
        createMember("u1", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100),
        createMember("u2", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 200),
        createMember("u3", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 300)
      ]

      vm.removeManagersFromList(["u1", "u3"])
      expect(vm.managerList.length).assertEqual(1)
      expect(vm.managerList[0].getAccId()).assertEqual("u2")
    })

    /**
     * 移除不存在的 ID，列表不变
     */
    it('should_not_change_list_when_ids_not_found', 0, () => {
      let vm = new TeamMangerListViewModel()
      vm.isFinish = true
      vm.managerList = [
        createMember("u1", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100)
      ]

      vm.removeManagersFromList(["nonexistent"])
      expect(vm.managerList.length).assertEqual(1)
      expect(vm.managerList[0].getAccId()).assertEqual("u1")
    })

    /**
     * 移除空列表无影响
     */
    it('should_handle_empty_remove_ids', 0, () => {
      let vm = new TeamMangerListViewModel()
      vm.isFinish = true
      vm.managerList = [
        createMember("u1", V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER, 100)
      ]

      vm.removeManagersFromList([])
      expect(vm.managerList.length).assertEqual(1)
    })
  })
}
