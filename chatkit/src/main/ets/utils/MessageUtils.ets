/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { systemDateTime } from '@kit.BasicServicesKit';
import { V2NIMMessage, V2NIMMessageRevokeNotification } from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';
import { RevokeMessageExtension } from '../model/RevokeMessageExtension';
import { ChatRepo } from '../repo/ChatRepo';

// 保存撤回消息到本地
export function saveLocalRevokeMessage(conversationId: string, msg: V2NIMMessage, edit: boolean) {
  let currentTime = systemDateTime.getTime()
  let revokeText = getContext().resourceManager.getStringByNameSync('chat_msg_undo_tips');
  let revokeMsg = ChatKitClient.nim.messageCreator.createTextMessage(revokeText)
  revokeMsg.serverExtension = msg.serverExtension
  let localExtension = {
    revoke_message_local: true,
    revoke_message_local_time: currentTime,
    revoke_message_client_id: msg.messageClientId,
    revoke_message_local_edit: edit,
    revoke_message_local_content: msg.text ?? ''

  } as RevokeMessageExtension

  revokeMsg.localExtension = JSON.stringify(localExtension)
  let createTime = msg.createTime + 10
  console.debug('netease saveLocalRevokeMessage:', revokeMsg.localExtension)
  ChatRepo.saveLocalMessage(revokeMsg, conversationId, ChatKitClient.getLoginUserId(), createTime)
}

// 保存他人撤回消息到本地
export function saveLocalRevokeMessageFormOther(conversationId: string, msgNotify: V2NIMMessageRevokeNotification,
  edit: boolean) {
  let currentTime = systemDateTime.getTime()
  let revokeText = getContext().resourceManager.getStringByNameSync('chat_msg_undo_tips');
  let revokeMsg = ChatKitClient.nim.messageCreator.createTextMessage(revokeText)
  let localExtension = {
    revoke_message_local: false,
    revoke_message_local_time: currentTime,
    revoke_message_client_id: msgNotify.messageRefer.messageClientId,
    revoke_message_local_edit: edit,
    revoke_message_local_content: ''
  } as RevokeMessageExtension

  revokeMsg.localExtension = JSON.stringify(localExtension)
  console.debug('netease saveLocalRevokeMessageFormOther:', revokeMsg.localExtension)
  let createTime = msgNotify.messageRefer.createTime + 10;
  ChatRepo.saveLocalMessage(revokeMsg, conversationId, msgNotify.revokeAccountId, createTime)
}
