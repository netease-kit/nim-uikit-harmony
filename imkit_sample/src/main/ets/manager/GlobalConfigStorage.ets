/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export function resolveReadMessageEnabled(readMessageSetting?: boolean,
  legacyReadMessageSetting?: boolean): boolean {
  if (typeof readMessageSetting === 'boolean') {
    return readMessageSetting
  }

  if (typeof legacyReadMessageSetting === 'boolean') {
    return legacyReadMessageSetting
  }

  return true
}

export function resolveTeamJoinAgreeModeEnabled(teamJoinAgreeModeSetting?: boolean): boolean {
  if (typeof teamJoinAgreeModeSetting === 'boolean') {
    return teamJoinAgreeModeSetting
  }

  return true
}

export function resolveLocalConversationEnabled(localConversationSetting?: boolean): boolean {
  if (typeof localConversationSetting === 'boolean') {
    return localConversationSetting
  }

  return true
}
