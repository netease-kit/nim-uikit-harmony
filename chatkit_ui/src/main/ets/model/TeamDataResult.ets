/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMTeam, V2NIMTeamMember, V2NIMUser } from '@nimsdk/base';

export class TeamDataResult {
  team?: V2NIMTeam | undefined = undefined;
  teamMemberList: V2NIMTeamMember[] = [];
  teamUserList: V2NIMUser[] = [];
}