/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NIMMessageInfo } from '../model/NIMMessageInfo';
import fs from '@ohos.file.fs';
import {
  V2NIMMessageAudioAttachment,
  V2NIMMessageCallAttachment,
  V2NIMMessageFileAttachment,
  V2NIMMessageImageAttachment,
  V2NIMMessageNotificationType,
  V2NIMMessageRevokeNotification,
  V2NIMMessageType,
  V2NIMMessageVideoAttachment
} from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService';
import {
  V2NIMConversationType,
  V2NIMMessageNotificationAttachment,
  V2NIMTeamChatBannedMode,
  V2NIMTeamInviteMode,
  V2NIMTeamUpdateInfoMode
} from '@nimsdk/base';
import { ChatKitClient, ChatRepo } from '@nimkit/chatkit';
import { JSONUtil } from '@nimkit/common';
import { systemDateTime } from '@kit.BasicServicesKit';
import { DeviceUtils } from './DeviceUtils';
import { FileUtils } from './FileUtils';
import { ChatConst } from '../constants/ChatConst';
import { DateUtils } from './DateUtils';
import { NEEmojiManager, NEEmojiParseResult } from '../manager/NEEmojiManager';
import { ChatInfo } from '../model/ChatInfo';

// 获取群通知消息内容
export function getNotificationMessageContent(messageInfo: NIMMessageInfo, chatUserInfo: ChatInfo): string {

  // 邀请通知
  if (messageInfo.message.attachment != null && messageInfo.message.attachment as V2NIMMessageNotificationAttachment) {
    let attachment = messageInfo.message.attachment as V2NIMMessageNotificationAttachment
    let fromAccount = messageInfo.message.senderId;
    if (fromAccount === ChatKitClient.getLoginUserId()) {
      fromAccount = getContext().resourceManager.getStringByNameSync('chat_team_notify_current_user_name')
    } else {
      fromAccount = chatUserInfo?.getChatUserShowName(messageInfo.message.senderId)
    }
    let targetName = '';
    attachment.targetIds?.forEach(element => {
      let name = ''
      if (element == ChatKitClient.getLoginUserId()) {
        name = getContext().resourceManager.getStringByNameSync('chat_team_notify_current_user_name')
      } else {
        name = chatUserInfo?.getChatUserShowName(element)
      }
      if (targetName.length > 0) {
        targetName = targetName + ','
      }
      targetName = targetName + name
    });

    if (attachment.type == V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_INVITE) {
      let inviteContent = getContext().resourceManager.getStringByNameSync('chat_team_notify_invite_title')
      let inviteJoin = getContext().resourceManager.getStringByNameSync('chat_team_notify_invite_join')
      return fromAccount + inviteContent.toString() + targetName + inviteJoin;
    } else if (attachment.type == V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_KICK) {
      let kickContent = getContext().resourceManager.getStringByNameSync('chat_team_notify_kick_title');
      return targetName + kickContent;
    } else if (attachment.type == V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_LEAVE) {
      let leaveContent = getContext().resourceManager.getStringByNameSync('chat_team_notify_leave_title');
      return fromAccount + leaveContent.toString();
    } else if (attachment.type == V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_DISMISS) {
      let leaveContent = getContext().resourceManager.getStringByNameSync('chat_team_notify_dismiss_title');
      return fromAccount + leaveContent;
    } else if (attachment.type == V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_UPDATE_TINFO) {
      let teamInfo = attachment.updatedTeamInfo
      let fromUser = chatUserInfo?.getChatUserShowName(fromAccount)
      let notifyContent = ''
      if (teamInfo?.name != undefined) {
        notifyContent = getContext().resourceManager.getStringByNameSync('chat_team_name_update') + teamInfo.name
      } else if (teamInfo?.announcement != undefined) {
        notifyContent = getContext().resourceManager.getStringByNameSync('chat_team_notice_update')
      } else if (teamInfo?.intro != undefined) {
        notifyContent = getContext().resourceManager.getStringByNameSync('chat_team_intro_update')
      } else if (teamInfo?.avatar != undefined) {
        notifyContent = getContext().resourceManager.getStringByNameSync('chat_team_avatar_update')
      } else if (teamInfo?.inviteMode != undefined) {
        notifyContent = getContext().resourceManager.getStringByNameSync('chat_team_invitation_permission_update')
        if (teamInfo.inviteMode === V2NIMTeamInviteMode.V2NIM_TEAM_INVITE_MODE_ALL) {
          notifyContent = notifyContent + getContext().resourceManager.getStringByNameSync('chat_team_permission_all')
        } else {
          notifyContent =
            notifyContent + getContext().resourceManager.getStringByNameSync('chat_team_permission_manager')
        }
      } else if (teamInfo?.updateInfoMode != undefined) {
        notifyContent = getContext().resourceManager.getStringByNameSync('chat_team_modify_resource_permission_update')
        if (teamInfo.updateInfoMode === V2NIMTeamUpdateInfoMode.V2NIM_TEAM_UPDATE_INFO_MODE_ALL) {
          notifyContent = notifyContent + getContext().resourceManager.getStringByNameSync('chat_team_permission_all')
        } else {
          notifyContent =
            notifyContent + getContext().resourceManager.getStringByNameSync('chat_team_permission_manager')
        }
      } else if (teamInfo?.chatBannedMode !== undefined) {
        fromUser = ''
        if (teamInfo.chatBannedMode == V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_UNBAN) {
          notifyContent = notifyContent + getContext().resourceManager.getStringByNameSync('chat_team_cancel_all_mute')
        } else {
          notifyContent = notifyContent + getContext().resourceManager.getStringByNameSync('chat_team_full_mute')
        }
      }
      return fromUser + notifyContent;
    }
  }
  return '';
}

// 保存撤回消息到本地
export function saveLocalRevokeMessage(conversationId: string, msg: NIMMessageInfo, edit: boolean) {
  let currentTime = systemDateTime.getTime()
  let revokeText = getContext().resourceManager.getStringByNameSync('chat_msg_undo_tips');
  let revokeMsg = ChatKitClient.nim.messageCreator.createTextMessage(revokeText)
  revokeMsg.serverExtension = msg.message.serverExtension
  let jsonData: Map<string, string> = new Map<string, string>()
  jsonData.set(ChatConst.revokeLocalKey, 'true')
  jsonData.set(ChatConst.revokeLocalTimeKey, currentTime.toString())
  jsonData.set(ChatConst.revokeMsgClientIdKey, msg.message.messageClientId)
  if (msg.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    jsonData.set(ChatConst.revokeMsgTextKey, msg.message.text ?? '')
    jsonData.set(ChatConst.revokeMsgEditKey, Boolean(edit).toString())
  }
  let jsonString = JSONUtil.toJSONString(jsonData)
  revokeMsg.localExtension = jsonString
  let createTime = msg.message.createTime + 10
  ChatRepo.saveLocalMessage(revokeMsg, conversationId, ChatKitClient.getLoginUserId(), createTime)
}

// 保存他人撤回消息到本地
export function saveLocalRevokeMessageFormOther(conversationId: string, msgNotify: V2NIMMessageRevokeNotification,
  edit: boolean) {
  let currentTime = systemDateTime.getTime()
  let revokeText = getContext().resourceManager.getStringByNameSync('chat_msg_undo_tips');
  let revokeMsg = ChatKitClient.nim.messageCreator.createTextMessage(revokeText)
  let jsonData = new Map<string, string>()
  jsonData.set(ChatConst.revokeLocalKey, 'false')
  jsonData.set(ChatConst.revokeLocalTimeKey, currentTime.toString())
  revokeMsg.localExtension = JSONUtil.toJSONString(jsonData);
  console.debug('netease saveLocalRevokeMessageFormOther:', revokeMsg.localExtension)
  let createTime = msgNotify.messageRefer.createTime + 10;
  ChatRepo.saveLocalMessage(revokeMsg, conversationId, msgNotify.revokeAccountId, createTime)
}

// 获取消息高度，单位为VP
export function getMessageHeight(uicontext: UIContext, messageInfo: NIMMessageInfo | undefined): number {
  let messageHeight = ChatConst.messageLineHeight;
  if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    // 文本消息体最大宽度，单位为VP
    let lineWidth = DeviceUtils.getMessageLineWidth();
    let textSize = uicontext.getMeasureUtils().measureTextSize({
      textContent: translateEmojiText(messageInfo?.message.text ?? ''),
      fontSize: ChatConst.messageTextFontSize,
      constraintWidth: px2vp(lineWidth),
      lineHeight: ChatConst.textLineHeight
    });
    let viewHeight = px2vp(textSize.height as number) + (ChatConst.messageLineHeight - ChatConst.textLineHeight)
    messageHeight = viewHeight
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
    messageHeight = ChatConst.mapMessageHeight;
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE ||
    messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
    messageHeight = getImageHeight(messageInfo);
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
    messageHeight = ChatConst.fileMessageWidth;
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
    messageHeight = ChatConst.messageLineHeight;
  }
  // 群消息需要展示发送者昵称，所有高度增加
  if (messageInfo?.message.conversationType !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P
    && messageInfo?.isReceiveMessage()) {
    messageHeight = messageHeight + ChatConst.textLineHeight;
  }

  // 需要展示发送消息时间的，高度增加
  if (messageInfo?.getMessageTime() != null) {
    messageHeight = messageHeight + 10
  }
  return messageHeight;
}

// 获取消息高度，单位为VP
export function measureTextHeight(uicontext: UIContext, text: string, maxLines: number): number {
  let messageHeight = ChatConst.messageLineHeight;
  // 文本消息体最大宽度，单位为VP
  let lineWidth = DeviceUtils.getMessageLineWidth();
  let textSize = uicontext.getMeasureUtils().measureTextSize({
    textContent: text,
    fontSize: ChatConst.messageTextFontSize,
    constraintWidth: px2vp(lineWidth),
    lineHeight: ChatConst.textLineHeight,
    maxLines: maxLines
  });
  let viewHeight = px2vp(textSize.height as number) + (ChatConst.messageLineHeight - ChatConst.textLineHeight)
  messageHeight = viewHeight
  return messageHeight;
}

// 将文本消息中的EMoji表情进行转换，将表情文案裁剪，保证裁剪之后的文本计算的宽度符合实际表情展示
// [惊讶] 转换成表情之后，实际宽度要少，所以按照测试，‘[惊讶][高兴]’ 转换为 ‘[惊高’ 计算高度满足表情图片高度
export function translateEmojiText(text: string): string {
  let inputString = text;
  let resultText = ''
  const pattern = /\[([^\]]+)\]/g;
  let finish = false;
  let lastMatchIndex = 0;
  let emojiLength = 0;
  while (finish == false) {
    let match = pattern.exec(inputString)
    if (match !== null) {
      let tag = match[0];
      emojiLength++;
      if (emojiLength >= 2) {
        emojiLength = 0;
        resultText = resultText + inputString.substring(lastMatchIndex, match.index) + tag.substring(1, 2);
      } else {
        resultText = resultText + inputString.substring(lastMatchIndex, match.index) + tag.substring(0, 2);
      }
      lastMatchIndex = match.index + match[0].length;
    } else {
      finish = true;
      resultText = resultText + inputString.substring(lastMatchIndex, inputString.length);
    }
  }
  return resultText;
}

// 根据图片消息的尺寸，计算展示的宽度，单位为VP
export function getImageWidth(messageInfo: NIMMessageInfo): number {
  if (messageInfo.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
    let imageAttachment = messageInfo.message.attachment as V2NIMMessageImageAttachment;
    if (imageAttachment && imageAttachment.width) {
      return Math.min(imageAttachment.width, ChatConst.imageMessageWidth);
    }
  } else if (messageInfo.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
    let videoAttachment = messageInfo.message.attachment as V2NIMMessageImageAttachment;
    if (videoAttachment && videoAttachment.width) {
      return Math.min(videoAttachment.width, ChatConst.imageMessageWidth);
    }
  }
  return ChatConst.imageMessageWidth;
}

// 根据图片消息的尺寸，计算展示的高度，单位为VP
export function getImageHeight(messageInfo: NIMMessageInfo): number {
  if (messageInfo.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
    let imageAttachment = messageInfo.message.attachment as V2NIMMessageImageAttachment;
    if (imageAttachment && imageAttachment.height) {
      if (imageAttachment.width >= ChatConst.imageMessageWidth) {
        return ChatConst.imageMessageWidth * imageAttachment.height / imageAttachment.width
      }
      return imageAttachment.height;
    }
  } else if (messageInfo.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
    let videoAttachment = messageInfo.message.attachment as V2NIMMessageImageAttachment;
    if (videoAttachment && videoAttachment.height) {
      if (videoAttachment.width >= ChatConst.imageMessageWidth) {
        return ChatConst.imageMessageWidth * videoAttachment.height / videoAttachment.width
      }
      return videoAttachment.height;
    }
  }
  return ChatConst.imageMessageHeight;
}

// 获取语音消息的展示图标，根据语音消息的发送或者接受展示不同的图标
export function getAudioMessageIcon(messageInfo: NIMMessageInfo): Resource {
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
    if (messageInfo.isReceiveMessage()) {
      return $r('app.media.ic_chat_audio_receive')
    }
  }
  return $r('app.media.ic_chat_audio_send')
}

// 获取语音消息的展示时间，根据语音消息的长度计算，单位为秒
export function getAudioMessageText(messageInfo: NIMMessageInfo): string {
  let result = 0;
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
    let audioAttachment = messageInfo.message.attachment as V2NIMMessageAudioAttachment;
    if (audioAttachment != null) {
      let duration = audioAttachment.duration != null ? audioAttachment.duration : 0;
      result = Math.floor(duration / 1000);
    }
  }
  return result + " s"
}

// 计算语音消息的宽度，根据语音消息的长度计算
// 最长230
export function getAudioMessageWidth(messageInfo: NIMMessageInfo): number {
  let result = 58;
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
    let audioAttachment = messageInfo.message.attachment as V2NIMMessageAudioAttachment;
    if (audioAttachment != null) {
      let duration = audioAttachment.duration != null ? audioAttachment.duration : 0;
      result += duration / 100;
    }
  }
  if (result > 230) {
    result = 230;
  }
  return result;
}

// 文件消息展示图标，根据文件消息类型展示不同的图标
export function getFileMessageIcon(messageInfo: NIMMessageInfo): Resource {
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
    let fileAttachment = messageInfo.message.attachment as V2NIMMessageFileAttachment;
    let fileIcon = $r('app.media.ic_chat_file_unknown')
    let fileType = fileAttachment.ext
    if (fileType == undefined) {
      fileType = FileUtils.getFileExtension(fileAttachment.name ?? '')
    }

    if (fileType !== undefined) {
      if (fileType.includes('doc')) {
        fileIcon = $r('app.media.ic_chat_file_word')
      } else if (fileType.includes('xls') || fileType.includes('xlsx') || fileType.includes('csv')) {
        fileIcon = $r('app.media.ic_chat_file_excel')
      } else if (fileType.includes('ppt')) {
        fileIcon = $r('app.media.ic_chat_file_ppt')
      } else if (fileType.includes('jpg') || fileType.includes('png') || fileType.includes('jpeg')
        || fileType.includes('tiff') || fileType.includes('gif')) {
        fileIcon = $r('app.media.ic_chat_file_image')
      } else if (fileType.includes('zip') || fileType.includes('7z') || fileType.includes('tar')
        || fileType.includes('rar')) {
        fileIcon = $r('app.media.ic_chat_file_rar')
      } else if (fileType.includes('pdf') || fileType.includes('rtf')) {
        fileIcon = $r('app.media.ic_chat_file_ppt')
      } else if (fileType.includes('mp4') || fileType.includes('avi') || fileType.includes('wmv')
        || fileType.includes('mov') || fileType.includes('asf') || fileType.includes('flv') || fileType.includes('f4v')
        || fileType.includes('rmvb') || fileType.includes('rm') || fileType.includes('3gp')) {
        fileIcon = $r('app.media.ic_chat_file_video')
      } else if (fileType.includes('mp3') || fileType.includes('aac') || fileType.includes('wav')
        || fileType.includes('wma') || fileType.includes('flac')) {
        fileIcon = $r('app.media.ic_chat_file_mp3')
      } else if (fileType.includes('jpg') || fileType.includes('png') || fileType.includes('jpeg')
        || fileType.includes('tiff') || fileType.includes('gif')) {
        fileIcon = $r('app.media.ic_chat_file_image')
      } else if (fileType.includes('txt')) {
        fileIcon = $r('app.media.ic_chat_file_txt')
      } else {
        fileIcon = $r('app.media.ic_chat_file_other')
      }
    }

    return fileIcon
  }
  return $r('app.media.ic_chat_file_other')
}

// 获取文件消息，发送文件名称
export function getFileMessageName(messageInfo: NIMMessageInfo): string {
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
    let fileAttachment = messageInfo.message.attachment as V2NIMMessageFileAttachment;
    if (fileAttachment != null) {
      return fileAttachment.name != null ? fileAttachment.name : ''
    }
  }
  return '';
}

// 计算文件消息的大小
export function getFileMessageSize(messageInfo: NIMMessageInfo): string {
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
    let fileAttachment = messageInfo.message.attachment as V2NIMMessageFileAttachment;
    if (fileAttachment != null) {
      let size = fileAttachment.size != null ? fileAttachment.size : 0;
      return FileUtils.formatFileSize(size)
    }
  }
  return '';
}

// 计算文件消息的大小
export function getCallMessageText(messageInfo: NIMMessageInfo): string | Resource {
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
    let callAttachment = messageInfo.message.attachment as V2NIMMessageCallAttachment;
    if (callAttachment != null) {
      let status = callAttachment.status;
      if (status == 1) {
        let durations = callAttachment.durations
        if (durations.length > 0) {
          let time = durations[0].duration
          let timeStr = DateUtils.formatCallTime(time)
          return getContext().resourceManager.getStringByNameSync('chat_msg_call_completed') + timeStr
        }
        return $r('app.string.chat_msg_call_completed')
      } else if (status == 2) {
        return $r('app.string.chat_msg_call_canceled')
      } else if (status == 3) {
        return $r('app.string.chat_msg_call_refused')
      } else if (status == 4) {
        return $r('app.string.chat_msg_call_timeout')
      } else if (status == 5) {
        return $r('app.string.chat_msg_call_busy')
      }
    }
  }
  return $r('app.string.chat_msg_call_completed');
}

// 计算文件消息的大小
export function getCallMessageIcon(messageInfo: NIMMessageInfo): Resource {
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
    let callAttachment = messageInfo.message.attachment as V2NIMMessageCallAttachment;
    if (callAttachment != null) {
      let type = callAttachment.type;
      if (type == 2) {
        return $r('app.media.ic_chat_call_video')
      } else {
        return $r('app.media.ic_chat_call_audio')
      }
    }
  }
  return $r('app.media.ic_chat_call_audio');
}

export function parseMessageText(messageInfo: NIMMessageInfo): Array<NEEmojiParseResult> | undefined {
  let text = messageInfo?.message.text?.trimStart().trimEnd();
  let result: Array<NEEmojiParseResult> | undefined = undefined
  if (text !== undefined) {
    result = NEEmojiManager.instance.parseEmojiText(text);
  }

  return result;
}

export function getVideoMessageUrl(messageInfo: NIMMessageInfo): string {
  let urlResult = ''
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
    let videoAttachment = messageInfo.message.attachment as V2NIMMessageVideoAttachment;
    if (videoAttachment != null) {
      urlResult = makeVideoThumbUrl(videoAttachment.url);
    }
  }
  console.debug('netease getVideoMessageUrl:', urlResult)
  return urlResult
}

export function makeVideoThumbUrl(url: string | undefined): string {
  if (url === undefined) {
    return '';
  }
  const connectChar: string = url.includes("?") ? "&" : "?";
  return url + connectChar + 'vframe=1';
}

export function getMessageAttachmentPath(msg: NIMMessageInfo): string {
  let filePath = '';
  if (msg.message.attachment as V2NIMMessageFileAttachment) {
    let fileAttachment = msg.message.attachment as V2NIMMessageFileAttachment;
    if (fileAttachment.path !== undefined) {
      filePath = fileAttachment.path;
    } else {
      let subDir = ''
      if (msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
        subDir = '/image/'
      } else if (msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
        subDir = '/video/'
      } else if (msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
        subDir = '/file/'
      } else if (msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
        subDir = '/audio/'
      }
      let fileExt = fileAttachment.ext
      if (fileExt !== undefined && !fileExt.startsWith('.')) {
        fileExt = '.' + fileExt
      }
      let dirPath = DeviceUtils.rootDirPath + subDir
      fs.mkdir(dirPath)
      filePath = DeviceUtils.rootDirPath + subDir + msg.message.messageClientId + fileExt
    }
  }
  console.debug('netease getMessageAttachmentPath:', filePath)
  return filePath;
}


export function getFileMessageAttachmentName(msg: NIMMessageInfo): string {
  let fileName = '';
  if (msg.message.attachment as V2NIMMessageFileAttachment) {
    let fileAttachment = msg.message.attachment as V2NIMMessageFileAttachment;
    fileName = fileAttachment.name ?? ''
  }
  console.debug('netease getFileMessageAttachmentName:', fileName)
  return fileName;
}

export function getFileMessageAttachmentExt(msg: NIMMessageInfo): string {
  let fileExt = '';
  if (msg.message.attachment as V2NIMMessageFileAttachment) {
    let fileAttachment = msg.message.attachment as V2NIMMessageFileAttachment;
    fileExt = fileAttachment.ext ?? ''
    if (fileExt !== undefined && !fileExt.startsWith('.')) {
      fileExt = '.' + fileExt
    }
  }
  console.debug('netease getFileMessageAttachmentExt:', fileExt)
  return fileExt;
}