/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { InputStyleType } from '../view/ChatInputView'

export enum AitInsertTarget {
  None = 0,
  SingleLine = 1,
  MultiLine = 2,
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
