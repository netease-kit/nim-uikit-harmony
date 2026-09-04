/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { filePreview } from '@kit.PreviewKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import {
  V2NIMConversationType,
  V2NIMMessageLocationAttachment,
  V2NIMMessageSendingState,
  V2NIMMessageType,
  V2NIMTeam,
  V2NIMTeamMemberRole
} from '@nimsdk/base';
import { sceneMap } from '@kit.MapKit';
import { common } from '@kit.AbilityKit';
import { MessageOperationItem, MessageOperationType } from '../model/MessageOperationItem';
import { ChatConst } from '../constants/ChatConst';
import {
  ChatKitClient,
  AIUserManager,
  getTopStickyPermissionMode,
  hasTopStickyPermission,
  IMKitConfigCenter,
  TeamRepo
} from '@nimkit/chatkit';
import { ChatKitConfig } from '../ChatKitConfig';
import { isSupportMessage } from '../common/MessageHelper';
import { canShowAISearchForMessageType } from '../aisearchkit/AISearchMenuUtils';


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
    Logger.info('ChatKitUI', 'Succeeded in opening preview');
  }).catch((err: BusinessError) => {
    Logger.error('ChatKitUI', `Failed to open preview, err.code = ${err.code}, err.message = ${err.message}`);
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
    Logger.info('ChatKitUI', "netease QueryLocation", "Succeeded in querying location.");
  }).catch((err: BusinessError) => {
    Logger.error('ChatKitUI', "netease QueryLocation", `Failed to query Location, code: ${err.code}, message: ${err.message}`);
  });
}

export function setupMoreOperationData(isP2P: boolean, isBot: boolean = false) {
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

  if (isP2P && !isBot) {
    // 呼叫组件功能（Bot 不支持音视频通话）
    const callOperationData = new NEChatMoreOperationData();
    callOperationData.operationTitle = $r("app.string.chat_send_call");
    callOperationData.type = NEChatMoreOperationType.Call;
    callOperationData.imageSource = "app.media.ic_public_chat_call";
    operationMoreDataList.push(callOperationData);
  }

  // 翻译
  if (IMKitConfigCenter.enableAI && AIUserManager.getAITranslateUser()) {
    const translateOperationData = new NEChatMoreOperationData();
    translateOperationData.operationTitle = $r("app.string.chat_ai_translate_action");
    translateOperationData.type = NEChatMoreOperationType.Translate;
    translateOperationData.imageSource = "app.media.ic_chat_translate_action";
    operationMoreDataList.push(translateOperationData);
  }

  return operationMoreDataList
}

export function getOpenFileType(fileExt: string): string {
  const normalizedExt = fileExt.trim().toLowerCase()
  const dotIndex = normalizedExt.lastIndexOf('.')
  const ext = dotIndex >= 0 ? normalizedExt.substring(dotIndex + 1) : normalizedExt

  if (ext === 'txt') {
    return 'text/plain'
  } else if (ext === 'cpp') {
    return 'text/x-c++src'
  } else if (ext === 'c') {
    return 'text/x-csrc'
  } else if (ext === 'h') {
    return 'text/x-chdr'
  } else if (ext === 'java') {
    return 'text/x-java'
  } else if (ext === 'xhtml') {
    return 'application/xhtml+xml'
  } else if (ext === 'xml') {
    return 'text/xml'
  } else if (ext === 'html' || ext === 'htm') {
    return 'text/html'
  } else if (ext === 'pdf') {
    return 'application/pdf'
  } else if (ext === 'jpg' || ext === 'jpeg') {
    return 'image/jpeg'
  } else if (ext === 'png') {
    return 'image/png'
  } else if (ext === 'gif') {
    return 'image/gif'
  } else if (ext === 'webp') {
    return 'image/webp'
  } else if (ext === 'bmp') {
    return 'image/bmp'
  } else if (ext === 'svg') {
    return 'image/svg+xml'
  } else if (ext === 'heic' || ext === 'heif') {
    return 'image/heic'
  } else if (ext === 'm4a') {
    return 'audio/mp4a-latm'
  } else if (ext === 'mp3') {
    return 'audio/mpeg'
  } else if (ext === 'aac') {
    return 'audio/aac'
  } else if (ext === 'ogg') {
    return 'audio/ogg'
  } else if (ext === 'wav') {
    return 'audio/x-wav'
  } else if (ext === 'mp4') {
    return 'video/mp4'
  } else if (ext === 'mkv') {
    return 'video/x-matroska'
  } else if (ext === 'mov') {
    return 'video/quicktime'
  } else if (ext === 'avi') {
    return 'video/x-msvideo'
  } else if (ext === 'ts') {
    return 'video/mp2ts'
  } else if (ext === 'doc') {
    return 'application/msword'
  } else if (ext === 'docx') {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  } else if (ext === 'xls') {
    return 'application/vnd.ms-excel'
  } else if (ext === 'xlsx') {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  } else if (ext === 'ppt') {
    return 'application/vnd.ms-powerpoint'
  } else if (ext === 'pptx') {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  }
  return 'application/octet-stream'
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

export function getOperateMenu(operateMsg: NIMMessageInfo | undefined, topMsg?: NIMMessageInfo | undefined): MessageOperationItem[] {
  let operationMoreDataList: MessageOperationItem[] = []
  if (operateMsg?.isAIStreamInProgress()) {
    return []
  }
  let localExtension = operateMsg?.message.localExtension;
  if (localExtension == undefined || !localExtension.includes(ChatConst.revokeLocalKey)) {

    // 语音消息且发送成功时，在第一位添加播放模式切换选项
    if (operateMsg !== undefined &&
      operateMsg.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO &&
      operateMsg.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED) {
      let voicePlayModeItem = new MessageOperationItem()
      voicePlayModeItem.operationType = MessageOperationType.VoicePlayMode;
      if (IMKitConfigCenter.enableEarphoneMode) {
        voicePlayModeItem.operationText = $r('app.string.chat_message_action_voice_play_speaker');
        voicePlayModeItem.operationImage = $r('app.media.ic_chat_audio_speaker');
      } else {
        voicePlayModeItem.operationText = $r('app.string.chat_message_action_voice_play_earphone');
        voicePlayModeItem.operationImage = $r('app.media.ic_chat_audio_earphone');
      }
      operationMoreDataList.push(voicePlayModeItem)
    }

    // 文本消息和多行消息 (type=102) 都支持复制
    if (operateMsg !== undefined &&
      (operateMsg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT ||
        operateMsg.isMultiLineMsg)) {
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
          let forwardItem = new MessageOperationItem()
          forwardItem.operationType = MessageOperationType.Forward;
          forwardItem.operationText = $r('app.string.chat_operation_forward');
          forwardItem.operationImage = $r('app.media.ic_chat_menu_forward');
          operationMoreDataList.push(forwardItem);
        }

        // 仅当标记功能开启时显示标记选项
        if (IMKitConfigCenter.enablePin) {
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

    }

    operationMoreDataList.push(buildDeleteMenuItem());

    if (operateMsg !== undefined &&
      operateMsg.message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
      && isSupportMessage(operateMsg) && operateMsg.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL
      && systemDateTime.getTime() - operateMsg.message.createTime < ChatKitConfig.messageRevokeTimeLimit
      // Only show revoke for messages shown as mine
      && operateMsg.getDisplaySenderId() == ChatKitClient.getLoginUserId()) {

      let undoItem = new MessageOperationItem()
      undoItem.operationImage = $r('app.media.ic_chat_menu_revoke');
      undoItem.operationText = $r('app.string.chat_operation_undo');
      undoItem.operationType = MessageOperationType.Undo;
      operationMoreDataList.push(undoItem)
    }

    // 多选选项：发送中的消息不支持多选
    if (operateMsg !== undefined &&
      operateMsg.canOperateInMultiSelect()) {
      let selectItem = new MessageOperationItem()
      selectItem.operationType = MessageOperationType.Select;
      selectItem.operationText = $r('app.string.chat_operation_multi_select');
      selectItem.operationImage = $r('app.media.ic_chat_menu_multi_select');
      operationMoreDataList.push(selectItem);
    }

    // 仅当收藏功能开启时显示收藏选项
    if (IMKitConfigCenter.enableCollection &&
      operateMsg !== undefined &&
      operateMsg.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
      && isSupportMessage(operateMsg)
      && operateMsg.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
      let collectionItem = new MessageOperationItem()
      collectionItem.operationType = MessageOperationType.Collection;
      collectionItem.operationText = $r('app.string.chat_operation_collection');
      collectionItem.operationImage = $r('app.media.ic_chat_menu_collection');
      operationMoreDataList.push(collectionItem);
    }

    // 语音消息转文字选项：语音消息 + 发送成功 + 未转换过
    if (operateMsg !== undefined &&
      operateMsg.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO &&
      operateMsg.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED &&
      !operateMsg.voiceToText) {
      let voiceToTextItem = new MessageOperationItem()
      voiceToTextItem.operationType = MessageOperationType.VoiceToText;
      voiceToTextItem.operationText = $r('app.string.chat_message_voice_to_text');
      voiceToTextItem.operationImage = $r('app.media.ic_voice_to_text');
      operationMoreDataList.push(voiceToTextItem);
    }

    // 添加置顶/取消置顶菜单项
    const topItem = getTopStickyMenuItem(operateMsg, topMsg)
    if (topItem) {
      operationMoreDataList.push(topItem)
    }

    // 翻译
    if (operateMsg !== undefined &&
      operateMsg.isReceiveMessage() &&
      operateMsg.message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
      // Hide translate for revoke notices
      && !operateMsg.isRevokeMsg
      && (operateMsg.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT || operateMsg.isMultiLineMsg)
    ) {
      let translateItem = new MessageOperationItem()
      translateItem.operationType = MessageOperationType.Translate;
      translateItem.operationText = $r('app.string.chat_operation_translate');
      translateItem.operationImage = $r('app.media.ic_chat_menu_translate');
      operationMoreDataList.push(translateItem);
    }

    if (canShowAISearchForMessage(operateMsg)) {
      appendAISearchMenuItem(operationMoreDataList)
    }
  }

  return operationMoreDataList
}

function buildDeleteMenuItem(): MessageOperationItem {
  let deleteItem = new MessageOperationItem()
  deleteItem.operationType = MessageOperationType.Delete;
  deleteItem.operationText = $r('app.string.chat_operation_delete');
  deleteItem.operationImage = $r('app.media.ic_chat_menu_delete');
  return deleteItem
}

export function isAISearchEnabled(): boolean {
  return IMKitConfigCenter.enableAI && IMKitConfigCenter.enableAIWordSearch &&
    AIUserManager.getAISearchUser() !== undefined
}

export function canShowAISearchForMessage(msg: NIMMessageInfo | undefined): boolean {
  if (!msg) {
    return false
  }
  return isAISearchEnabled() && canShowAISearchForMessageType(msg.getMessageType(), msg.isMultiLineMsg)
}

export function appendAISearchMenuItem(items: MessageOperationItem[]): void {
  if (!isAISearchEnabled()) {
    return
  }
  let aiSearchItem = new MessageOperationItem()
  aiSearchItem.operationType = MessageOperationType.AISearch
  aiSearchItem.operationText = $r('app.string.chat_ai_search')
  aiSearchItem.operationImage = $r('app.media.ic_chat_ai_search')
  items.push(aiSearchItem)
}

export function getSelectedTextOperateMenu(text: string, allowAISearch: boolean = true): MessageOperationItem[] {
  const operationMoreDataList: MessageOperationItem[] = []
  if (text.length === 0) {
    return operationMoreDataList
  }

  let copyItem = new MessageOperationItem()
  copyItem.operationType = MessageOperationType.Copy
  copyItem.operationText = $r('app.string.chat_operation_copy')
  copyItem.operationImage = $r('app.media.ic_chat_menu_copy')
  operationMoreDataList.push(copyItem)

  if (allowAISearch) {
    appendAISearchMenuItem(operationMoreDataList)
  }
  return operationMoreDataList
}

export function getOperateMenuCount(msgInfo: NIMMessageInfo | undefined, topMsg?: NIMMessageInfo | undefined): number {
  return getOperateMenu(msgInfo, topMsg).length
}

export function getOperateMenuSize(msgInfo: NIMMessageInfo | undefined) {
  return getOperateMenuCount(msgInfo)
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

export function computeOperateViewWidthByCount(itemCount: number): number {
  return ChatConst.menuItemWidth * Math.min(itemCount, ChatConst.menuItemColumnNum)
}

export function computeOperateViewHeightByCount(itemCount: number): number {
  return ChatConst.menuItemHeight * (Math.ceil(itemCount / ChatConst.menuItemColumnNum))
}

export function getTranslationOperateMenu(): MessageOperationItem[] {
  const operationMoreDataList: MessageOperationItem[] = []

  let copyItem = new MessageOperationItem()
  copyItem.operationType = MessageOperationType.Copy
  copyItem.operationText = $r('app.string.chat_operation_copy')
  copyItem.operationImage = $r('app.media.ic_chat_menu_copy')
  operationMoreDataList.push(copyItem)

  let forwardItem = new MessageOperationItem()
  forwardItem.operationType = MessageOperationType.Forward
  forwardItem.operationText = $r('app.string.chat_operation_forward')
  forwardItem.operationImage = $r('app.media.ic_chat_menu_forward')
  operationMoreDataList.push(forwardItem)

  let hideItem = new MessageOperationItem()
  hideItem.operationType = MessageOperationType.HideTranslation
  hideItem.operationText = $r('app.string.chat_translation_action_hide')
  hideItem.operationImage = $r('app.media.ic_chat_menu_translate_hide')
  operationMoreDataList.push(hideItem)

  return operationMoreDataList
}

/**
 * 判断当前用户是否有消息置顶权限
 * @param team 当前群信息
 * @param memberRole 当前用户在群中的角色
 * @returns true=有权限
 */
export function havePermissionForTopSticky(team: V2NIMTeam | undefined,
  memberRole: V2NIMTeamMemberRole | undefined): boolean {
  if (!team) {
    return false
  }

  const permissionMode = getTopStickyPermissionMode(team.serverExtension, TeamRepo.isGroupTeam(team))
  return hasTopStickyPermission(permissionMode, memberRole)
}

/**
 * 获取置顶消息操作菜单项
 * @param operateMsg 当前操作的消息
 * @param topMessage 当前置顶消息（用于判断 置顶/取消置顶）
 * @returns 置顶菜单项（如果不满足条件返回 undefined）
 */
export function getTopStickyMenuItem(operateMsg: NIMMessageInfo | undefined,
  topMessage: NIMMessageInfo | undefined): MessageOperationItem | undefined {
  if (!operateMsg) {
    return undefined
  }

  // 仅群聊 + enableTopMessage 开启 + 消息发送成功
  if (!IMKitConfigCenter.enableTopMessage) {
    return undefined
  }
  if (operateMsg.message.conversationType !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
    return undefined
  }
  const errorCode = operateMsg.message.messageStatus?.errorCode
  // Keep messages shown as failed out of top sticky actions.
  if (operateMsg.message.sendingState !== V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED ||
    (errorCode !== undefined && errorCode !== 200) || operateMsg.isServerAntiSpam) {
    return undefined
  }

  let item = new MessageOperationItem()
  if (topMessage && topMessage.message.messageClientId === operateMsg.message.messageClientId) {
    // 当前消息就是已置顶消息 → 取消置顶
    item.operationType = MessageOperationType.UnTopSticky
    item.operationText = $r('app.string.chat_message_un_top_sticky')
    item.operationImage = $r('app.media.ic_chat_pop_untop_sticky')
  } else {
    // 置顶
    item.operationType = MessageOperationType.TopSticky
    item.operationText = $r('app.string.chat_message_top_sticky')
    item.operationImage = $r('app.media.ic_chat_pop_top_sticky')
  }
  return item
}
