/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMTeamMemberRole } from '@nimsdk/base'
import {
  keyExtensionTopSticky,
  typeExtensionAllowAll,
  typeExtensionAllowManager
} from '../constant/Constant'

const DISCUSSION_TEAM_EXTENSION_KEY = 'im_ui_kit_group'

export function isDiscussionTeamByServerExtension(serverExtension?: string): boolean {
  if (!serverExtension || serverExtension.length === 0) {
    return false
  }

  try {
    let extensionObject = JSON.parse(serverExtension) as Record<string, Object | string | number | boolean | undefined>
    return extensionObject?.[DISCUSSION_TEAM_EXTENSION_KEY] === true
  } catch (_e) {
    return false
  }
}

export function getTopStickyPermissionMode(serverExtension?: string,
  isDiscussionTeam: boolean = isDiscussionTeamByServerExtension(serverExtension)): string {
  let permissionMode = isDiscussionTeam ? typeExtensionAllowAll : typeExtensionAllowManager
  if (!serverExtension || serverExtension.length === 0) {
    return permissionMode
  }

  try {
    let extensionObject = JSON.parse(serverExtension) as Record<string, Object | string | number | boolean | undefined>
    const permission = extensionObject?.[keyExtensionTopSticky]
    if (typeof permission === 'string' && permission.length > 0) {
      permissionMode = permission
    }
  } catch (_e) {
    return permissionMode
  }

  return permissionMode
}

export function hasTopStickyPermission(permissionMode: string,
  memberRole: V2NIMTeamMemberRole | number | undefined): boolean {
  if (permissionMode === typeExtensionAllowAll) {
    return true
  }

  if (memberRole === undefined) {
    return false
  }

  return memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER ||
    memberRole === V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
}
