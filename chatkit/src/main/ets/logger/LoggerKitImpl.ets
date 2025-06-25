/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { taskpool } from '@kit.ArkTS';
import { LogLevel, NetWorkingInStance, NIMEStrAnyObj, V2NIMErrorImpl } from '@nimsdk/base';

import fs from '@ohos.file.fs';

@Concurrent
async function writeLogger(filePath: string, level: string, label: string, message: string,
  ...args: NIMEStrAnyObj[]) {
  //  CELLULAR = 0, WIFI = 1, ETHERNET = 3, VPN = 4
  const netInfo = NetWorkingInStance.getInstance().getNetInfoSync()
  const customInfo = `${netInfo.netType}_${netInfo.isConnected}`
  // date formatter
  const date = new Date()
  const milliseconds: number = date.getMilliseconds()
  const formattedMilliseconds: string = ("00" + milliseconds).slice(-3);
  const dateStr = `${date.getMonth() +
    1}-${date.getDate()} ${date.getHours()}:${date.getMinutes()}:${date.getSeconds()}:${formattedMilliseconds}`
  const prefix = `[${dateStr}]: ${level}: ${customInfo}: ${label}: ${message} `
  // args formatter
  let tempStr = args.map((item) => {
    if (item instanceof V2NIMErrorImpl) {
      let desc = `${item.name}\n code: ${item.code}\n message: "${item.message}"\n detail: ${item.detail ?
      JSON.stringify(item.detail) : ''}`
      if (item?.detail?.rawError) {
        desc += `\n rawError: ${item.detail.rawError.message}`
      }
      return desc
    } else if (item instanceof Error) {
      return item && item.message ? item.message : item
    } else if (typeof item === 'object') {
      return JSON.stringify(item).replace(/^\[|\]$/g, "").replace(/^\[|\]$/g, "")
    } else {
      return item
    }
  }).join(' ')

  tempStr = tempStr.replace(/^"|"$/g, '')

  const logMessage = tempStr ? `${prefix + ': ' + tempStr}\n` : `${prefix}\n`

  const file: fs.File = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.APPEND)
  fs.writeSync(file.fd, logMessage)
  fs.closeSync(file)
}

export class LoggerKitImpl {
  // 本地日志，默认保存 15 天
  private static readonly LoggerFileEffectivePeriod: number = 15
  logDir: string = ''
  sequenceRunner: taskpool.SequenceRunner
  logLevel: LogLevel
  isOpenConsoleLog: boolean
  private currentLogPath: string

  public constructor(cacheDir: string, logLevel?: LogLevel, isOpenConsoleLog?: boolean) {
    this.logDir = cacheDir + '/nim_kit_log'
    this.checkLoggerEffectivePeriod(this.logDir)
    const formattedDate = this.formattedDate()
    this.currentLogPath = this.logDir + `/nim_kit_${formattedDate}.txt`
    this.sequenceRunner = new taskpool.SequenceRunner()
    this.logLevel = logLevel ?? LogLevel.Debug
    this.isOpenConsoleLog = isOpenConsoleLog ?? true
  }

  async write(level: LogLevel, label: string, message: string, ...args: NIMEStrAnyObj[]): Promise<void> {
    this.consoleLog(level, label, message, args)
    const filePath = this.currentLogPath
    const task = new taskpool.Task(writeLogger, filePath, level, label, message, args)
    this.sequenceRunner.execute(task)
  }

  consoleLog(level: LogLevel, label: string, message: string, args: NIMEStrAnyObj[]) {
    // console log
    message = message.slice(0, 2000)
    if (this.isOpenConsoleLog) {
      if (level === LogLevel.Debug) {
        console.debug(label, message, args[0].length === 0 ? '' : JSON.stringify(args[0]))
      } else if (level === LogLevel.Info) {
        console.info(label, message, args[0].length === 0 ? '' : JSON.stringify(args[0]))
      } else if (level === LogLevel.Error) {
        console.error(label, message, args[0].length === 0 ? '' : JSON.stringify(args[0]))
      } else if (level === LogLevel.Warn) {
        console.warn(label, message, args[0].length === 0 ? '' : JSON.stringify(args[0]))
      }
    }
  }

  public getLogDirectory(): string {
    return this.logDir
  }

  public getLogFilePath(): string {
    return this.currentLogPath
  }

  async checkLoggerEffectivePeriod(fileDir: string): Promise<void> {
    try {
      // 获取log list
      if (!fs.accessSync(this.logDir)) {
        fs.mkdirSync(this.logDir, true);
      }

      let fileList: Array<string> = await fs.listFile(fileDir, { recursion: false, listNum: 0 })
      //  大于等于 15 时，淘汰最久的
      if (fileList.length >= LoggerKitImpl.LoggerFileEffectivePeriod) {
        fileList.sort((a, b) => a.localeCompare(b))
        let oldestName: string = fileList[0]
        let oldestFilePath = `${fileDir} + ${oldestName}`
        await fs.unlink(oldestFilePath)
      }
    } catch (e) {
      this.write(LogLevel.Error, 'checkLoggerEffectivePeriod', `fail:${JSON.stringify(e)}, filename ${fileDir}`)
    }
  }

  private formattedDate(): string {
    const date = new Date()
    const formattedDate = Intl.DateTimeFormat("en-US",
      { year: "numeric", month: "numeric", day: "numeric" }
    ).format(date)
      .replace(/\//g, '_');
    return formattedDate
  }
}