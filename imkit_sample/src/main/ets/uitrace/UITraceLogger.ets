/**
 * UITraceLogger
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−04-18
 *
 * Copyright © 2025 Netease. All rights reserved.
 */
import { taskpool } from "@kit.ArkTS"
import fs from '@ohos.file.fs';

@Concurrent
async function writeLogger(filePath: string, domain: string, message: string, event?: Record<string, string | number>) {
  // date formatter
  const date = new Date()
  const milliseconds: number = date.getMilliseconds()
  const formattedMilliseconds: string = ("00" + milliseconds).slice(-3);
  const dateStr = `${date.getMonth() +
    1}-${date.getDate()} ${date.getHours()}:${date.getMinutes()}:${date.getSeconds()}:${formattedMilliseconds}`
  const prefix = `[${dateStr}]: ${domain}: ${message} `
  // formatter
  const eventStr = JSON.stringify(event)
  const logMessage = `${prefix + ': ' + eventStr}\n`
  console.info(logMessage)
  const file: fs.File = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.APPEND)
  fs.writeSync(file.fd, logMessage)
  fs.closeSync(file)
}

class UITraceLogger {
  // 本地日志，默认保存 15 天
  private static readonly LoggerFileEffectivePeriod: number = 15
  logDir: string = ''
  sequenceRunner: taskpool.SequenceRunner
  private currentLogPath: string | undefined = undefined

  public constructor() {
    this.sequenceRunner = new taskpool.SequenceRunner()
  }

  async write(domain: string, message: string, event?: Record<string, string | number>): Promise<void> {
    const filePath = this.getLogFilePath()
    const task = new taskpool.Task(writeLogger, filePath, domain, message, event??[])
    this.sequenceRunner.execute(task)
  }

  public getLogDirectory(): string {
    return this.logDir
  }

  public getLogFilePath(): string {
    if (this.currentLogPath) {
      return this.currentLogPath
    }

    this.logDir = getContext().cacheDir + '/nim_kit_log'
    this.checkLoggerEffectivePeriod(this.logDir)
    const formattedDate = this.formattedDate()
    this.currentLogPath = this.logDir + `/nim_kit_ui_${formattedDate}.txt`

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
      if (fileList.length >= UITraceLogger.LoggerFileEffectivePeriod) {
        fileList.sort((a, b) => a.localeCompare(b))
        let oldestName: string = fileList[0]
        let oldestFilePath = `${fileDir} + ${oldestName}`
        await fs.unlink(oldestFilePath)
      }
    } catch (e) {
      this.write('Error', 'checkLoggerEffectivePeriod', {'fail':JSON.stringify(e), 'filename': fileDir})
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

export default new UITraceLogger()