/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { filePreview } from '@kit.PreviewKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { V2NIMMessageLocationAttachment, V2NIMMessageSendingState, V2NIMMessageType } from '@nimsdk/base';
import { sceneMap } from '@kit.MapKit';
import { common } from '@kit.AbilityKit';
import { MessageOperationItem, MessageOperationType } from '../model/MessageOperationItem';
import { ChatConst } from '../constants/ChatConst';
import { ChatKitClient } from '@nimkit/chatkit';
import { ChatKitConfig } from '../ChatKitConfig';
import { isSupportMessage } from '../common/MessageHelper';


export function openFileWithApp(fileUri: string, fileName: string, fileExt: string, context: Context) {
  let displayInfo: filePreview.DisplayInfo = {
    x: 100,
    y: 100,
  };
  let fileInfo: filePreview.PreviewInfo = {
    title: fileName,
    uri: fileUri,
    mimeType: getOpenFileType(fileExt)
  };
  filePreview.openPreview(context, fileInfo, displayInfo).then(() => {
    console.info('Succeeded in opening preview');
  }).catch((err: BusinessError) => {
    console.error(`Failed to open preview, err.code = ${err.code}, err.message = ${err.message}`);
  });
}

export function showLocationDetail(msg: NIMMessageInfo, context: common.UIAbilityContext) {
  let attachment = msg.message.attachment as V2NIMMessageLocationAttachment

  let queryLocationOptions: sceneMap.LocationQueryOptions = {
    location: {
      latitude: attachment.latitude,
      longitude: attachment.longitude
    },
    name: attachment.address,
    address: attachment.address,
  };
  // 拉起地点详情页
  sceneMap.queryLocation(context, queryLocationOptions).then(() => {
    console.info("netease QueryLocation", "Succeeded in querying location.");
  }).catch((err: BusinessError) => {
    console.error("netease QueryLocation", `Failed to query Location, code: ${err.code}, message: ${err.message}`);
  });
}

export function setupMoreOperationData() {
  let operationMoreDataList: Array<NEChatMoreOperationData> = Array()

  // 拍摄功能
  const videoOperationData = new NEChatMoreOperationData();
  videoOperationData.operationTitle = $r("app.string.chat_camera_take");
  videoOperationData.type = NEChatMoreOperationType.Video;
  videoOperationData.imageSource = "app.media.ic_public_chat_photo";
  operationMoreDataList.push(videoOperationData);

  // 位置功能
  const locationOperationData = new NEChatMoreOperationData();
  locationOperationData.operationTitle = $r("app.string.chat_send_location");
  locationOperationData.type = NEChatMoreOperationType.Location;
  locationOperationData.imageSource = "app.media.ic_chat_more_location";
  operationMoreDataList.push(locationOperationData);

  // 文件功能
  const fileOperationData = new NEChatMoreOperationData();
  fileOperationData.operationTitle = $r("app.string.chat_send_file");
  fileOperationData.type = NEChatMoreOperationType.File;
  fileOperationData.imageSource = "app.media.ic_public_chat_file";
  operationMoreDataList.push(fileOperationData);

  return operationMoreDataList
}

export function getOpenFileType(fileExt: string): string {

  if (fileExt.includes('txt')) {
    return 'text/plain'
  } else if (fileExt.includes('cpp')) {
    return 'text/x-c++src'
  } else if (fileExt.includes('c')) {
    return 'text/x-csrc'
  } else if (fileExt.includes('h')) {
    return 'text/x-chdr'
  } else if (fileExt.includes('java')) {
    return 'text/x-java'
  } else if (fileExt.includes('xhtml')) {
    return 'application/xhtml+xml'
  } else if (fileExt.includes('xml')) {
    return 'text/xml'
  } else if (fileExt.includes('html') || fileExt.includes('htm')) {
    return 'text/html'
  } else if (fileExt.includes('pdf')) {
    return 'application/pdf'
  } else if (fileExt.includes('jpg')) {
    return 'image/jpeg'
  } else if (fileExt.includes('png')) {
    return 'image/png'
  } else if (fileExt.includes('gif')) {
    return 'image/gif'
  } else if (fileExt.includes('webp')) {
    return 'image/webp'
  } else if (fileExt.includes('bmp')) {
    return 'image/bmp'
  } else if (fileExt.includes('svg')) {
    return 'image/svg+xml'
  } else if (fileExt.includes('m4a')) {
    return 'audio/mp4a-latm'
  } else if (fileExt.includes('mp3')) {
    return 'audio/mpeg'
  } else if (fileExt.includes('aac')) {
    return 'audio/aac'
  } else if (fileExt.includes('ogg')) {
    return 'audio/ogg'
  } else if (fileExt.includes('wav')) {
    return 'audio/x-wav'
  } else if (fileExt.includes('mp4')) {
    return 'video/mp4'
  } else if (fileExt.includes('mkv')) {
    return 'video/x-matroska'
  } else if (fileExt.includes('ts')) {
    return 'video/mp2ts'
  }

  return ' '
}

export function sliceContent(content: string | undefined, maxsize: number, isCenter: boolean): string {
  if (!content) {
    return ''
  }
  let result = content
  if (content.length > maxsize) {
    if (isCenter) {
      let startIndex = Math.floor(maxsize * 0.75)
      let lastIndex = content.length - 2
      let targetStr = content.charAt(startIndex)
      let lastTargetStr = content.charAt(lastIndex)
      // 判断是否为高位
      if (isCharacterEmoji(targetStr) && !isLastCharacterEmoji(targetStr)) {
        startIndex++
      }
      let nick = content.substring(0, startIndex + 1) + "..."
      if (isLastCharacterEmoji(lastTargetStr)) {
        lastIndex++
      }
      result = nick + content.substring(lastIndex)
    } else {
      let lastIndex = maxsize - 2
      let lastTargetStr = content.charAt(lastIndex)
      // 判断是否为高位
      if (isCharacterEmoji(lastTargetStr) && !isLastCharacterEmoji(lastTargetStr)) {
        lastIndex++
      }
      result = content.substring(0, lastIndex + 1) + "..."
    }
  }
  return result
}

// 最后是否为表情符号的最后一位
export function isLastCharacterEmoji(str: string): boolean {
  // 使用正则表达式匹配表情符号
  const emojiRegex = /[\uDC00-\uDFFF]+$/u

  return emojiRegex.test(str)
}

// 最后是否为表情符号
export function isCharacterEmoji(str: string): boolean {
  // 使用正则表达式匹配表情符号
  const emojiRegex = /[\uD83C-\uDBFF\uDC00-\uDFFF]+$/u

  return emojiRegex.test(str)
}

export function getOperateMenu(operateMsg: NIMMessageInfo | undefined): MessageOperationItem[] {
  let operationMoreDataList: MessageOperationItem[] = []
  let localExtension = operateMsg?.message.localExtension;
  if (localExtension == undefined || !localExtension.includes(ChatConst.revokeLocalKey)) {

    if (operateMsg !== undefined &&
      operateMsg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      let copyItem = new MessageOperationItem()
      copyItem.operationType = MessageOperationType.Copy;
      copyItem.operationText = $r('app.string.chat_operation_copy');
      copyItem.operationImage = $r('app.media.ic_chat_menu_copy');
      operationMoreDataList.push(copyItem)
    }

    if (operateMsg !== undefined &&
      operateMsg.message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
      && isSupportMessage(operateMsg)) {
      if (operateMsg.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {

        let replyItem = new MessageOperationItem()
        replyItem.operationType = MessageOperationType.Reply;
        replyItem.operationText = $r('app.string.chat_operation_reply');
        replyItem.operationImage = $r('app.media.ic_chat_menu_reply');
        operationMoreDataList.push(replyItem);


        if (operateMsg.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
          let translateItem = new MessageOperationItem()
          translateItem.operationType = MessageOperationType.Forward;
          translateItem.operationText = $r('app.string.chat_operation_forward');
          translateItem.operationImage = $r('app.media.ic_chat_menu_translate');
          operationMoreDataList.push(translateItem);
        }

        let pinItem = new MessageOperationItem()
        if (operateMsg?.isPinMsg) {
          pinItem.operationText = $r('app.string.chat_operation_unpin');
          pinItem.operationType = MessageOperationType.Unpin;
        } else {
          pinItem.operationType = MessageOperationType.Pin;
          pinItem.operationText = $r('app.string.chat_operation_pin');

        }
        pinItem.operationImage = $r('app.media.ic_chat_menu_pin');
        operationMoreDataList.push(pinItem);
      }

    }

    let deleteItem = new MessageOperationItem()
    deleteItem.operationType = MessageOperationType.Delete;
    deleteItem.operationText = $r('app.string.chat_operation_delete');
    deleteItem.operationImage = $r('app.media.ic_chat_menu_delete');
    operationMoreDataList.push(deleteItem);

    if (operateMsg !== undefined &&
      operateMsg.message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
      && isSupportMessage(operateMsg) && operateMsg.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL
      && systemDateTime.getTime() - operateMsg.message.createTime < ChatKitConfig.messageRevokeTimeLimit
      && operateMsg.message.senderId == ChatKitClient.getLoginUserId()) {

      let undoItem = new MessageOperationItem()
      undoItem.operationImage = $r('app.media.ic_chat_menu_revoke');
      undoItem.operationText = $r('app.string.chat_operation_undo');
      undoItem.operationType = MessageOperationType.Undo;
      operationMoreDataList.push(undoItem)
    }

    let selectItem = new MessageOperationItem()
    selectItem.operationType = MessageOperationType.Select;
    selectItem.operationText = $r('app.string.chat_operation_multi_select');
    selectItem.operationImage = $r('app.media.ic_chat_menu_multi_select');
    operationMoreDataList.push(selectItem);

    if (operateMsg !== undefined &&
      operateMsg.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
      && isSupportMessage(operateMsg)
      && operateMsg.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
      let collectionItem = new MessageOperationItem()
      collectionItem.operationType = MessageOperationType.Collection;
      collectionItem.operationText = $r('app.string.chat_operation_collection');
      collectionItem.operationImage = $r('app.media.ic_chat_menu_collection');
      operationMoreDataList.push(collectionItem);
    }
  }

  return operationMoreDataList
}

export function getOperateMenuSize(msgInfo: NIMMessageInfo | undefined) {
  let count = 0
  if (msgInfo == undefined) {
    return count
  }
  let localExtension = msgInfo?.message.localExtension;
  if (localExtension == undefined || !localExtension.includes(ChatConst.revokeLocalKey)) {
    // 多选和删除
    count = count + 2
    if (msgInfo !== undefined &&
      msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      // 复制
      count++
    }

    if (msgInfo.message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
      && isSupportMessage(msgInfo)) {

      if (msgInfo.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
        // 回复、收藏
        count = count + 2
        if (msgInfo.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
          // 转发、标记
          count = count + 2
        } else {
          // 标记
          count++
        }

        if (msgInfo.getMessageType() !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL &&
          systemDateTime.getTime() - msgInfo.message.createTime < ChatKitConfig.messageRevokeTimeLimit
          && msgInfo.message.senderId == ChatKitClient.getLoginUserId()) {
          // 撤回
          count++;
        }
      }
    }


  }
  return count
}

/**
 * 计算消息长按弹窗宽度
 * @param msg 长按的消息
 * @returns 消息长按弹窗宽度
 */
export function computeOperateViewWidth(msg: NIMMessageInfo | undefined): number {
  return ChatConst.menuItemWidth * Math.min(getOperateMenuSize(msg), ChatConst.menuItemColumnNum)
}

export function computeOperateViewHeight(msg: NIMMessageInfo | undefined): number {
  return ChatConst.menuItemHeight * (Math.ceil(getOperateMenuSize(msg) / ChatConst.menuItemColumnNum))
}

