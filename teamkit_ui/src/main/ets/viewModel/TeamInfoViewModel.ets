/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatKitClient, TeamRepo } from '@nimkit/chatkit'
import { V2NIMTeam, V2NIMTeamMember } from '@nimsdk/base'

@ObservedV2
export class TeamInfoViewModel {
  @Trace teamInfo?: V2NIMTeam
  //本人的群成员身份
  @Trace mineTeamMember?: V2NIMTeamMember

  onTeamInfoUpdated(team: V2NIMTeam) {
    if (team.teamId === this.teamInfo?.teamId) {
      this.teamInfo = team
    }
  }

  initTeamData(teamInfo?: V2NIMTeam) {
    this.teamInfo = teamInfo
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', this.onTeamInfoUpdated.bind(this))
    TeamRepo
  }

  getMineTeamMember() {
    if (this.teamInfo) {
      TeamRepo.getTeamMemberListByIds(
        this.teamInfo.teamId,
        this.teamInfo.teamType,
        [ChatKitClient.getLoginUserId()]
      ).then((result) => {
        this.mineTeamMember = result[0]
      })
    }
  }

  destroy() {
    ChatKitClient.nim.teamService?.off('onTeamInfoUpdated', this.onTeamInfoUpdated.bind(this))
  }
}