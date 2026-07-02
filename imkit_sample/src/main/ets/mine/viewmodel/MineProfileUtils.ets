/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMUser } from '@nimsdk/base';

export function resolveMineUser(user: V2NIMUser | undefined, loginAccountId: string): V2NIMUser | undefined {
  return user?.accountId === loginAccountId ? user : undefined
}

export function resolveMineDisplayAccountId(user: V2NIMUser | undefined, loginAccountId: string): string {
  return user?.accountId ?? loginAccountId
}

export function resolveMineDisplayName(user: V2NIMUser | undefined, loginAccountId: string): string {
  if (user?.name && user.name.length > 0) {
    return user.name
  }

  return loginAccountId
}

export function resolveMineAvatarName(user: V2NIMUser | undefined, loginAccountId: string): string {
  const displayName = resolveMineDisplayName(user, loginAccountId)
  if (displayName.length > 2) {
    return displayName.substring(displayName.length - 2, displayName.length)
  }

  return displayName
}

export function resolveMineAvatarPreloadUrl(user: V2NIMUser | undefined, loginAccountId: string): string {
  const mineUser = resolveMineUser(user, loginAccountId)
  if (mineUser?.avatar && mineUser.avatar.length > 0) {
    return mineUser.avatar
  }

  return ''
}
