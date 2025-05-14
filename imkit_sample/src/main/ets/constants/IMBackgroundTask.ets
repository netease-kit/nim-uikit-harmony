/**
 * IMBackgroundTask
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−04-17
 *
 * Copyright © 2025 Netease. All rights reserved.
 */

import { backgroundTaskManager } from "@kit.BackgroundTasksKit";
import { BusinessError } from "@kit.BasicServicesKit";

const TAG = '[IMBackgroundTask]'

export class IMBackgroundTask {
  private taskId?: number // 申请短期任务ID
  private delayTime?: number;  // 本次申请短时任务的剩余时间

  private static instance: IMBackgroundTask;

  public static getInstance(): IMBackgroundTask {
    if (!IMBackgroundTask.instance) {
      IMBackgroundTask.instance = new IMBackgroundTask();
    }
    return IMBackgroundTask.instance;
  }

  constructor() {
  }
  // 申请短时任务
  requestSuspendDelay() {
    try {
      console.info(TAG, 'requestSuspendDelay')
      let myReason = 'data storage request suspend delay';   // 申请原因
      let delayInfo = backgroundTaskManager.requestSuspendDelay(myReason, () => {
        // 回调函数。应用申请的短时任务即将超时，通过此函数回调应用，执行一些清理和标注工作，并取消短时任务
        console.info(TAG, 'suspend delay task will timeout');
        if (this.taskId) {
          backgroundTaskManager.cancelSuspendDelay(this.taskId);
        }
      })

      this.taskId = delayInfo.requestId;
      this.delayTime = delayInfo.actualDelayTime;
      console.info(TAG, `requestSuspendDelay id: ${delayInfo.requestId} time: ${delayInfo.actualDelayTime}`)
    } catch (e) {
      console.warn(TAG, 'requestSuspendDelay failed', e)
    }
  }

  async getRemainingDelayTime() {
    backgroundTaskManager.getRemainingDelayTime(this.taskId).then((res: number) => {
      console.info(TAG, 'Succeeded in getting remaining delay time.', res);
    }).catch((err: BusinessError) => {
      console.error(TAG, `Failed to get remaining delay time. Code: ${err.code}, message: ${err.message}`);
    })
  }

  cancelSuspendDelay() {
    try {
      if (this.taskId) {
        console.info(TAG, 'cancelSuspendDelay')
        backgroundTaskManager.cancelSuspendDelay(this.taskId);
      }
    } catch (e) {
      console.warn(TAG, 'cancelSuspendDelay failed', e)
    }
  }
}