/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMTeam } from '@nimsdk/base';

const discussTeamKey = "im_ui_kit_group" // 讨论组识别关键字

/// 判断是否是讨论组
export function IsDiscussion(team?: V2NIMTeam) {
  if (team?.serverExtension && team.serverExtension.includes(discussTeamKey)) {
    return true
  }
  return false
}