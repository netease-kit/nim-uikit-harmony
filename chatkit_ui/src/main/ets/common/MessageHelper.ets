/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NIMMessageInfo } from '../model/NIMMessageInfo';
import Hash from '@ohos.file.hash';
import fs from '@ohos.file.fs';
import {
  V2NIMMessage,
  V2NIMMessageAudioAttachment,
  V2NIMMessageCallAttachment,
  V2NIMMessageFileAttachment,
  V2NIMMessageImageAttachment,
  V2NIMMessageNotificationType,
  V2NIMMessageType,
  V2NIMMessageVideoAttachment
} from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService';
import {
  IM_ELITE_SDK_VERSION_HUMAN,
  V2NIMConversationType,
  V2NIMMessageNotificationAttachment,
  V2NIMMessageSendingState,
  V2NIMTeamChatBannedMode,
  V2NIMTeamInviteMode,
  V2NIMTeamUpdateInfoMode
} from '@nimsdk/base';
import {
  aitKey,
  ChatKitClient,
  ChatRepo,
  CustomMessageUtils,
  errCodeInBlock,
  errCodeNoFriend,
  getAitModelFromJson,
  keyExtensionAtAll,
  keyExtensionLastOptType,
  keyReplyMsgKey,
  MergedMessageAttachment,
  mergedMessageAvatarKey,
  mergedMessageCustomType,
  mergedMessageNickKey,
  multiForwardFileName,
  StorageRepo,
  typeExtensionAllowAll
} from '@nimkit/chatkit';
import { DeviceUtils } from './DeviceUtils';
import { FileUtils } from './FileUtils';
import { ChatConst } from '../constants/ChatConst';
import { DateUtils } from './DateUtils';
import { NEEmojiManager, NEEmojiParseResult } from '../manager/NEEmojiManager';
import { ChatInfo } from '../model/ChatInfo';
import { JSON } from '@kit.ArkTS';
import { ImagesIndexModel, NECommonUtils } from '@nimkit/common';
import { fileUri } from '@kit.CoreFileKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { isCharacterEmoji, isLastCharacterEmoji, openFileWithApp, sliceContent } from '../common/ChatUtils';
import { ChatAitNode } from '../model/ChatAitNode';
import { media } from '@kit.MediaKit';

// 获取群通知消息内容
export function getNotificationMessageContent(messageInfo: NIMMessageInfo, chatUserInfo: ChatInfo): string {

  // 邀请通知
  if (messageInfo.message.attachment != null && messageInfo.message.attachment as V2NIMMessageNotificationAttachment) {
    let attachment = messageInfo.message.attachment as V2NIMMessageNotificationAttachment
    let fromAccount = messageInfo.message.senderId;
    if (fromAccount === ChatKitClient.getLoginUserId()) {
      fromAccount = getContext().resourceManager.getStringByNameSync('chat_current_user_name')
    } else {
      fromAccount = chatUserInfo?.getChatUserShowName(messageInfo.message.senderId)
    }
    let targetName = '';
    attachment.targetIds?.forEach(element => {
      let name = ''
      if (element == ChatKitClient.getLoginUserId()) {
        name = getContext().resourceManager.getStringByNameSync('chat_current_user_name')
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
      } else if (teamInfo?.serverExtension !== undefined) {
        let extensionObj = JSON.parse(teamInfo.serverExtension) as object | null
        if (extensionObj != null && extensionObj[keyExtensionLastOptType] == keyExtensionAtAll) {
          if (extensionObj[keyExtensionAtAll] === typeExtensionAllowAll) {
            notifyContent = getContext().resourceManager.getStringByNameSync('chat_team_at_permission_all_tips')
          } else {
            notifyContent = getContext().resourceManager.getStringByNameSync('chat_team_at_permission_manager_tips')
          }
        }

      }
      return fromUser + notifyContent;
    } else if (attachment.type == V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_ADD_MANAGER) {
      return targetName + getContext().resourceManager.getStringByNameSync('chat_team_appoint_manager');
    } else if (attachment.type == V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_REMOVE_MANAGER) {
      return targetName + getContext().resourceManager.getStringByNameSync('chat_team_removed_manager');
    }
  }
  return '';
}

export function getPinMessagesTips(messageInfo: NIMMessageInfo, chatUserInfo: ChatInfo | undefined): string {
  let targetName = ''
  if (messageInfo.pinInfo != null) {
    if (messageInfo.pinInfo.operatorId == ChatKitClient.getLoginUserId()) {
      targetName = getContext().resourceManager.getStringByNameSync('chat_current_user_name')
    } else if (chatUserInfo !== undefined) {
      targetName = chatUserInfo?.getChatUserShowName(messageInfo.pinInfo?.operatorId)
    }
    if (targetName.length > ChatConst.pinOperatorNameMaxLen) {
      let targetIndex = ChatConst.pinOperatorNameMaxLen - 1
      if (!isLastCharacterEmoji(targetName.charAt(targetIndex))) {
        targetIndex++
      }
      targetName = targetName.substring(0, targetIndex + 1) + '...'
    }
  }

  return getContext().resourceManager.getStringByNameSync('chat_pin_message_tips', targetName);
}

// 获取消息高度，单位为VP
export function measureMessageHeight(uicontext: UIContext, messageInfo: NIMMessageInfo | undefined): number {
  let messageHeight = ChatConst.messageLineHeight;
  if (messageInfo?.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    // 文本消息体最大宽度，单位为VP
    let lineWidth = DeviceUtils.getMessageLineWidth();
    let textSize = uicontext.getMeasureUtils().measureTextSize({
      textContent: translateEmojiText(messageInfo?.message.text ?? ''),
      fontSize: ChatConst.messageTextFontSize,
      constraintWidth: px2vp(lineWidth),
      lineHeight: ChatConst.textLineHeight
    });
    console.debug('netease measureMessageHeight text', messageInfo.message.text)
    console.debug('netease measureMessageHeight', 'linewidth:', lineWidth, ',', px2vp(lineWidth), 'textHeight',
      textSize.height as number, ',,', px2vp(textSize.height as number))
    messageHeight = px2vp(textSize.height as number)
    if (messageHeight < ChatConst.textLineHeight) {
      messageHeight = ChatConst.textLineHeight
    }
    messageHeight = messageHeight + (ChatConst.messageLineHeight - ChatConst.textLineHeight)
    if (messageInfo.isReplyMsg) {
      messageHeight = messageHeight + ChatConst.textLineHeight;
    }
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
    messageHeight = ChatConst.mapMessageHeight;
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE ||
    messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
    messageHeight = getImageHeight(messageInfo);
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
    messageHeight = ChatConst.fileMessageWidth;
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
    messageHeight = ChatConst.messageLineHeight;
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
    messageHeight = ChatConst.messageLineHeight;
  } else if (messageInfo?.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
    if (messageInfo.isMergeMsg) {
      // 文本消息体最大宽度，单位为VP
      // 文本消息体最大宽度，单位为VP
      let lineWidth = DeviceUtils.getMessageLineWidth();
      let textSize = uicontext.getMeasureUtils().measureTextSize({
        textContent: messageInfo.mergedContent,
        fontSize: ChatConst.messageTextFontSize,
        constraintWidth: px2vp(lineWidth),
        lineHeight: ChatConst.textLineHeight,
      });
      let viewHeight = px2vp(textSize.height as number) + ChatConst.mergedMessageMinHeight
      if (viewHeight > ChatConst.mergedMessageHeight) {
        viewHeight = ChatConst.mergedMessageHeight
      }
      messageHeight = viewHeight
    }
  }
  // 群消息需要展示发送者昵称，所有高度增加
  // if (messageInfo?.message.conversationType !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P
  //   && (messageInfo?.isMergeDetailMsg || messageInfo?.isReceiveMessage())) {
  //   messageHeight = messageHeight + ChatConst.textLineHeight;
  // }

  // 需要展示发送消息时间的，高度增加
  // if (messageInfo?.getMessageTime() != null) {
  //   messageHeight = messageHeight + 10
  // }

  // if (messageInfo?.isPinMsg) {
  //   messageHeight = messageHeight + 30
  // }
  return messageHeight;
}

// 获取消息高度，单位为VP
export function getPinMessageHeight(uicontext: UIContext, messageInfo: NIMMessageInfo | undefined): number {
  let messageHeight = ChatConst.messageLineHeight;
  if (messageInfo?.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    // 文本消息体最大宽度，单位为VP
    let lineWidth = DeviceUtils.getPinMessageLineWidth()
    let textSize = uicontext.getMeasureUtils().measureTextSize({
      textContent: translateEmojiText(messageInfo?.message.text ?? ''),
      fontSize: ChatConst.messageTextFontSize,
      constraintWidth: px2vp(lineWidth),
      lineHeight: ChatConst.textLineHeight
    });
    let viewHeight = px2vp(textSize.height as number)
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
  // if (messageInfo?.getMessageTime() != null) {
  //   messageHeight = messageHeight + 10
  // }
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
  });
  let viewHeight = px2vp(textSize.height as number) + (ChatConst.messageLineHeight - ChatConst.textLineHeight)
  messageHeight = viewHeight
  return messageHeight;
}

// 将文本消息中的Emoji表情进行转换，将表情文案裁剪，保证裁剪之后的文本计算的宽度符合实际表情展示
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
  if (messageInfo.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
    let callAttachment = messageInfo.message.attachment as V2NIMMessageCallAttachment;
    if (callAttachment.type === 2) {
      return $r('app.media.ic_chat_call_video')
    } else {
      return $r('app.media.ic_chat_call_audio')
    }
  }
  return $r('app.media.ic_chat_call_audio');
}

export function parseMessageText(text?: string): Array<NEEmojiParseResult> | undefined {
  let result: Array<NEEmojiParseResult> | undefined = undefined
  if (text !== undefined) {
    result = NEEmojiManager.instance.parseEmojiText(text);
  }

  return result;
}

/**
 * 获取@标识
 * @param startIndex
 * @param text
 * @param extension
 * @returns
 */
export function getAitNodes(startIndex: number, text: string, extension?: string): ChatAitNode[] {
  let segments: ChatAitNode[] = []
  let aitModel = getAitModelFromJson(extension)
  if (aitModel) {
    aitModel.aitBlocks.forEach((value, key) => {
      if (value.segments) {
        for (let segment of value.segments) {
          if (segment.start >= startIndex
            && segment.start < startIndex + text.length) {
            let node: ChatAitNode = {
              text: value.text,
              segment: segment,
              account: key
            }
            segments.push(...[node])
          }
        }
      }
    })
  }
  let aitNodes: ChatAitNode[] = []
  if (segments.length > 0) {
    segments.sort((a, b) => (a.segment?.start ?? 0) - (b.segment?.start ?? 0))
    let lastStartIndex = startIndex
    let endIndex = 0
    for (let index = 0; index < segments.length; index++) {
      let segment = segments[index]
      if (lastStartIndex < (segment.segment?.start ?? 0)) {
        let textNode: ChatAitNode = {
          text: text.substring(lastStartIndex - startIndex, (segment.segment?.start ?? 0) - startIndex)
        }
        aitNodes.push(...[textNode])
      }
      aitNodes.push(...[segment])
      lastStartIndex = (segment.segment?.end ?? lastStartIndex) + 1
      endIndex = segment.segment?.end ?? 0
    }
    //添加最后非@的Text
    if (endIndex < startIndex + text.length) {
      let textNode: ChatAitNode = {
        text: text.substring(endIndex - startIndex)
      }
      aitNodes.push(...[textNode])
    }
  } else {
    let textNode: ChatAitNode = {
      text: text
    }
    aitNodes.push(...[textNode])
  }
  return aitNodes
}

export function parseText(msgText: string): Array<NEEmojiParseResult> | undefined {
  let text = msgText?.trimStart().trimEnd();
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

// 获取本地视频消息首帧
export async function getVideoMessageThumbnail(messageInfo: NIMMessageInfo) {
  if (messageInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
    let videoAttachment = messageInfo.message.attachment as V2NIMMessageVideoAttachment;
    if (videoAttachment != null) {
      if (videoAttachment.path !== undefined) {
        if (fs.accessSync(videoAttachment.path)) {
          const uri = fileUri.getUriFromPath(videoAttachment.path)
          // 打开文件
          let file = fs.openSync(uri)

          // 创建AVImageGenerator对象
          let avImageGenerator: media.AVImageGenerator = await media.createAVImageGenerator()
          // 设置fdSrc
          avImageGenerator.fdSrc = file

          // 初始化入参
          let timeUs = 0
          let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC

          // 获取缩略图（promise模式）
          let pixelMap = await avImageGenerator.fetchFrameByTime(timeUs, queryOption, {
            width: videoAttachment.width,
            height: videoAttachment.height
          })

          // 释放资源（promise模式）
          avImageGenerator.release()
          fs.closeSync(file);

          return pixelMap
        }
      }
    }
  }
  return undefined
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

// 移除消息扩展字段中的 回复、@
/// - Parameter forwardMessage: 消息
export function clearForwardAtMark(forwardMessage: V2NIMMessage) {
  // 回复 thread 方案
  if (forwardMessage.threadReply) {
    forwardMessage.threadReply = undefined
  }

  if (forwardMessage.serverExtension) {
    try {
      let remoteExt = JSON.parse(forwardMessage.serverExtension) as object
      if (remoteExt) {
        remoteExt[aitKey] = undefined
        remoteExt[keyReplyMsgKey] = undefined
      }
      forwardMessage.serverExtension = JSON.stringify(remoteExt)
    } catch (err) {
      console.error(err)
    }
  }
}

/// 获取消息外显文案
/// - Parameter message: 消息
/// - Returns: 外显文案
function contentOfMessage(message: V2NIMMessage): string {
  const resourceManager = getContext().resourceManager
  switch (message.messageType) {
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT:
      return message.text ?? ''
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE:
      return resourceManager.getStringSync($r('app.string.imageMessageType').id)
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO:
      return resourceManager.getStringSync($r('app.string.audioMessageType').id)
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO:
      return resourceManager.getStringSync($r('app.string.videoMessageType').id)
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION:
      return resourceManager.getStringSync($r('app.string.locationMessageType').id)
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE:
      return resourceManager.getStringSync($r('app.string.fileMessageType').id)
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION:
      return resourceManager.getStringSync($r('app.string.notificationMessageType').id)
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_TIPS:
      return resourceManager.getStringSync($r('app.string.tipMessageType').id)
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL:
      if (message.attachment) {
        const messageAttachment = message.attachment as V2NIMMessageCallAttachment
        if (messageAttachment.type == 1) {
          return resourceManager.getStringSync($r('app.string.msg_type_rtc_audio').id)
        } else {
          return resourceManager.getStringSync($r('app.string.msg_type_rtc_video').id)
        }
      }
    case V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM:
      if (message.attachment) {
        let type = CustomMessageUtils.typeOfCustomMessage(message.attachment)
        if (type === mergedMessageCustomType) {
          return '[' + resourceManager.getStringSync($r('app.string.chatHistoryBrief').id) + ']'
        }
      }
      return resourceManager.getStringSync($r('app.string.chat_msg_unknown_type').id)
  }
  return message.text ?? resourceManager.getStringSync($r('app.string.chatMessageNonsupportType').id)
}

/**
 * 序列化文件的头部，占一行
 *
 * @param version 文件格式版本
 * @param message_count 消息数目
 * @return 头部字符串
 */
function buildHeader(version: number, messageCount: number): string {
  const obj: Record<string, Object> = {};
  obj['version'] = version
  obj['terminal'] = 3
  obj['sdk_version'] = IM_ELITE_SDK_VERSION_HUMAN
  obj['message_count'] = messageCount
  return JSON.stringify(obj);
}

/**
 * 把需要进行上传的数据 按照约定的“数据字段字典”转换后的json格式字符串，每条记录一行，存储在文本文件中，并从第二行开始存储(因为第一行存的是head信息)
 *
 * @param msgList 要合并的消息列表
 * @return 合并后的字符串
 */
function buildBody(msgList: V2NIMMessage[], chatInfo: ChatInfo): [string, Record<string, Object>[]] {
  // 分隔符
  const enter = "\n";
  if (msgList.length === 0) {
    return ["", []];
  }
  // 序列化结果
  let stringBuilder = "";
  // 摘要信息
  const abstracts: Record<string, Object>[] = [];

  for (let index = 0; index < msgList.length; index++) {
    const msg = msgList[index];
    // 移除扩展字段中的 回复、@ 信息
    let oldRemoteExt = msg.serverExtension
    clearForwardAtMark(msg)

    // 保存消息昵称和头像
    let senderNick = chatInfo.getChatUserShowName(msg.senderId, false, false) // 昵称不取备注和群昵称
    if (msg.serverExtension) {
      let remoteExt = JSON.parse(msg.serverExtension) as object
      if (remoteExt) {
        remoteExt[mergedMessageNickKey] = senderNick
        remoteExt[mergedMessageAvatarKey] =
          chatInfo.getChatUserAvatarUrl(msg.senderId) ?? chatInfo.getChatUserAvatarName(msg.senderId)
        msg.serverExtension = JSON.stringify(remoteExt)
      }
    } else {
      const remoteExt: Record<string, Object> = {};
      remoteExt[mergedMessageNickKey] = senderNick
      remoteExt[mergedMessageAvatarKey] =
        chatInfo.getChatUserAvatarUrl(msg.senderId) ?? chatInfo.getChatUserAvatarName(msg.senderId)
      msg.serverExtension = JSON.stringify(remoteExt)
    }

    // 摘要信息
    if (index < 3) {
      let content = contentOfMessage(msg)
      abstracts.push({
        "senderNick": senderNick,
        "content": content,
        "userAccId": msg.senderId
      })
    }

    stringBuilder += enter + ChatKitClient.nim.messageConverter.messageSerialization(msg)

    // 恢复扩展字段中的 回复、@ 信息
    msg.serverExtension = oldRemoteExt
  }
  return [stringBuilder.substring(enter.length), abstracts];
}

/**
 * 创建合并转发消息体内容
 *
 * @param messages
 * @return
 */
export async function createForwardMessageListFileDetail(messages: V2NIMMessage[], chatInfo: ChatInfo,
  depth: number): Promise<V2NIMMessage | undefined> {
  if (!messages || messages.length === 0) {
    return undefined;
  }
  const conversationId = messages[0].conversationId;
  if (!conversationId) {
    return undefined;
  }
  const msgList: V2NIMMessage[] = [];
  for (const msg of messages) {
    if (conversationId !== msg.conversationId) {
      continue;
    }
    if (
      msg.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION ||
        msg.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AVCHAT ||
        msg.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_ROBOT
    ) {
      continue;
    }
    msgList.push(msg);
  }

  let multiForwardMsg = buildHeader(0, msgList.length) + "\n" + buildBody(msgList, chatInfo)[0];
  let data = systemDateTime.getTime()
  let fileName = multiForwardFileName + '_' + data
  let cacheDir = getContext().cacheDir
  let filePath = cacheDir + "/" + fileName

  try {
    // 新建并打开文件
    let file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    // 写入一段内容至文件
    fs.writeSync(file.fd, multiForwardMsg);
    // 关闭文件
    fs.closeSync(file);

    // 上传文件
    let fileTask = StorageRepo.createUploadFileTask({
      filePath: filePath,
      sceneName: "nim_default_im"
    })

    if (fileTask) {
      const data: Record<string, Object> = {}
      const url = await StorageRepo.uploadFile(fileTask, () => {
      })
      if (url) {
        data["url"] = url
      }
      if (fs.accessSync(filePath)) {
        const md5 = await Hash.hash(filePath, "md5")
        data["md5"] = md5.toLowerCase()
      }
      data["sessionId"] = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(chatInfo.conversationId)
      data["depth"] = depth
      data["abstracts"] = buildBody(msgList, chatInfo)[1]
      if (chatInfo.conversationName) {
        data["sessionName"] = chatInfo.conversationName
      }

      const jsonData: Record<string, Object> = {}
      jsonData["data"] = data
      jsonData["messageType"] = "custom"
      jsonData["type"] = mergedMessageCustomType

      let text = `[${getContext().resourceManager.getStringByNameSync('chatHistoryBrief')}]`
      let rawAttach = JSON.stringify(jsonData)
      let mergeMessage = ChatRepo.createCustomMessage(text, rawAttach)
      return mergeMessage
    }
    return undefined
  } catch (err) {
    console.error(err)
    NECommonUtils.showToast($r('app.string.chat_multi_forward_failed'))
    return undefined
  }
}

/*
  获取消息的视频 url，用于视频查看器
 */
export function getMessageVideoUrl(msg: NIMMessageInfo, chatInfo?: ChatInfo): string | undefined {
  let path = getMessageAttachmentPath(msg)
  if (msg.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
    if (path !== '' && fs.accessSync(path)) {
      return path
    }
  }

  if (msg.downloadProgress < 0) {
    if (path !== '' && fs.accessSync(path)) {
      return path
    } else {
      downloadAttachment(msg, path, chatInfo)
      return undefined
    }
  }
  return undefined
}

/*
 * 获取消息的视频宽高比
 */
export function getMessageVideoRatio(message?: NIMMessageInfo) {
  const attachment = message?.message.attachment as V2NIMMessageVideoAttachment
  if (attachment && attachment.height > 0) {
    return attachment.width / attachment.height
  }
  return 0
}

export async function downloadAttachment(msg: NIMMessageInfo, path: string, chatInfo?: ChatInfo) {
  if (msg.message.attachment as V2NIMMessageFileAttachment) {
    let fileAttachment = msg.message.attachment as V2NIMMessageFileAttachment;
    if (fileAttachment.url !== undefined) {
      msg.setDownloadProgress(1)
      try {
        await StorageRepo.downloadFile(fileAttachment.url, path, (progress: number) => {
          if (progress < 100) {
            chatInfo?.downloadProgressMap.set(msg.message.messageClientId, progress)
            msg.setDownloadProgress(progress)
          } else {
            if (progress == 100) {
              msg.setDownloadProgress(100)
            }
            msg.setDownloadProgress(-1)
            chatInfo?.downloadProgressMap.delete(msg.message.messageClientId)
          }
        }
        )
      } catch (err) {
        console.log('netease downloadAttachment', err)
        msg.setDownloadProgress(-1)
      }
    }
  }
}


/*
    获取消息列表中的图片url列表，并返回当前消息的图片的下标，用于图片查看器
   */
export async function getMessageImageUrls(message?: NIMMessageInfo, chatInfo?: ChatInfo,
  messages?: NIMMessageInfo[]): Promise<ImagesIndexModel> {
  let model = new ImagesIndexModel()
  let messageList = messages
  if (chatInfo) {
    messageList = chatInfo.msgList.getMessageList()
  }
  messageList?.forEach(async (msg) => {
    if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      const imageAttach = msg.message.attachment as V2NIMMessageImageAttachment
      if (imageAttach) {
        let path = getMessageAttachmentPath(msg)

        // 本地存在（已下载）
        if (fs.accessSync(path)) {
          const uri = fileUri.getUriFromPath(path)
          model.imageUrls.push(uri)

          // 当前点击的图片
          if (msg?.message.messageClientId === message?.message.messageClientId) {
            model.currentIndex = model.imageUrls.length - 1
          }
        } else if (imageAttach.url) {
          // 未下载
          // 先展示缩略图
          const imageThumbUrl = ChatKitClient.nim.storageUtil?.imageThumbUrl(imageAttach.url, 350)
          if (imageThumbUrl) {
            model.imageUrls.push(imageThumbUrl)

            // 当前点击的图片
            if (msg?.message.messageClientId === message?.message.messageClientId) {
              model.currentIndex = model.imageUrls.length - 1
            }

            // 下载后替换为原图
            try {
              let path = getMessageAttachmentPath(msg)
              await downloadAttachment(msg, path, chatInfo)

              if (fs.accessSync(path)) {
                const uri = fileUri.getUriFromPath(path)
                const imageIndex = model.imageUrls.indexOf(imageThumbUrl)
                model.imageUrls[imageIndex] = uri
              }
            } catch (err) {
              console.log('netease getMessageImageUrls', err)
            }
          }
        }
      }
    }
  })
  return model
}

export async function getMessageImageUrl(message?: NIMMessageInfo, chatInfo?: ChatInfo): Promise<ImagesIndexModel> {
  let model = new ImagesIndexModel()
  let messageList = [message]
  messageList?.forEach(async (msg) => {
    if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      const imageAttach = msg.message.attachment as V2NIMMessageImageAttachment
      if (imageAttach) {
        let path = getMessageAttachmentPath(msg)

        // 本地存在（已下载）
        if (fs.accessSync(path)) {
          const uri = fileUri.getUriFromPath(path)
          model.imageUrls.push(uri)

        } else if (imageAttach.url) {
          // 未下载
          // 先展示缩略图
          const imageThumbUrl = ChatKitClient.nim.storageUtil?.imageThumbUrl(imageAttach.url, 350)
          if (imageThumbUrl) {
            model.imageUrls.push(imageThumbUrl)
            // 下载后替换为原图
            try {
              let path = getMessageAttachmentPath(msg)
              await downloadAttachment(msg, path, chatInfo)

              if (fs.accessSync(path)) {
                const uri = fileUri.getUriFromPath(path)
                const imageIndex = model.imageUrls.indexOf(imageThumbUrl)
                model.imageUrls[imageIndex] = uri
              }
            } catch (err) {
              console.log('netease getMessageImageUrl', err)
            }
          }
        }
      }
    }
  })
  return model
}

/**
 * 文件消息下载或打开
 * @param msg
 * @param context
 */
export function downLoadAndOpenFile(msg: NIMMessageInfo, context: Context, chatInfo?: ChatInfo) {
  let path = getMessageAttachmentPath(msg)
  if (path !== '') {
    fs.stat(path).then((stat: fs.Stat) => {
      let uri = fileUri.getUriFromPath(path);
      let fileName = getFileMessageAttachmentName(msg);
      let fileExt = getFileMessageAttachmentExt(msg);
      openFileWithApp(uri, fileName, fileExt, context)
    }).catch((err: BusinessError) => {
      console.error("netease get file info failed with error message: " + err.message + ", error code: " + err.code);
      downloadAttachment(msg, path, chatInfo)
      NECommonUtils.showToast($r('app.string.chat_msg_download_tips'))
      return
    });
  }
}

/**
 * 拼装合并消息内容
 * @param mergedAttachment
 */
export function getMergedMessageContent(mergedAttachment: MergedMessageAttachment): string {
  let content = ''
  if (mergedAttachment.abstracts) {
    for (let index = 0; index < mergedAttachment.abstracts.length; index++) {
      let abstract = mergedAttachment.abstracts[index]
      let sendNick = abstract.senderNick
      if (sendNick.length > 8) {
        let startIndex = 3
        let lastIndex = sendNick.length - 2
        let targetStr = sendNick.charAt(startIndex)
        let lastTargetStr = sendNick.charAt(lastIndex)
        // 判断是否为高位
        if (isCharacterEmoji(targetStr) && !isLastCharacterEmoji(targetStr)) {
          startIndex++
        }
        sendNick = sendNick.substring(0, startIndex + 1)
        sendNick = sendNick + "..."
        if (isLastCharacterEmoji(lastTargetStr)) {
          lastIndex++
        }
        sendNick = sendNick + abstract.senderNick.substring(lastIndex)
      }
      content += sendNick + ": "
      content += abstract.content
      if (index < mergedAttachment.abstracts.length - 1) {
        content += "\n"
      }
    }
  }
  return content
}

export function getReplyMessageTitle(msg: NIMMessageInfo, chatInfo: ChatInfo): string {
  return getContext().resourceManager.getStringByNameSync('chat_input_reply_text') +
  parseReplyMessageUserInfo(msg, chatInfo)
}

export function parseReplyMessageContent(msg: NIMMessageInfo, chatInfo: ChatInfo): string {
  let result: string = ''
  let nickName = sliceContent(chatInfo?.getChatUserShowName(msg.message), 8, true)
  result = nickName + ": "
  if (msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    result += sliceContent(msg.message.text, 30, false)
  } else {
    result += contentOfMessage(msg.message)
  }
  return result
}

export function parseReplyMessageUserInfo(msg: NIMMessageInfo, chatInfo: ChatInfo): string {
  let result: string = ''
  let nickName = sliceContent(chatInfo?.getChatUserShowName(msg.message), 8, true)
  result = nickName + ": "
  return result
}

export function getReplyMessageText(msg: NIMMessageInfo): string {
  let result: string = ''
  if (msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    result = msg.message.text ?? ''
  } else {
    result = contentOfMessage(msg.message)
  }
  return result
}

export function sliceMessageText(msgResult: Array<NEEmojiParseResult> | undefined,
  limit: number): Array<NEEmojiParseResult> {
  let size = 0
  let result: Array<NEEmojiParseResult> = []
  if (msgResult) {

    for (let index = 0; index < msgResult.length; index++) {
      const element = msgResult[index];
      if (element.text) {
        if (element.text.length + size < limit) {
          result.push(element)
          size = size + element.text.length
        } else if (element.text.length + size < limit + 5) {
          result.push(element)
          break
        } else {
          element.text = sliceContent(element.text, limit - size, false)
          result.push(element)
          break
        }
      } else if (element.emoji) {
        if (size + 1.5 < limit) {
          result.push(element)
          size = size + 1.5
        } else {
          break
        }
      }

    }
  }
  return result
}

/**
 * 插入消息发送失败提示
 * @param msg 发送失败的消息
 * @param err 失败信息
 */
export function sendMessageFailedTips(msg: V2NIMMessage, err: BusinessError, conversationId: string) {
  let text: string | undefined
  const resourceManager = getContext().resourceManager
  switch (err.code) {
    case errCodeInBlock:
      text = resourceManager.getStringSync($r('app.string.msg_send_failed_in_block').id)
      break
    case errCodeNoFriend:
      text = resourceManager.getStringSync($r('app.string.msg_send_failed_no_friend').id) +
      resourceManager.getStringSync($r('app.string.msg_send_failed_friend_application').id)
      break
  }

  if (text) {
    const tipMessage = ChatRepo.createTipsMessage(text)
    const createTime = Date.now()
    ChatRepo.insertMessageToLocal(tipMessage, conversationId, ChatKitClient.getLoginUserId(),
      createTime)
  }
}

export function isSupportMessage(msgInfo: NIMMessageInfo): boolean {
  let result = false
  if (msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
    result = true
  } else if (msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
    result = true
  } else if (msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
    result = true
  } else if (msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
    result = true
  } else if (msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
    result = true
  } else if (msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
    result = true
  } else if (msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
    result = true
  } else if (msgInfo.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
    if (msgInfo.isMergeMsg) {
      result = true
    } else {
      result = false
    }
  } else {
    result = false
  }
  return result
}

