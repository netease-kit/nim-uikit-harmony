/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import {
  NIMEStrAnyObj,
  V2NIMErrorCode,
  V2NIMMessage,
  V2NIMMessageQuickComment,
  V2NIMMessageQuickCommentNotification,
  V2NIMMessageQuickCommentType,
  V2NIMMessageSendingState,
  V2NIMMessageType
} from '@nimsdk/base'

export const REACTION_EMOJI_COUNT: number = 112
export const QUICK_COMMENT_QUERY_BATCH_SIZE: number = 20
export const QUICK_REACTION_INDEXES: number[] = [3, 5, 1, 21, 65, 19, 20]
export const QUICK_REACTION_WITH_ARROW_INDEXES: number[] = [3, 5, 1, 21, 65, 19]

export class ReactionSummary {
  index: number
  count: number
  hasSelf: boolean
  firstCreateTime: number

  constructor(index: number, count: number, hasSelf: boolean, firstCreateTime: number) {
    this.index = index
    this.count = count
    this.hasSelf = hasSelf
    this.firstCreateTime = firstCreateTime
  }
}

export function buildReactionSummaryRenderKey(summary: ReactionSummary): string {
  return `${summary.index}-${summary.count}-${summary.hasSelf ? '1' : '0'}`
}

class ReactionAccumulator {
  index: number
  firstCreateTime: number
  operators: Set<string> = new Set<string>()

  constructor(index: number, createTime: number) {
    this.index = index
    this.firstCreateTime = createTime
  }
}

export function reactionIndexToEmojiFile(index: number): string | undefined {
  if (index < 1 || index > REACTION_EMOJI_COUNT) {
    return undefined
  }
  return `reaction_emoji/${index.toString().padStart(3, '0')}.png`
}

export function buildAllReactionIndexes(): number[] {
  const indexes: number[] = []
  for (let index = 1; index <= REACTION_EMOJI_COUNT; index++) {
    indexes.push(index)
  }
  return indexes
}

export function buildQuickCommentBatches(messages: V2NIMMessage[]): V2NIMMessage[][] {
  const batches: V2NIMMessage[][] = []
  for (let index = 0; index < messages.length; index += QUICK_COMMENT_QUERY_BATCH_SIZE) {
    batches.push(messages.slice(index, index + QUICK_COMMENT_QUERY_BATCH_SIZE))
  }
  return batches
}

export function formatReactionCount(count: number): string {
  if (count < 1000) {
    return count.toString()
  }
  const countInThousands = Math.floor(count / 1000)
  if (countInThousands < 1000) {
    return `${countInThousands}k`
  }
  return `${Math.floor(countInThousands / 1000)}m`
}

export function isReactionMediaMessageType(messageType: V2NIMMessageType): boolean {
  return messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE ||
    messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO ||
    messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION ||
    messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO
}

export function shouldRightAlignSendMessageContent(_messageType: V2NIMMessageType): boolean {
  return false
}

export function getSendMessageComboFlexShrink(hasReaction: boolean): number {
  return hasReaction ? 0 : 1
}

export function isQuickCommentLimitErrorCode(errorCode: number | undefined): boolean {
  return errorCode === V2NIMErrorCode.V2NIM_ERROR_CODE_QUICK_COMMENT_LIMIT
}

export function calculateReactionNaturalWidth(countTextWidths: number[]): number {
  const outerLeftPadding = 6
  const addCapsuleWidthWithGap = 28 + 6
  const reactionCapsuleBorderWidth = 0.5 * 2
  let width = outerLeftPadding + addCapsuleWidthWithGap
  countTextWidths.forEach((countTextWidth: number): void => {
    const reactionCapsuleWidthWithGap = 20 + 4 + countTextWidth + 6 + 8 + reactionCapsuleBorderWidth + 6
    width += reactionCapsuleWidthWithGap
  })
  return width
}

export function calculateReactionLayoutWidth(countTextWidths: number[], maxWidth: number): number {
  const outerLeftPadding = 6
  const addCapsuleWidthWithGap = 28 + 6
  const reactionCapsuleBorderWidth = 0.5 * 2
  const naturalWidth = calculateReactionNaturalWidth(countTextWidths)
  if (maxWidth <= 0 || naturalWidth <= maxWidth) {
    return naturalWidth
  }

  const itemWidths: number[] = [addCapsuleWidthWithGap]
  countTextWidths.forEach((countTextWidth: number): void => {
    itemWidths.push(20 + 4 + countTextWidth + 6 + 8 + reactionCapsuleBorderWidth + 6)
  })

  let currentLineWidth = outerLeftPadding
  let widestLineWidth = outerLeftPadding
  itemWidths.forEach((itemWidth: number): void => {
    if (currentLineWidth > outerLeftPadding && currentLineWidth + itemWidth > maxWidth) {
      widestLineWidth = Math.max(widestLineWidth, currentLineWidth)
      currentLineWidth = outerLeftPadding + itemWidth
    } else {
      currentLineWidth += itemWidth
    }
  })
  widestLineWidth = Math.max(widestLineWidth, currentLineWidth)
  return Math.min(widestLineWidth, maxWidth)
}

export function quickCommentResultToMap(result: NIMEStrAnyObj): Map<string, V2NIMMessageQuickComment[]> {
  const commentMap: Map<string, V2NIMMessageQuickComment[]> = new Map<string, V2NIMMessageQuickComment[]>()
  Object.keys(result).forEach((messageClientId: string): void => {
    commentMap.set(messageClientId, result[messageClientId] as V2NIMMessageQuickComment[])
  })
  return commentMap
}

export function shouldEnableReactionForSelection(
  selectionActive: boolean,
  allSelected: boolean,
  translationMode: boolean
): boolean {
  return !translationMode && (!selectionActive || allSelected)
}

export function isMessageReactionEnabled(globalEnabled: boolean, conversationSupported: boolean): boolean {
  return globalEnabled && conversationSupported
}

export function computeReactionMenuY(
  anchorTop: number,
  anchorBottom: number,
  menuHeight: number,
  visibleHeight: number,
  bottomInset: number,
  margin: number,
  preferAbove: boolean
): number {
  const maxY = Math.max(0, visibleHeight - bottomInset - menuHeight - margin)
  const preferredY = preferAbove ? anchorTop - menuHeight - margin : anchorBottom + margin
  const alternateY = preferAbove ? anchorBottom + margin : anchorTop - menuHeight - margin
  if (preferredY >= 0 && preferredY <= maxY) {
    return preferredY
  }
  if (alternateY >= 0 && alternateY <= maxY) {
    return alternateY
  }
  return Math.max(0, Math.min(preferredY, maxY))
}

export function buildReactionSummaries(
  comments: V2NIMMessageQuickComment[],
  loginUserId: string
): ReactionSummary[] {
  const groups: Map<number, ReactionAccumulator> = new Map<number, ReactionAccumulator>()
  comments.forEach((comment: V2NIMMessageQuickComment): void => {
    let group = groups.get(comment.index)
    if (group === undefined) {
      group = new ReactionAccumulator(comment.index, comment.createTime)
      groups.set(comment.index, group)
    }
    group.firstCreateTime = Math.min(group.firstCreateTime, comment.createTime)
    group.operators.add(comment.operatorId)
  })

  const result: ReactionSummary[] = []
  groups.forEach((group: ReactionAccumulator): void => {
    result.push(new ReactionSummary(
      group.index,
      group.operators.size,
      group.operators.has(loginUserId),
      group.firstCreateTime
    ))
  })
  return result.sort((left: ReactionSummary, right: ReactionSummary): number => {
    if (left.firstCreateTime !== right.firstCreateTime) {
      return left.firstCreateTime - right.firstCreateTime
    }
    return left.index - right.index
  })
}

export function applyQuickCommentNotification(
  comments: V2NIMMessageQuickComment[],
  notification: V2NIMMessageQuickCommentNotification
): V2NIMMessageQuickComment[] {
  const incoming = notification.quickComment
  const result = comments.filter((comment: V2NIMMessageQuickComment): boolean => {
    return comment.index !== incoming.index || comment.operatorId !== incoming.operatorId
  })
  if (notification.operationType === V2NIMMessageQuickCommentType.V2NIM_QUICK_COMMENT_STATE_ADD) {
    result.push(incoming)
  }
  return result
}

export function canShowMessageReaction(message: V2NIMMessage, isRevokeMessage: boolean): boolean {
  const errorCode = message.messageStatus?.errorCode
  if (isRevokeMessage ||
    message.sendingState !== V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED ||
    (errorCode !== undefined && errorCode !== 200)) {
    return false
  }
  return message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION &&
    message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_TIPS &&
    message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_INVALID
}
