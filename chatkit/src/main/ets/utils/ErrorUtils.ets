import { promptAction } from '@kit.ArkUI';
import { V2NIMErrorCode } from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';

/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
export class ErrorUtils {
  static handleErrorToast(errorCode: number) {

    let msg: ResourceStr = $r('app.string.unknown_error');
    switch (errorCode) {
      case V2NIMErrorCode.V2NIM_ERROR_CODE_PIN_LIMIT:
        msg = $r('app.string.chat_pin_limit_error_tips')
        break
      case V2NIMErrorCode.V2NIM_ERROR_CODE_COLLECTION_LIMIT:
        msg = $r('app.string.chat_collection_limit_error_tips')
        break
      case V2NIMErrorCode.V2NIM_ERROR_CODE_ILLEGAL_STATE:
        msg = $r('app.string.chat_network_error_tips')
        break
    }

    try {
      promptAction.showToast({
        message: msg,
        alignment: Alignment.Bottom
      })
    } catch (error) {
      console.error(`showToast args error code is ${error.code}, message is ${error.message}`);
    }
  }

  static checkNetworkAndToast(): boolean {
    if (ChatKitClient.connectBroken()) {
      ErrorUtils.showToast($r('app.string.chat_network_error_tips'))
    }
    return !ChatKitClient.connectBroken()
  }

  private static showToast(msg: ResourceStr) {
    try {
      promptAction.showToast({
        message: msg,
        alignment: Alignment.Bottom
      })
    } catch (error) {
      console.error(`showToast args error code is ${error.code}, message is ${error.message}`);
    }
  }
}
