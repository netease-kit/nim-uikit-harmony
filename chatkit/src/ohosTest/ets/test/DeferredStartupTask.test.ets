/*
 * Copyright (c) 2026 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { DeferredStartupTask } from '../../../main/ets/utils/DeferredStartupTask';

export default function deferredStartupTaskTest() {
  describe('deferredStartupTaskTest', () => {
    it('should_schedule_task_only_once_until_reset', 0, () => {
      let scheduleCount = 0
      const task = new DeferredStartupTask((): void => {
        scheduleCount++
      })

      task.schedule()
      task.schedule()
      expect(scheduleCount).assertEqual(1)

      task.reset()
      task.schedule()
      expect(scheduleCount).assertEqual(2)
    })

    it('should_run_task_only_once_when_triggered_manually', 0, () => {
      let runCount = 0
      const task = new DeferredStartupTask((): void => {
        runCount++
      })

      task.runNow()
      task.runNow()
      expect(runCount).assertEqual(1)
    })
  })
}
