/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium'
import { shouldStopAudioPlaybackOnMessageItemDisappear } from '../../../main/ets/common/AudioPlaybackPolicy'

export default function audioPlaybackPolicyTest() {
  describe('audioPlaybackPolicyTest', () => {
    it('should_not_stop_audio_when_message_item_disappears_from_viewport', 0, () => {
      expect(shouldStopAudioPlaybackOnMessageItemDisappear()).assertFalse()
    })
  })
}
