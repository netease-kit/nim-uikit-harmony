/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { promptAction } from '@kit.ArkUI';

export class NECommonUtils {
  /// toast on bottom
  public static showToast(msg: ResourceStr) {
    try {
      promptAction.showToast({
        message: msg,
        alignment: Alignment.Bottom
      });
    } catch (error) {
      console.error(`showToast args error code is ${error.code}, message is ${error.message}`);
    }
    ;
  }

  /// 获取简称 (尾部截取)
  /// - Parameter showAlias: 是否优先显示备注
  /// - Parameter count: 尾部截取长度
  public static shortName(name?: string, count: number = 2): string {
    if (name) {
      const start: number = (name.length - count) > 0 ? name.length - count : 0
      const end: number = name.length
      return name.substring(start, end)
    }
    return ""
  }
}