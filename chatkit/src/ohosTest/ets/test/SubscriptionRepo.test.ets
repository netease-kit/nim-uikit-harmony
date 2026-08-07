/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMLoginClientType, V2NIMLoginStatus, V2NIMUserStatus } from '@nimsdk/base';
import { SubscriptionRepo } from '../../../main/ets/repo/SubscriptionRepo';

export default function subscriptionRepoTest() {
  describe('SubscriptionRepo', () => {
    const resetSubscriptionRepo = (): void => {
      SubscriptionRepo.onlineStateMap.clear();
      SubscriptionRepo.subscriptionArray = [];
      SubscriptionRepo.subscriptionInFlightSet.clear();
    };

    const makeUserStatus = (accountId: string, statusType: number, serverExtension?: string): V2NIMUserStatus => {
      return {
        accountId,
        statusType,
        clientType: V2NIMLoginClientType.V2NIM_LOGIN_CLIENT_TYPE_PC,
        publishTime: 0,
        serverExtension
      } as V2NIMUserStatus
    }

    it('should_keep_cached_online_state_during_temporary_unlogin_status', 0, async () => {
      resetSubscriptionRepo();
      SubscriptionRepo.onlineStateMap.set('friendA', true);
      SubscriptionRepo.subscriptionArray.push('friendA');

      await SubscriptionRepo.onLoginStatusFun(V2NIMLoginStatus.V2NIM_LOGIN_STATUS_UNLOGIN);

      expect(SubscriptionRepo.getOnlineState('friendA')).assertTrue();
      expect(SubscriptionRepo.subscriptionArray.includes('friendA')).assertTrue();
    });

    it('should_keep_cached_online_state_during_temporary_logining_status', 0, async () => {
      resetSubscriptionRepo();
      SubscriptionRepo.onlineStateMap.set('friendA', true);
      SubscriptionRepo.subscriptionArray.push('friendA');

      await SubscriptionRepo.onLoginStatusFun(V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINING);

      expect(SubscriptionRepo.getOnlineState('friendA')).assertTrue();
      expect(SubscriptionRepo.subscriptionArray.includes('friendA')).assertTrue();
    });

    it('should_clear_cached_online_state_after_logout', 0, async () => {
      resetSubscriptionRepo();
      SubscriptionRepo.onlineStateMap.set('friendA', true);
      SubscriptionRepo.subscriptionArray.push('friendA');

      await SubscriptionRepo.onLoginStatusFun(V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGOUT);

      expect(SubscriptionRepo.getOnlineState('friendA')).assertUndefined();
      expect(SubscriptionRepo.subscriptionArray.length).assertEqual(0);
    });

    it('should_reset_subscription_state_when_login_account_boundary_changes', 0, () => {
      resetSubscriptionRepo();
      SubscriptionRepo.onlineStateMap.set('friendA', true);
      SubscriptionRepo.subscriptionArray.push('friendA');
      SubscriptionRepo.subscriptionInFlightSet.add('friendB');

      SubscriptionRepo.resetSubscriptionState();

      expect(SubscriptionRepo.getOnlineState('friendA')).assertUndefined();
      expect(SubscriptionRepo.subscriptionArray.length).assertEqual(0);
      expect(SubscriptionRepo.subscriptionInFlightSet.size).assertEqual(0);
    });

    it('should_mark_custom_status_user_online_when_server_extension_contains_online_clients', 0, () => {
      resetSubscriptionRepo();

      SubscriptionRepo.applyUserStatusChanged([
        makeUserStatus('friendA', 10001, '{"online":[16]}')
      ])

      expect(SubscriptionRepo.getOnlineState('friendA')).assertTrue();
    });

    it('should_mark_user_offline_when_server_extension_online_list_is_empty', 0, () => {
      resetSubscriptionRepo();

      SubscriptionRepo.applyUserStatusChanged([
        makeUserStatus('friendA', 1, '{"online":[]}')
      ])

      expect(SubscriptionRepo.getOnlineState('friendA')).assertFalse();
    });

    it('should_fallback_to_status_type_when_server_extension_is_missing', 0, () => {
      resetSubscriptionRepo();

      SubscriptionRepo.applyUserStatusChanged([
        makeUserStatus('friendA', 1),
        makeUserStatus('friendB', 10001)
      ])

      expect(SubscriptionRepo.getOnlineState('friendA')).assertTrue();
      expect(SubscriptionRepo.getOnlineState('friendB')).assertFalse();
    });

    it('should_ignore_invalid_server_extension_and_fallback_to_status_type', 0, () => {
      resetSubscriptionRepo();

      SubscriptionRepo.applyUserStatusChanged([
        makeUserStatus('friendA', 1, 'not-json')
      ])

      expect(SubscriptionRepo.getOnlineState('friendA')).assertTrue();
    });
  });
}
