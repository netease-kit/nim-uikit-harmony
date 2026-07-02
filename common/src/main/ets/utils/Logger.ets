/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0xFF00;

type LogArg = string | Error | number | boolean | Object | undefined | null;

/**
 * nimkit 统一日志工具。
 */
export class Logger {

  static debug(tag: string, ...args: LogArg[]): void {
    hilog.debug(DOMAIN, tag, '%{public}s', Logger.format(args));
  }

  static info(tag: string, ...args: LogArg[]): void {
    hilog.info(DOMAIN, tag, '%{public}s', Logger.format(args));
  }

  static warn(tag: string, ...args: LogArg[]): void {
    hilog.warn(DOMAIN, tag, '%{public}s', Logger.format(args));
  }

  static error(tag: string, ...args: LogArg[]): void {
    hilog.error(DOMAIN, tag, '%{public}s', Logger.format(args));
  }

  private static format(args: LogArg[]): string {
    let result = '';
    for (let i = 0; i < args.length; i++) {
      if (i > 0) { result += ' '; }
      const arg = args[i];
      if (typeof arg === 'string') {
        result += arg;
      } else if (typeof arg === 'number' || typeof arg === 'boolean') {
        result += String(arg);
      } else {
        result += JSON.stringify(arg);
      }
    }
    return result;
  }
}
