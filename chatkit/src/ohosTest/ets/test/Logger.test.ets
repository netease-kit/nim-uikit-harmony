/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { LoggerKitImpl } from '../../../main/ets/logger/LoggerKitImpl';
import { KitLogger } from '../../../main/ets/logger/AppLogger';
import { LogLevel, NIMEStrAnyObj } from '@nimsdk/base';

export default function LoggerTest() {
  describe('LoggerKitImpl_constructor', () => {
    it('should_construct_with_default_values', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache');
      expect(logger.logLevel).assertEqual(LogLevel.Debug);
      expect(logger.isOpenConsoleLog).assertTrue();
      expect(logger.logDir.length > 0).assertTrue();
    });
    it('should_construct_with_custom_level', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache', LogLevel.Error);
      expect(logger.logLevel).assertEqual(LogLevel.Error);
    });
    it('should_construct_with_console_log_disabled', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache', LogLevel.Debug, false);
      expect(logger.isOpenConsoleLog).assertFalse();
    });
    it('should_getLogDirectory', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache');
      const dir: string = logger.getLogDirectory();
      expect(dir.length > 0).assertTrue();
    });
    it('should_getLogFilePath', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache');
      const path: string = logger.getLogFilePath();
      expect(path.length > 0).assertTrue();
    });
  });

  describe('LoggerKitImpl_consoleLog', () => {
    it('should_log_debug_when_console_open', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache', LogLevel.Debug, true);
      const args: NIMEStrAnyObj[] = [JSON.parse('{"key":"value"}') as NIMEStrAnyObj];
      logger.consoleLog(LogLevel.Debug, 'TestLabel', 'test message', args);
    });
    it('should_log_info_when_console_open', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache', LogLevel.Debug, true);
      const args: NIMEStrAnyObj[] = [JSON.parse('{"key":"value"}') as NIMEStrAnyObj];
      logger.consoleLog(LogLevel.Info, 'TestLabel', 'test message', args);
    });
    it('should_log_warn_when_console_open', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache', LogLevel.Debug, true);
      const args: NIMEStrAnyObj[] = [JSON.parse('{"key":"value"}') as NIMEStrAnyObj];
      logger.consoleLog(LogLevel.Warn, 'TestLabel', 'test message', args);
    });
    it('should_log_error_when_console_open', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache', LogLevel.Debug, true);
      const args: NIMEStrAnyObj[] = [JSON.parse('{"key":"value"}') as NIMEStrAnyObj];
      logger.consoleLog(LogLevel.Error, 'TestLabel', 'test message', args);
    });
    it('should_not_log_when_console_closed', 0, () => {
      const logger: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache', LogLevel.Debug, false);
      const args: NIMEStrAnyObj[] = [JSON.parse('{"key":"value"}') as NIMEStrAnyObj];
      logger.consoleLog(LogLevel.Debug, 'TestLabel', 'test message', args);
    });
  });

  describe('KitLogger_constructor', () => {
    it('should_construct_with_core', 0, () => {
      const core: LoggerKitImpl = new LoggerKitImpl('/tmp/test_cache');
      const kitLogger: KitLogger = new KitLogger(core);
      expect(kitLogger !== undefined).assertTrue();
    });
  });
}