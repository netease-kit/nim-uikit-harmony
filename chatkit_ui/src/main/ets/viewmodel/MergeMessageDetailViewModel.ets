/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ErrorUtils, MergedMessageAttachment, multiForwardFileName, StorageRepo } from '@nimkit/chatkit';
import { V2NIMMessage, V2NIMMessageCallAttachment, V2NIMMessageType } from '@nimsdk/base';
import Hash from '@ohos.file.hash';
import fs from '@ohos.file.fs';
import { NECommonUtils } from '@nimkit/common';
import { MergeMessageInfo } from '../model/MergeMessageInfo';

@ObservedV2
export class MergeMessageDetailViewModel {
  @Trace mergeMessageInfo?: MergeMessageInfo;

  //初始化
  init(mergeMessageInfo: MergeMessageInfo): void {
    this.mergeMessageInfo = mergeMessageInfo;
  }

  loadMergeMessage(pathStack: NavPathStack, attachment: MergedMessageAttachment) {
    const cachePath = getContext().cacheDir
    const filePath = cachePath + multiForwardFileName + "_" + attachment.md5
    if (fs.accessSync(filePath)) {
      this.decodeMessage(filePath, attachment.md5)
    } else {
      if (ErrorUtils.checkNetworkAndToast()) {
        this.downloadAttachment(attachment.url ?? "", filePath).then(() => {
          this.decodeMessage(filePath, attachment.md5)
        })
      } else {
        pathStack.removeByName("MergeMessageDetailPage")
      }
    }
  }

  async decodeMessage(filePath: string, md5?: string) {
    try {
      const fileMD5 = await Hash.hash(filePath, 'md5')
      if (fileMD5.toLowerCase() === md5) {
        const line = await fs.readText(filePath)
        const lineList = line.split('\n')
        let messageList: V2NIMMessage[] = []
        if (lineList.length > 1) {
          for (let index = 1; index < lineList.length; index++) {
            const msgJson = lineList[index];
            const message = ChatKitClient.nim.messageConverter.messageDeserialization(msgJson)
            if (message) {
              // 语音消息
              if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
                message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT
                message.text = getContext().resourceManager.getStringSync($r('app.string.audioMessageType').id)
              }
              // 话单消息
              if (message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
                message.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT
                if (message.attachment) {
                  let attachment = message.attachment as V2NIMMessageCallAttachment
                  if (attachment.type == 1) {
                    message.text = getContext().resourceManager.getStringSync($r('app.string.msg_type_rtc_audio').id)
                  } else {
                    message.text = getContext().resourceManager.getStringSync($r('app.string.msg_type_rtc_video').id)
                  }
                }
              }
              let msgInfo = this.mergeMessageInfo?.pushMessage(message);
              if (msgInfo) {
                msgInfo.isMergeDetailMsg = true
              }
            }
          }
        }
      } else {
        NECommonUtils.showToast($r('app.string.file_md5_check_failed'))
      }
    } catch (err) {
      console.log(err)
    }
  }

  async downloadAttachment(url: string, filePath: string) {
    try {
      await StorageRepo.downloadFile(url, filePath, (progress: number) => {

      })
    } catch (err) {
      console.error(err)
    }
  }

  onDestroy(): void {
  }
}