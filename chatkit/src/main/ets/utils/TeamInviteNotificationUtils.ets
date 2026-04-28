/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  NIMEStrAnyObj,
  V2NIMMessage,
  V2NIMMessageNotificationAttachment,
  V2NIMMessageNotificationType,
  V2NIMMessageType
} from '@nimsdk/base'

export const teamCreateInviteLocalKey = 'nimkit_local_team_create_invite'

export function buildTeamCreateInviteLocalExtension(): string {
  return JSON.stringify({
    nimkit_local_team_create_invite: true
  })
}

export function isLocalTeamCreateInviteMessage(message?: V2NIMMessage): boolean {
  if (!message?.localExtension) {
    return false
  }

  try {
    const localExtension = JSON.parse(message.localExtension) as NIMEStrAnyObj | null
    return Boolean(localExtension?.[teamCreateInviteLocalKey])
  } catch (error) {
    return false
  }
}

export function isTeamCreateInviteNotification(message?: V2NIMMessage): boolean {
  if (!message || message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION) {
    return false
  }

  const attachment = message.attachment as V2NIMMessageNotificationAttachment | undefined
  return attachment?.type === V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_INVITE ||
    attachment?.type === V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_SUPER_TEAM_INVITE
}

export function shouldCollapseTeamCreateInviteNotifications(left?: V2NIMMessage, right?: V2NIMMessage): boolean {
  if (!left || !right || !isTeamCreateInviteNotification(left) || !isTeamCreateInviteNotification(right)) {
    return false
  }

  const leftLocal = isLocalTeamCreateInviteMessage(left)
  const rightLocal = isLocalTeamCreateInviteMessage(right)
  const hasServerShapeDifference = Boolean(left.messageServerId) !== Boolean(right.messageServerId)
  if (!hasServerShapeDifference && leftLocal === rightLocal) {
    return false
  }

  const leftAttachment = left.attachment as V2NIMMessageNotificationAttachment
  const rightAttachment = right.attachment as V2NIMMessageNotificationAttachment

  return left.conversationId === right.conversationId &&
    left.senderId === right.senderId &&
    leftAttachment.type === rightAttachment.type &&
    normalizeTargetIds(leftAttachment.targetIds) === normalizeTargetIds(rightAttachment.targetIds)
}

function normalizeTargetIds(targetIds?: string[]): string {
  if (!targetIds || targetIds.length === 0) {
    return ''
  }

  return [...targetIds].sort().join(',')
}
