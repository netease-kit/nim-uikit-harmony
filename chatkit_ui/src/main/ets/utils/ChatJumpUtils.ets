/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export interface MessageJumpPlan {
  scrollIndex: number
  shouldLoadAnchor: boolean
}

export function buildMessageJumpPlan(targetMessageClientId?: string, loadedMessageClientIds: string[] = []): MessageJumpPlan {
  const normalizedTargetMessageClientId = targetMessageClientId?.trim() ?? ''
  if (normalizedTargetMessageClientId.length === 0) {
    return {
      scrollIndex: -1,
      shouldLoadAnchor: false
    }
  }

  const scrollIndex = loadedMessageClientIds.findIndex((messageClientId: string) => {
    return messageClientId === normalizedTargetMessageClientId
  })
  if (scrollIndex >= 0) {
    return {
      scrollIndex,
      shouldLoadAnchor: false
    }
  }

  return {
    scrollIndex: -1,
    shouldLoadAnchor: true
  }
}
