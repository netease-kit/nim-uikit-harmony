/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMTeamAgreeMode, V2NIMTeamJoinMode, V2NIMTeamUpdateExtensionMode } from '@nimsdk/base';
import {
  getAgreeModeByToggleState,
  getAgreeModeToggleState,
  getJoinModeByToggleState,
  getJoinModeToggleState,
  getTopStickyUpdateExtensionMode
} from '../../../main/ets/viewModel/TeamManageViewModel';
const TYPE_EXTENSION_ALLOW_ALL = 'all'
const TYPE_EXTENSION_ALLOW_MANAGER = 'manager'

// 本地副本：避免跨模块导入 '../../../chatkit/src/main/ets/utils/TopStickyPermissionUtils'
const KEY_EXTENSION_TOP_STICKY = 'yxAllowTop'
const DISCUSSION_TEAM_KEY = 'im_ui_kit_group'

function localGetTopStickyPermissionMode(serverExtension?: string): string {
  let isDiscussionTeam = false
  if (serverExtension && serverExtension.length > 0) {
    try {
      let extObj: Record<string, Object> = JSON.parse(serverExtension) as Record<string, Object>
      if (extObj[DISCUSSION_TEAM_KEY] === true) {
        isDiscussionTeam = true
      }
    } catch (_e) {
      // ignore
    }
  }
  let permissionMode = isDiscussionTeam ? TYPE_EXTENSION_ALLOW_ALL : TYPE_EXTENSION_ALLOW_MANAGER
  if (!serverExtension || serverExtension.length === 0) {
    return permissionMode
  }
  try {
    let extObj: Record<string, Object> = JSON.parse(serverExtension) as Record<string, Object>
    let permission: string = extObj[KEY_EXTENSION_TOP_STICKY] as string
    if (typeof permission === 'string' && permission.length > 0) {
      permissionMode = permission
    }
  } catch (_e) {
    return permissionMode
  }
  return permissionMode
}

/**
 * 进群管理冒烟测试
 *
 * 验证内容：
 * - JM-001: 新建群聊默认进群管理权限
 * - JM-002: 入群邀请需同意开关逻辑
 * - JM-003: 入群审核开关逻辑
 *
 * 注：由于单元测试环境无法直接导入 IMKitConfigCenter，
 * 这里验证的是开关切换的逻辑正确性和枚举值映射关系。
 */
export default function teamJoinManageTest() {
  describe('TeamJoinManage_DefaultSettings', () => {
    /**
     * JM-001: 验证默认值常量定义
     *
     * 冒烟用例：创建高级群时，默认 joinMode=FREE, agreeMode=NO_AUTH
     */
    it('should_verify_default_join_mode_constant', 0, () => {
      // 验证 SDK 枚举值存在且可用
      const freeMode = V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_FREE;
      expect(freeMode).assertEqual(0);  // FREE 对应枚举值 0
    });

    it('should_verify_default_agree_mode_constant', 0, () => {
      // 验证 SDK 枚举值存在且可用
      const noAuthMode = V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_NO_AUTH;
      expect(noAuthMode).assertEqual(1);  // NO_AUTH 对应枚举值 1
    });
  });

  describe('TeamJoinManage_AgreeModeSwitchLogic', () => {
    /**
     * JM-002: 验证入群邀请需同意开关的参数生成逻辑
     */
    it('should_return_auth_mode_when_switch_on', 0, () => {
      // Given: 用户打开入群邀请需同意开关
      const isOn = true;

      // When: 计算新的 agreeMode 值（与 TeamManagePage.ets:436-437 逻辑一致）
      const newAgreeMode = getAgreeModeByToggleState(isOn);

      // Then: 应该返回需要验证的模式
      expect(newAgreeMode).assertEqual(V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_AUTH);
    });

    it('should_return_no_auth_mode_when_switch_off', 0, () => {
      // Given: 用户关闭入群邀请需同意开关
      const isOn = false;

      // When: 计算新的 agreeMode 值
      const newAgreeMode = getAgreeModeByToggleState(isOn);

      // Then: 应该返回不需要验证的模式
      expect(newAgreeMode).assertEqual(V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_NO_AUTH);
    });
  });

  describe('TeamJoinManage_JoinModeSwitchLogic', () => {
    /**
     * JM-003: 验证入群审核开关的参数生成逻辑
     */
    it('should_return_apply_mode_when_switch_on', 0, () => {
      // Given: 用户打开入群审核开关
      const isOn = true;

      // When: 计算新的 joinMode 值（与 TeamManagePage.ets:486-487 逻辑一致）
      const newJoinMode = getJoinModeByToggleState(isOn);

      // Then: 应该返回需要申请的模式
      expect(newJoinMode).assertEqual(V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_APPLY);
    });

    it('should_return_free_mode_when_switch_off', 0, () => {
      // Given: 用户关闭入群审核开关
      const isOn = false;

      // When: 计算新的 joinMode 值
      const newJoinMode = getJoinModeByToggleState(isOn);

      // Then: 应该返回自由加入的模式
      expect(newJoinMode).assertEqual(V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_FREE);
    });
  });

  describe('TeamJoinManage_ToggleStateMapping', () => {
    /**
     * 验证 Toggle 组件的 isOn 状态与 SDK 枚举值的映射关系
     *
     * TeamManagePage 中的逻辑：
     * - agreeMode Toggle: isOn = (agreeMode === V2NIM_TEAM_AGREE_MODE_AUTH)
     * - joinMode Toggle: isOn = (joinMode !== V2NIM_TEAM_JOIN_MODE_FREE)
     */
    it('should_map_agree_mode_auth_to_toggle_on', 0, () => {
      // Given: agreeMode 为需要验证
      const agreeMode = V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_AUTH;

      // When: 计算 Toggle 的 isOn 状态（与 TeamManagePage.ets:430 逻辑一致）
      const isOn = getAgreeModeToggleState(agreeMode);

      // Then: Toggle 应该显示为开启状态
      expect(isOn).assertTrue();
    });

    it('should_map_join_mode_free_to_toggle_off', 0, () => {
      // Given: joinMode 为自由加入
      const joinMode = V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_FREE;

      // When: 计算 Toggle 的 isOn 状态
      const isOn = getJoinModeToggleState(joinMode);

      // Then: Toggle 应该显示为关闭状态
      expect(isOn).assertFalse();
    });

    it('should_map_no_auth_to_toggle_off', 0, () => {
      expect(getAgreeModeToggleState(V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_NO_AUTH)).assertFalse();
    });

    it('should_map_apply_mode_to_toggle_on', 0, () => {
      expect(getJoinModeToggleState(V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_APPLY)).assertTrue();
    });

    it('should_map_invite_mode_to_toggle_on', 0, () => {
      expect(getJoinModeToggleState(V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_INVITE)).assertTrue();
    });

    it('should_toggle_off_when_agree_mode_undefined', 0, () => {
      expect(getAgreeModeToggleState(undefined)).assertFalse();
    });

    it('should_toggle_off_when_join_mode_undefined', 0, () => {
      expect(getJoinModeToggleState(undefined)).assertFalse();
    });
  });

  describe('TeamJoinManage_TopStickyPermission', () => {
    it('should_default_to_manager_for_advanced_team', 0, () => {
      expect(localGetTopStickyPermissionMode('{}')).assertEqual(TYPE_EXTENSION_ALLOW_MANAGER);
    });

    it('should_default_to_all_for_discussion_team', 0, () => {
      expect(localGetTopStickyPermissionMode('{"im_ui_kit_group":true}')).assertEqual(TYPE_EXTENSION_ALLOW_ALL);
    });

    it('should_return_all_when_top_sticky_permission_is_explicitly_all', 0, () => {
      expect(localGetTopStickyPermissionMode('{"yxAllowTop":"all"}')).assertEqual(TYPE_EXTENSION_ALLOW_ALL);
    });

    it('should_return_manager_when_top_sticky_permission_is_explicitly_manager', 0, () => {
      expect(localGetTopStickyPermissionMode('{"im_ui_kit_group":true,"yxAllowTop":"manager"}'))
        .assertEqual(TYPE_EXTENSION_ALLOW_MANAGER);
    });

    it('should_allow_all_members_to_update_extension_when_top_sticky_permission_is_all', 0, () => {
      expect(getTopStickyUpdateExtensionMode(TYPE_EXTENSION_ALLOW_ALL))
        .assertEqual(V2NIMTeamUpdateExtensionMode.V2NIM_TEAM_UPDATE_EXTENSION_MODE_ALL);
    });

    it('should_only_allow_managers_to_update_extension_when_top_sticky_permission_is_manager', 0, () => {
      expect(getTopStickyUpdateExtensionMode(TYPE_EXTENSION_ALLOW_MANAGER))
        .assertEqual(V2NIMTeamUpdateExtensionMode.V2NIM_TEAM_UPDATE_EXTENSION_MODE_MANAGER);
    });
  });
}
