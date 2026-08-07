/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { InputStyleType } from '../view/ChatInputView'
import { V2NIMAIUser } from '@nimsdk/base'
import { TeamMemberCache } from '@nimkit/chatkit'

export enum AitInsertTarget {
  None = 0,
  SingleLine = 1,
  MultiLine = 2,
}

export interface AitCandidate {
  accountId: string
  displayName: string
}

export function resolveAvatarLongPressAitTarget(
  inputStyle: InputStyleType,
  hasSingleLineController: boolean,
  hasMultiLineInstance: boolean
): AitInsertTarget {
  if (inputStyle === InputStyleType.Multiline) {
    return hasMultiLineInstance ? AitInsertTarget.MultiLine : AitInsertTarget.None
  }
  return hasSingleLineController ? AitInsertTarget.SingleLine : AitInsertTarget.None
}

export function resolveAvatarLongPressAitAccountId(displaySenderId: string | undefined,
  loginUserId: string): string | undefined {
  if (!displaySenderId || displaySenderId === loginUserId) {
    return undefined
  }
  return displaySenderId
}

export async function resolveAitCandidateByAccountId(accountId: string,
  aiUsers: V2NIMAIUser[]): Promise<AitCandidate | undefined> {
  const aiUser = aiUsers.find(aiUser => aiUser.accountId === accountId)
  if (aiUser) {
    return {
      accountId: aiUser.accountId,
      displayName: aiUser.name ?? aiUser.accountId
    }
  }

  const member = await TeamMemberCache.getInstance().getMemberById(accountId)
  if (member) {
    return {
      accountId: member.getAccId(),
      displayName: member.getAitName()
    }
  }
  return undefined
}
