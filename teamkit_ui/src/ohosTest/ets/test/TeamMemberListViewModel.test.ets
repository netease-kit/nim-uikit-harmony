/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMTeamMemberRole } from '@nimsdk/base';
import { TeamMemberWithUser } from '@nimkit/chatkit';
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
}

function createMember(accountId: string, memberRole: V2NIMTeamMemberRole, joinTime: number): TeamMemberWithUser {
  let data = new MockTeamMemberData()
  data.accountId = accountId
  data.memberRole = memberRole
  data.joinTime = joinTime
  return new TeamMemberWithUser(data as V2NIMTeamMember, undefined, undefined)
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
}
