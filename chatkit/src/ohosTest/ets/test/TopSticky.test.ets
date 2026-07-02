/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  isDiscussionTeamByServerExtension,
  getTopStickyPermissionMode,
  hasTopStickyPermission
} from '../../../main/ets/utils/TopStickyPermissionUtils';
import { V2NIMTeamMemberRole } from '@nimsdk/base';

export default function TopStickyTest() {
  describe('isDiscussionTeamByServerExtension', () => {
    it('should_return_false_for_undefined', 0, () => {
      expect(isDiscussionTeamByServerExtension(undefined)).assertFalse();
    });
    it('should_return_false_for_empty', 0, () => {
      expect(isDiscussionTeamByServerExtension('')).assertFalse();
    });
    it('should_return_true_for_discussion_group', 0, () => {
      expect(isDiscussionTeamByServerExtension('{"im_ui_kit_group":true}')).assertTrue();
    });
    it('should_return_false_for_normal_team', 0, () => {
      expect(isDiscussionTeamByServerExtension('{"other":1}')).assertFalse();
    });
    it('should_return_false_for_invalid_json', 0, () => {
      expect(isDiscussionTeamByServerExtension('{invalid}')).assertFalse();
    });
  });

  describe('getTopStickyPermissionMode', () => {
    it('should_return_all_for_discussion_team', 0, () => {
      const mode: string = getTopStickyPermissionMode('{"im_ui_kit_group":true}', true);
      expect(mode).assertEqual('all');
    });
    it('should_return_manager_for_normal_team', 0, () => {
      const mode: string = getTopStickyPermissionMode('{}', false);
      expect(mode).assertEqual('manager');
    });
    it('should_return_all_when_yxAllowTop_is_all', 0, () => {
      const mode: string = getTopStickyPermissionMode('{"yxAllowTop":"all"}');
      expect(mode).assertEqual('all');
    });
    it('should_return_custom_when_yxAllowTop_is_manager', 0, () => {
      const mode: string = getTopStickyPermissionMode('{"yxAllowTop":"manager"}');
      expect(mode).assertEqual('manager');
    });
    it('should_default_for_empty_extension', 0, () => {
      const mode: string = getTopStickyPermissionMode(undefined);
      expect(mode).assertEqual('manager');
    });
  });

  describe('hasTopStickyPermission', () => {
    it('should_return_true_for_all_mode_any_role', 0, () => {
      expect(hasTopStickyPermission('all', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)).assertTrue();
    });
    it('should_return_true_for_manager_role', 0, () => {
      expect(hasTopStickyPermission('manager', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER)).assertTrue();
      expect(hasTopStickyPermission('manager', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER)).assertTrue();
    });
    it('should_return_false_for_normal_role', 0, () => {
      expect(hasTopStickyPermission('manager', V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL)).assertFalse();
    });
    it('should_return_false_for_undefined_role', 0, () => {
      expect(hasTopStickyPermission('manager', undefined)).assertFalse();
    });
  });
}
