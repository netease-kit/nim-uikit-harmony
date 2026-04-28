/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

const APPLY_JOIN_WAITING_VERIFY_ERROR_CODE = 808

export enum TeamApplyJoinToastType {
  APPLICATION_SENT,
  APPLY_FAILED
}

export function resolveTeamApplyJoinErrorToastType(errorCode?: number): TeamApplyJoinToastType {
  if (errorCode === APPLY_JOIN_WAITING_VERIFY_ERROR_CODE) {
    return TeamApplyJoinToastType.APPLICATION_SENT
  }

  return TeamApplyJoinToastType.APPLY_FAILED
}
