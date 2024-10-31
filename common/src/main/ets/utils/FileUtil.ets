/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';

export class FileUtils {
  // 复制文件
  // @param src 源文件路径
  // @param dest 目标文件路径
  static copyFile(src: string, dest: string) {
    if (src.length <= 0) {
      return
    }
    if (dest.length <= 0) {
      return
    }
    if (src === dest) {
      return
    }
    try {
      const file = fs.openSync(src, fs.OpenMode.READ_ONLY)
      fs.copyFileSync(file.fd, dest)
    } catch (err) {
      console.error('netease copy file failed', err);
    }
  }

  // 删除目录
  // @param path 文件夹路径
  static async deleteDir(path: string) {
    if (path.length <= 0) {
      return
    }
    try {
      await fs.rmdir(path)
    } catch (err) {
      console.error('netease delete dir failed', err);
    }
  }

  // 删除文件
  // @param path 文件路径
  static async deleteFile(path: string) {
    if (path.length <= 0) {
      return
    }
    try {
      await fs.unlink(path)
    } catch (err) {
      console.error('netease delete file failed', err);
    }
  }

  static async createFile(path: string) {
    if (path.length <= 0) {
      return
    }
    let file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    fs.createRandomAccessFile(file).then((randomAccessFile: fs.RandomAccessFile) => {
      randomAccessFile.close();
    }).catch((err: BusinessError) => {
      console.error("netease create randomAccessFile failed with error message: " + err.message + ", error code: " +
      err.code);
    }).finally(() => {
      fs.closeSync(file);
    });
  }
}
