/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { V2NIMLoginStatus } from '@nimsdk/base';
import { SubscriptionRepo } from '../../../main/ets/repo/SubscriptionRepo';

export default function subscriptionRepoTest() {
  describe('SubscriptionRepo', () => {
    const resetSubscriptionRepo = (): void => {
      SubscriptionRepo.onlineStateMap.clear();
      SubscriptionRepo.subscriptionArray = [];
      SubscriptionRepo.subscriptionInFlightSet.clear();
    };

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
  });
}
