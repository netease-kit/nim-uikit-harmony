/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMErrorCode, V2NIMTeamJoinActionStatus } from '@nimsdk/base';
import {
  refineTeamVerifyActionErrorResult,
  resolveTeamVerifyActionError,
  TeamVerifyActionErrorToastType
} from '../main/ets/viewmodel/TeamVerifyViewModel';

export default function teamVerifyViewModelTest() {
  describe('TeamVerifyViewModel_resolveTeamVerifyActionError', () => {
    it('should_map_team_member_limit_to_expired_and_member_limit_toast', 0, () => {
      const result = resolveTeamVerifyActionError(801,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.TEAM_MEMBER_LIMIT)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_map_joined_team_limit_to_joined_team_limit_toast_without_status_change', 0, () => {
      const result = resolveTeamVerifyActionError(V2NIMErrorCode.V2NIM_ERROR_CODE_JOINED_TEAM_LIMIT,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.JOINED_TEAM_LIMIT)
      expect(result.nextStatus).assertEqual(undefined)
    })

    it('should_map_already_in_team_error_to_expired_and_already_in_team_toast', 0, () => {
      const result = resolveTeamVerifyActionError(809,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.ALREADY_IN_TEAM)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_map_team_member_already_exist_error_to_expired_and_already_in_team_toast', 0, () => {
      const result = resolveTeamVerifyActionError(V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_MEMBER_ALREADY_EXIST,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.ALREADY_IN_TEAM)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_map_no_permission_error_to_expired_and_no_permission_toast', 0, () => {
      const result = resolveTeamVerifyActionError(802,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.NO_PERMISSION)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_map_team_not_exist_error_to_expired_and_team_not_exist_toast', 0, () => {
      const result = resolveTeamVerifyActionError(V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_NOT_EXIST,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.TEAM_NOT_EXIST)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_map_team_owner_permission_required_to_expired_and_no_permission_toast', 0, () => {
      const result = resolveTeamVerifyActionError(V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_OWNER_OPERATION_PERMISSION_REQUIRED,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.NO_PERMISSION)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_map_team_owner_or_manager_permission_required_to_expired_and_no_permission_toast', 0, () => {
      const result = resolveTeamVerifyActionError(
        V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_OWNER_OR_MANAGER_OPERATION_PERMISSION_REQUIRED,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.NO_PERMISSION)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_map_validate_processed_error_to_expired', 0, () => {
      const result = resolveTeamVerifyActionError(509,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.VALIDATE_PROCESSED)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_fallback_to_validate_processed_for_other_errors', 0, () => {
      const result = resolveTeamVerifyActionError(514,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.VALIDATE_PROCESSED)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_refine_validate_processed_to_already_in_team_when_target_has_joined', 0, () => {
      const baseResult = resolveTeamVerifyActionError(514,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)
      const result = refineTeamVerifyActionErrorResult(baseResult, { alreadyInTeam: true })

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.ALREADY_IN_TEAM)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_keep_validate_processed_when_target_is_not_in_team', 0, () => {
      const baseResult = resolveTeamVerifyActionError(514,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)
      const result = refineTeamVerifyActionErrorResult(baseResult, { alreadyInTeam: false })

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.VALIDATE_PROCESSED)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_refine_validate_processed_to_no_permission_when_operator_lost_permission', 0, () => {
      const baseResult = resolveTeamVerifyActionError(514,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)
      const result = refineTeamVerifyActionErrorResult(baseResult, { noPermission: true })

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.NO_PERMISSION)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })

    it('should_keep_already_in_team_when_both_already_in_team_and_no_permission', 0, () => {
      const baseResult = resolveTeamVerifyActionError(514,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT)
      const result = refineTeamVerifyActionErrorResult(baseResult, { alreadyInTeam: true, noPermission: true })

      expect(result.toastType).assertEqual(TeamVerifyActionErrorToastType.ALREADY_IN_TEAM)
      expect(result.nextStatus).assertEqual(V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED)
    })
  })
}
