/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { promptAction } from '@kit.ArkUI';

export class NECommonUtils {
  /// toast on center
  public static showToast(msg: ResourceStr) {
    try {
      promptAction.showToast({
        message: msg,
        alignment: Alignment.Center
      });
    } catch (error) {
      console.error(`showToast args error code is ${error.code}, message is ${error.message}`);
    }
    ;
  }
}