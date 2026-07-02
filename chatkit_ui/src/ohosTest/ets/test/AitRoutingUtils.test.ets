/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  AitInsertTarget,
  resolveAvatarLongPressAitAccountId,
  resolveAvatarLongPressAitTarget
} from '../../../main/ets/common/AitRoutingUtils'
import { InputStyleType } from '../../../main/ets/view/ChatInputView'

export default function aitRoutingUtilsTest() {
  describe('aitRoutingUtilsTest', () => {
    it('should_route_avatar_long_press_to_multiline_target_when_input_is_multiline', 0, () => {
      const target = resolveAvatarLongPressAitTarget(InputStyleType.Multiline, true, true)

      expect(target).assertEqual(AitInsertTarget.MultiLine)
    })

    it('should_not_fallback_to_singleline_target_when_multiline_instance_is_missing', 0, () => {
      const target = resolveAvatarLongPressAitTarget(InputStyleType.Multiline, true, false)

      expect(target).assertEqual(AitInsertTarget.None)
    })

    it('should_route_avatar_long_press_to_singleline_target_when_input_is_not_multiline', 0, () => {
      const target = resolveAvatarLongPressAitTarget(InputStyleType.None, true, true)

      expect(target).assertEqual(AitInsertTarget.SingleLine)
    })

    it('should_use_display_sender_for_ai_response_avatar_long_press', 0, () => {
      const accountId = resolveAvatarLongPressAitAccountId('ai_assistant', 'login_user')

      expect(accountId).assertEqual('ai_assistant')
    })

    it('should_ignore_self_display_sender_for_avatar_long_press', 0, () => {
      const accountId = resolveAvatarLongPressAitAccountId('login_user', 'login_user')

      expect(accountId).assertUndefined()
    })
  })
}
