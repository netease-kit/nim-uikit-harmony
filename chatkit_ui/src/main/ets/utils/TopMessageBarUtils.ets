/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMMessageLocationAttachment, V2NIMMessageType } from '@nimsdk/base'
import { contentOfMessage, getVideoMessageUrl } from '../common/MessageHelper'
import { NIMMessageInfo } from '../model/NIMMessageInfo'

export function shouldShowTopMessageBar(enableTopMessage: boolean, messageInfo: object | undefined): boolean {
  return enableTopMessage && messageInfo !== undefined
}

export function getTopMessageSenderName(senderId: string, senderName?: string): string {
  if (senderId.length === 0) {
    return ''
  }

  const displayName = senderName ?? ''
  if (displayName.trim().length > 0) {
    return displayName
  }

  return senderId
}

export function getTopMessageSummary(messageInfo: NIMMessageInfo | undefined): string {
  if (!messageInfo) {
    return ''
  }

  const summary = contentOfMessage(messageInfo.message)
  if (messageInfo.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
    return summary
  }

  return buildTopMessageSummary(summary, getTopMessageLocationDetail(messageInfo))
}

export function buildTopMessageSummary(summary: string, detail?: string): string {
  const normalizedSummary = summary.trim()
  const normalizedDetail = detail?.trim() ?? ''

  if (normalizedSummary.length === 0) {
    return normalizedDetail
  }

  if (normalizedDetail.length === 0) {
    return normalizedSummary
  }

  return `${normalizedSummary} ${normalizedDetail}`
}

export function getTopMessageLocationDetail(messageInfo: NIMMessageInfo | undefined): string {
  if (!messageInfo) {
    return ''
  }

  const locationAttachment = messageInfo.message.attachment as V2NIMMessageLocationAttachment | undefined
  return resolveTopMessageLocationDetail(messageInfo.message.messageType, messageInfo.message.text, locationAttachment?.address)
}

export function resolveTopMessageLocationDetail(messageType: V2NIMMessageType, locationName?: string, address?: string): string {
  if (messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
    return ''
  }

  const normalizedLocationName = locationName?.trim() ?? ''
  if (normalizedLocationName.length > 0) {
    return normalizedLocationName
  }

  return address?.trim() ?? ''
}

export function isTopMessageImage(messageInfo: NIMMessageInfo | undefined): boolean {
  return messageInfo?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE
}

export function isTopMessageVideo(messageInfo: NIMMessageInfo | undefined): boolean {
  return messageInfo?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO
}

export function getTopMessageVideoPreviewUrl(messageInfo: NIMMessageInfo | undefined): string {
  if (!messageInfo || !isTopMessageVideo(messageInfo)) {
    return ''
  }

  return getVideoMessageUrl(messageInfo)
}

function isTopMessageMatched(topMessageClientId?: string, topMessageServerId?: string,
  currentMessageClientId?: string, currentMessageServerId?: string): boolean {
  const normalizedTopClientId = topMessageClientId?.trim() ?? ''
  const normalizedTopServerId = topMessageServerId?.trim() ?? ''
  const normalizedCurrentClientId = currentMessageClientId?.trim() ?? ''
  const normalizedCurrentServerId = currentMessageServerId?.trim() ?? ''

  if (normalizedTopClientId.length > 0 && normalizedTopClientId === normalizedCurrentClientId) {
    return true
  }

  if (normalizedTopServerId.length > 0 && normalizedTopServerId === normalizedCurrentServerId) {
    return true
  }

  return false
}

export function isTopMessageRevoked(topMessageClientId?: string, topMessageServerId?: string,
  revokeMessageClientId?: string, revokeMessageServerId?: string): boolean {
  return isTopMessageMatched(
    topMessageClientId,
    topMessageServerId,
    revokeMessageClientId,
    revokeMessageServerId
  )
}

export function isTopMessageDeleted(topMessageClientId?: string, topMessageServerId?: string,
  deleteMessageClientId?: string, deleteMessageServerId?: string): boolean {
  return isTopMessageMatched(
    topMessageClientId,
    topMessageServerId,
    deleteMessageClientId,
    deleteMessageServerId
  )
}
