/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import {
  V2NIMMessage,
  V2NIMMessageListOption,
  V2NIMMessageListResult,
  V2NIMQueryDirection
} from '@nimsdk/base';

export const LAST_READ_UNREAD_DISPLAY_LIMIT: number = 99
export const LAST_READ_UNREAD_QUERY_LIMIT: number = 100

export class LastReadUnreadDisplayCount {
  count: number
  overflow: boolean
  targetMessageClientId: string
  targetMessageCreateTime: number

  constructor(count: number, overflow: boolean,
    targetMessageClientId: string = '', targetMessageCreateTime: number = 0) {
    this.count = count
    this.overflow = overflow
    this.targetMessageClientId = targetMessageClientId
    this.targetMessageCreateTime = targetMessageCreateTime
  }
}

export type LastReadMessageListQuery =
  (option: V2NIMMessageListOption) => Promise<V2NIMMessageListResult>

export enum LastReadPositionStatus {
  DISABLED = 0,
  READY = 1,
  VISIBLE = 2,
  LOCATING = 3,
  CONSUMED = 4
}

export function createLastReadPositionStatus(lastReadTime?: number): LastReadPositionStatus {
  return lastReadTime !== undefined && lastReadTime >= 0 ?
    LastReadPositionStatus.READY : LastReadPositionStatus.DISABLED
}

export function resolveLastReadPositionAfterUnreadCount(
  currentStatus: LastReadPositionStatus,
  unreadCount: number
): LastReadPositionStatus {
  if (currentStatus === LastReadPositionStatus.CONSUMED) {
    return LastReadPositionStatus.CONSUMED
  }
  return unreadCount > 0 ? LastReadPositionStatus.VISIBLE : LastReadPositionStatus.DISABLED
}

export function updateLastReadPositionStatus(
  currentStatus: LastReadPositionStatus,
  boundaryTime: number,
  topVisibleTime?: number,
  targetAtOrBelowTop?: boolean
): LastReadPositionStatus {
  if (currentStatus === LastReadPositionStatus.DISABLED ||
    currentStatus === LastReadPositionStatus.LOCATING ||
    currentStatus === LastReadPositionStatus.CONSUMED) {
    return currentStatus
  }
  if (boundaryTime <= 0 || topVisibleTime === undefined || topVisibleTime <= 0) {
    return currentStatus
  }
  // Prefer exact list positions when the target is already loaded.
  if (targetAtOrBelowTop !== undefined) {
    return targetAtOrBelowTop ? LastReadPositionStatus.CONSUMED : LastReadPositionStatus.VISIBLE
  }
  return topVisibleTime <= boundaryTime ?
    LastReadPositionStatus.CONSUMED : LastReadPositionStatus.VISIBLE
}

export function startLastReadPositionJump(currentStatus: LastReadPositionStatus): LastReadPositionStatus {
  return currentStatus === LastReadPositionStatus.VISIBLE ? LastReadPositionStatus.LOCATING : currentStatus
}

export function finishLastReadPositionJump(
  currentStatus: LastReadPositionStatus,
  success: boolean
): LastReadPositionStatus {
  if (currentStatus !== LastReadPositionStatus.LOCATING) {
    return currentStatus
  }
  return success ? LastReadPositionStatus.CONSUMED : LastReadPositionStatus.VISIBLE
}

export function canShowLastReadPosition(
  status: LastReadPositionStatus,
  unreadCount: number,
  visibleStateReady: boolean
): boolean {
  if (unreadCount <= 0 || !visibleStateReady) {
    return false
  }
  return status === LastReadPositionStatus.VISIBLE || status === LastReadPositionStatus.LOCATING
}

export function buildLastReadMessageQueryOption(
  conversationId: string,
  lastReadTime: number
): V2NIMMessageListOption {
  return {
    conversationId,
    beginTime: lastReadTime + 1,
    limit: 1,
    direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC,
    strictMode: false,
    onlyQueryLocal: false
  }
}

export async function queryLocalUnreadDisplayCount(
  conversationId: string,
  lastReadTime: number,
  query: LastReadMessageListQuery
): Promise<LastReadUnreadDisplayCount> {
  let count = 0
  let anchorMessage: V2NIMMessage | undefined = undefined
  let targetMessageClientId = ''
  let targetMessageCreateTime = 0

  while (true) {
    const option = new Object() as V2NIMMessageListOption
    option.conversationId = conversationId
    option.beginTime = anchorMessage ? anchorMessage.createTime : lastReadTime + 1
    option.limit = LAST_READ_UNREAD_QUERY_LIMIT
    option.direction = V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
    option.strictMode = false
    option.onlyQueryLocal = true
    option.anchorMessage = anchorMessage

    const queryResult = await query(option)
    for (const message of queryResult.messages) {
      if (count === 0) {
        targetMessageClientId = message.messageClientId
        targetMessageCreateTime = message.createTime
      }
      count++
      if (count > LAST_READ_UNREAD_DISPLAY_LIMIT) {
        return new LastReadUnreadDisplayCount(
          LAST_READ_UNREAD_DISPLAY_LIMIT, true, targetMessageClientId, targetMessageCreateTime)
      }
    }

    if (!queryResult.hasMore) {
      return new LastReadUnreadDisplayCount(count, false, targetMessageClientId, targetMessageCreateTime)
    }
    if (!queryResult.anchorMessage) {
      throw new Error('Message list result hasMore is true but anchorMessage is missing')
    }
    anchorMessage = queryResult.anchorMessage
  }
}
