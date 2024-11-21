/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { taskpool } from '@kit.ArkTS';
import {
    LogLevel,
    NetWorkingInStance, NIMEStrAnyObj, V2NIMErrorImpl
} from '@nimsdk/base';

import fs from '@ohos.file.fs';

@Concurrent
async function writeLogger(filePath: string, level: string, label: string, message: string, state: string,
  ...args: NIMEStrAnyObj[]) {
  //  CELLULAR = 0, WIFI = 1, ETHERNET = 3, VPN = 4
  const netInfo = NetWorkingInStance.getInstance().getNetInfoSync()
  const customInfo = `${state}_${netInfo.netType}_${netInfo.isConnected}`
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

const TAG = '[LoggerServiceImpl]'

export class LoggerKitImpl {
  // 本地日志，默认保存 15 天
  private static readonly LoggerFileEffectivePeriod: number = 15
  logDir: string = ''
  // core: NIM
  sequenceRunner: taskpool.SequenceRunner
  logLevel: LogLevel
  isOpenConsoleLog: boolean
  private currentLogPath: string

  public constructor(cacheDir: string, logLevel?: LogLevel, isOpenConsoleLog?: boolean) {
    // core.loggerService = this
    // this.core = core
    this.logDir = cacheDir + '/nim_kit_log'
    this.checkLoggerEffectivePeriod(this.logDir)
    const formattedDate = this.formattedDate()
    this.currentLogPath = this.logDir + `/nim_kit_${formattedDate}.txt`
    // this.core.eventBus.on('LoggerServiceImpl/onUploadLogFiles', () => {
    //   this.uploadZipLogFile(false)
    // })

    this.sequenceRunner = new taskpool.SequenceRunner()
    this.logLevel = logLevel ?? LogLevel.Debug
    this.isOpenConsoleLog = isOpenConsoleLog ?? false
  }

  async write(level: LogLevel, label: string, message: string, ...args: NIMEStrAnyObj[]): Promise<void> {

    let state = 'U'
    // const isForeground = this.core.settingService?.v2IGetIsForeground()
    // if (typeof isForeground !== 'undefined') {
    //   state = isForeground ? 'F' : 'B'
    // }

    if (this.isWriteLog(level)) {
      const filePath = this.currentLogPath
      const task = new taskpool.Task(writeLogger, filePath, level, label, message, state, args)
      this.sequenceRunner.execute(task)
    }

    this.consoleLog(level, label, message, args)
  }

  isWriteLog(level: LogLevel): boolean {
    switch (this.logLevel) {
      case LogLevel.Debug:
        return true;
      case LogLevel.Info:
        return level !== LogLevel.Debug;
      case LogLevel.Warn:
        return level !== LogLevel.Debug && level !== LogLevel.Info;
      case LogLevel.Error:
        return level === LogLevel.Error;
      default:
        return true;
    }
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

  // async uploadSDKLogs(isActive: boolean): Promise<string> {
  //   try {
  //     this.core.logger.info(TAG, 'uploadSDKLogs', isActive)
  //     return await this.uploadZipLogFile(isActive)
  //   } catch (e) {
  //     this.core.logger.error(TAG, 'uploadSDKLogs', isActive, e)
  //     if (e instanceof V2NIMErrorImpl || e.name === 'V2NIMError') {
  //       throw e as V2NIMErrorImpl
  //     } else {
  //       throw new V2NIMErrorImpl({
  //         code: V2NIMErrorCode.V2NIM_ERROR_CODE_FILE_UPLOAD_FAILED,
  //         detail: {
  //           reason: 'upload log file: error: ' + `${JSON.stringify(e)}`
  //         }
  //       })
  //     }
  //   }
  // }

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

  // async uploadZipLogFile(isActive: boolean): Promise<string> {
  //   let outFile = this.getOutputZipFilePath()
  //   try {
  //     this.core.logger.info(TAG, 'uploadZipLogFile', isActive)
  //     // zip log file
  //     const fileList: Array<string> = await fs.listFile(this.logDir, { recursion: false, listNum: 0 })
  //     const zipList = fileList.map(item => this.logDir + '/' + item)
  //     await zlib.compressFiles(zipList, outFile, {
  //       level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION,
  //       memLevel: zlib.MemLevel.MEM_LEVEL_MAX,
  //       strategy: zlib.CompressStrategy.COMPRESS_STRATEGY_HUFFMAN_ONLY
  //     })
  //
  //     const result: UploadFileResult = await this.core.storageService.uploadFileTask({
  //       taskId: guid(),
  //       uploadParams: {
  //         filePath: outFile,
  //         sceneName: V2NIMStorageSceneConfig.DEFAULT_SYSTEM().sceneName,
  //       } as V2NIMUploadFileParams
  //     })
  //     // 上传成功删除本地zip 文件
  //     await this.uploadSendLog(result.url, isActive)
  //     await fs.unlink(outFile)
  //     this.core.logger.info(TAG, 'uploadZipLogFile succeed')
  //     return result.url
  //   } catch (e) {
  //     await fs.unlink(outFile)
  //     this.core.logger.error(TAG, 'uploadZipLogFile', isActive, e)
  //     if (e instanceof V2NIMErrorImpl || e.name === 'V2NIMError') {
  //       throw e as V2NIMErrorImpl
  //     } else {
  //       throw new V2NIMErrorImpl({
  //         code: V2NIMErrorCode.V2NIM_ERROR_CODE_FILE_UPLOAD_FAILED,
  //         detail: {
  //           reason: 'upload log file: error: ' + `${JSON.stringify(e)}`
  //         }
  //       })
  //     }
  //   }
  // }

  // private async uploadSendLog(url: string, isActive: boolean): Promise<void> {
  //   try {
  //     this.core.logger.info(TAG, 'uploadSendLog', url, isActive)
  //     const activeType = isActive ? 1 : 0
  //     const uploadLogUrlRequest: UploadLogUrlRequest = new UploadLogUrlRequest(
  //       url,
  //       new UploadLogUrlParams(activeType)
  //     )
  //     await this.core.sendCmd('uploadLogUrl', uploadLogUrlRequest)
  //   } catch (e) {
  //     this.core.logger.error(TAG, 'uploadSendLog', url, isActive, e)
  //   }
  // }

  private getOutputZipFilePath(): string {
    const filepath = this.logDir + `/nim_log.zip`
    if (fs.accessSync(filepath)) {
      fs.unlinkSync(filepath)
    }

    return filepath
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