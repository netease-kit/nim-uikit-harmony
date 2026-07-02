/*
 * Copyright (c) 2026 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export class DeferredStartupTask {
  private readonly task: () => void
  private hasScheduled: boolean = false
  private hasRun: boolean = false
  private generation: number = 0

  constructor(task: () => void) {
    this.task = task
  }

  schedule(scheduler?: (runner: () => void) => void): boolean {
    if (this.hasScheduled || this.hasRun) {
      return false
    }

    this.hasScheduled = true
    const scheduledGeneration = this.generation
    const actualScheduler = scheduler ?? ((runner: () => void): void => {
      runner()
    })

    actualScheduler((): void => {
      if (this.generation !== scheduledGeneration) {
        return
      }
      this.runNow()
    })
    return true
  }

  runNow(): boolean {
    if (this.hasRun) {
      return false
    }

    this.hasScheduled = true
    this.hasRun = true
    this.task()
    return true
  }

  reset(): void {
    this.hasScheduled = false
    this.hasRun = false
    this.generation++
  }
}
