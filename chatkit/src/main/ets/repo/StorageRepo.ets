/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMProgressCallback,
  V2NIMStorageScene,
  V2NIMUploadFileParams,
  V2NIMUploadFileTask
} from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';

export class StorageRepo {
  /**
   * 设置自定义场景
   *
   * @param sceneName 自定义的场景名
   * @param expireTime 文件过期时间. 单位秒. 数值要求大于等于 86400 秒, 即 1 天.
   */
  static addCustomStorageScene(sceneName: string, expireTime: number): V2NIMStorageScene | undefined {
    return ChatKitClient.nim.storageService?.addCustomStorageScene(sceneName, expireTime)
  }

  /**
   * 查询存储场景列表
   */
  static getStorageSceneList(): V2NIMStorageScene[] {
    return ChatKitClient.nim.storageService?.getStorageSceneList() ?? []
  }

  /**
   * 创建文件上传任务
   *
   * @param fileParams 上传文件参数
   * @returns 上传任务
   */
  static createUploadFileTask(fileParams: V2NIMUploadFileParams): V2NIMUploadFileTask | null {
    return ChatKitClient.nim.storageService?.createUploadFileTask(fileParams) ?? null
  }

  /**
   * 上传文件
   *
   * @param fileTask 上传任务，createUploadTask 函数返回值
   * @returns 文件的 url
   */
  static async uploadFile(fileTask: V2NIMUploadFileTask, progress: V2NIMProgressCallback): Promise<string | undefined> {
    return await ChatKitClient.nim.storageService?.uploadFile(fileTask, progress)
  }

  /**
   * 取消文件上传
   *
   * @param fileTask 上传任务，createUploadTask 函数返回值
   */
  static async cancelUploadFile(fileTask: V2NIMUploadFileTask): Promise<void> {
    return await ChatKitClient.nim.storageService?.cancelUploadFile(fileTask)
  }

  /**
   * 下载文件
   *
   * @param url 下载文件 url
   * @param filePath 文件下载存放的本地路径
   * @returns 文件的 url
   */
  static async downloadFile(url: string, filePath: string,
    progress: V2NIMProgressCallback): Promise<string | undefined> {
    return await ChatKitClient.nim.storageService?.downloadFile(url, filePath, progress)
  }

  /**
   * 取消文件下载
   *
   * @param url 下载文件 url
   * @returns
   */
  static async cancelDownloadFile(url: string): Promise<void> {
    return await ChatKitClient.nim.storageService?.cancelDownloadFile(url)
  }

  /**
   * 短链接转长链接
   *
   * @param url 文件远程地址
   * @returns 文件的 url
   */
  static async shortUrlToLong(url: string): Promise<string | undefined> {
    return await ChatKitClient.nim.storageService?.shortUrlToLong(url)
  }
}