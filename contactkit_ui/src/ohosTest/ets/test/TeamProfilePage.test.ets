/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  TeamApplyJoinToastType,
  resolveTeamApplyJoinErrorToastType
} from '../../../main/ets/utils/TeamProfileUtils';

export default function teamProfilePageTest() {
  describe('TeamProfilePage_resolveTeamApplyJoinErrorToastType', () => {
    it('should_treat_waiting_verify_error_as_application_sent', 0, () => {
      expect(resolveTeamApplyJoinErrorToastType(808)).assertEqual(TeamApplyJoinToastType.APPLICATION_SENT)
    })
  })
}
