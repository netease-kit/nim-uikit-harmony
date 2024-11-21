/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { LogLevel } from '@nimsdk/base'
import { LoggerKitImpl } from './LoggerKitImpl'

export class KitLogger {
  private core: LoggerKitImpl

  public constructor(core: LoggerKitImpl) {
    this.core = core
  }

  public async debug(label?: string, message?: string, ...args: string[]): Promise<void> {
    try {
      label = label ? label : 'Debug'
      message = message ? message : 'logMessage'
      const level = LogLevel.Debug
      this.core.write(level, label, message, args)
    } catch (e) {
      this.core.write(LogLevel.Error, label ?? '', 'debug', ['write error'])
    }
  }

  public async info(label?: string, message?: string, ...args: string[]): Promise<void> {
    try {
      label = label ? label : 'Info'
      message = message ? message : 'logMessage'
      const level = LogLevel.Info
      this.core.write(level, label, message, args)
    } catch (e) {
      this.core.write(LogLevel.Error, label ?? '', 'debug', ['write error'])
    }
  }

  public async warn(label?: string, message?: string, ...args: string[]): Promise<void> {
    try {
      label = label ? label : 'Warn'
      message = message ? message : 'logMessage'
      const level = LogLevel.Warn
      this.core.write(level, label, message, args)
    } catch (e) {
      this.core.write(LogLevel.Error, label ?? '', 'debug', ['write error'])
    }
  }

  public async error(label?: string, message?: string, ...args: string[]): Promise<void> {
    try {
      label = label ? label : 'Error'
      message = message ? message : 'logMessage'
      const level = LogLevel.Error
      this.core.write(level, label, message, args)
    } catch (e) {
      this.core.write(LogLevel.Error, label ?? '', 'debug', ['write error'])
    }
  }
}

