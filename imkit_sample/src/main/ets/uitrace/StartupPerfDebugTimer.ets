const KEY_RUNNING = 'imkit_startup_perf_running'
const KEY_START_AT = 'imkit_startup_perf_start_at'
const KEY_ELAPSED_MS = 'imkit_startup_perf_elapsed_ms'
const KEY_FINAL_MS = 'imkit_startup_perf_final_ms'
const KEY_STAGE = 'imkit_startup_perf_stage'
const KEY_COUNT = 'imkit_startup_perf_count'
const KEY_RUN_ID = 'imkit_startup_perf_run_id'
const KEY_STABLE_TOKEN = 'imkit_startup_perf_stable_token'

export class StartupPerfDebugTimer {
  static start(stage: string): void {
    const now = Date.now()
    const runId = (AppStorage.get<number>(KEY_RUN_ID) ?? 0) + 1
    AppStorage.setOrCreate<boolean>(KEY_RUNNING, true)
    AppStorage.setOrCreate<number>(KEY_START_AT, now)
    AppStorage.setOrCreate<number>(KEY_ELAPSED_MS, 0)
    AppStorage.setOrCreate<number>(KEY_FINAL_MS, 0)
    AppStorage.setOrCreate<string>(KEY_STAGE, stage)
    AppStorage.setOrCreate<number>(KEY_COUNT, 0)
    AppStorage.setOrCreate<number>(KEY_RUN_ID, runId)
    AppStorage.setOrCreate<number>(KEY_STABLE_TOKEN, 0)
  }

  static startIfNotRunning(stage: string): void {
    if (StartupPerfDebugTimer.isRunning()) {
      return
    }
    StartupPerfDebugTimer.start(stage)
  }

  static mark(stage: string, count?: number): void {
    if (!StartupPerfDebugTimer.hasStarted()) {
      return
    }
    StartupPerfDebugTimer.updateElapsed()
    AppStorage.setOrCreate<string>(KEY_STAGE, stage)
    if (count !== undefined) {
      AppStorage.setOrCreate<number>(KEY_COUNT, count)
    }
  }

  static scheduleStableFinish(stage: string, count: number, stableMs: number): void {
    if (!StartupPerfDebugTimer.isRunning()) {
      return
    }
    const runId = AppStorage.get<number>(KEY_RUN_ID) ?? 0
    const stableToken = (AppStorage.get<number>(KEY_STABLE_TOKEN) ?? 0) + 1
    AppStorage.setOrCreate<number>(KEY_STABLE_TOKEN, stableToken)
    StartupPerfDebugTimer.mark(`${stage}.stable_wait_${stableMs}ms`, count)
    setTimeout(() => {
      if ((AppStorage.get<number>(KEY_RUN_ID) ?? 0) !== runId ||
        (AppStorage.get<number>(KEY_STABLE_TOKEN) ?? 0) !== stableToken ||
        !StartupPerfDebugTimer.isRunning()) {
        return
      }
      StartupPerfDebugTimer.finish(stage, count)
    }, stableMs)
  }

  static finish(stage: string, count: number): void {
    if (!StartupPerfDebugTimer.isRunning()) {
      return
    }
    StartupPerfDebugTimer.updateElapsed()
    const elapsed = AppStorage.get<number>(KEY_ELAPSED_MS) ?? 0
    AppStorage.setOrCreate<boolean>(KEY_RUNNING, false)
    AppStorage.setOrCreate<number>(KEY_FINAL_MS, elapsed)
    AppStorage.setOrCreate<string>(KEY_STAGE, stage)
    AppStorage.setOrCreate<number>(KEY_COUNT, count)
  }

  static fail(stage: string): void {
    if (!StartupPerfDebugTimer.hasStarted()) {
      return
    }
    StartupPerfDebugTimer.updateElapsed()
    const elapsed = AppStorage.get<number>(KEY_ELAPSED_MS) ?? 0
    AppStorage.setOrCreate<boolean>(KEY_RUNNING, false)
    AppStorage.setOrCreate<number>(KEY_FINAL_MS, elapsed)
    AppStorage.setOrCreate<string>(KEY_STAGE, stage)
  }

  static tick(): void {
    if (StartupPerfDebugTimer.isRunning()) {
      StartupPerfDebugTimer.updateElapsed()
    }
  }

  static elapsedMs(): number {
    const startAt = AppStorage.get<number>(KEY_START_AT) ?? 0
    if (startAt <= 0) {
      return -1
    }
    return Date.now() - startAt
  }

  private static updateElapsed(): void {
    const startAt = AppStorage.get<number>(KEY_START_AT) ?? 0
    if (startAt <= 0) {
      return
    }
    AppStorage.setOrCreate<number>(KEY_ELAPSED_MS, Date.now() - startAt)
  }

  private static hasStarted(): boolean {
    return (AppStorage.get<number>(KEY_START_AT) ?? 0) > 0
  }

  private static isRunning(): boolean {
    return AppStorage.get<boolean>(KEY_RUNNING) ?? false
  }
}
