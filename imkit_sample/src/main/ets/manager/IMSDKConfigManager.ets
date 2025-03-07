/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import fs from '@ohos.file.fs';
import { NIMServiceOptions } from '@nimsdk/base';

export class IMSDKConfigModel {
  configOptions?: NIMServiceOptions
  customJson?: string
  enableCustomConfig: boolean = false
  accountId?: string
  accountIdToken?: string
}

export class IMSDKConfigManager {
  static configModel?: IMSDKConfigModel
  static fileName = 'sdk_config'

  /// 保存私有化配置
  static saveConfig(model: IMSDKConfigModel) {
    IMSDKConfigManager.clearConfig()
    IMSDKConfigManager.configModel = model

    let path = getContext().filesDir + '/' + IMSDKConfigManager.fileName
    // 新建并打开文件
    let file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    // 写入一段内容至文件
    fs.writeSync(file.fd, JSON.stringify(model));
    // 关闭文件
    fs.closeSync(file);
  }

  /// 获取私有化配置
  static getConfig() {
    if (IMSDKConfigManager.configModel) {
      return IMSDKConfigManager.configModel
    }

    let path = getContext().filesDir + '/' + IMSDKConfigManager.fileName
    if (fs.accessSync(path)) {
      const line = fs.readTextSync(path)
      const data = JSON.parse(line) as IMSDKConfigModel
      if (data) {
        IMSDKConfigManager.configModel = data
        return data
      }
    }
    return undefined
  }

  /// 删除配置
  static clearConfig() {
    let path = getContext().filesDir + '/' + IMSDKConfigManager.fileName
    if (fs.accessSync(path)) {
      fs.unlinkSync(path)
    }
    IMSDKConfigManager.configModel = undefined
  }
}