/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatKitClient, DisposableBag, TeamEventRepo, TeamRepo } from '@nimkit/chatkit'
import { V2NIMTeam, V2NIMTeamMember } from '@nimsdk/base'

@ObservedV2
export class TeamInfoViewModel {
  @Trace teamInfo?: V2NIMTeam
  //本人的群成员身份
  @Trace mineTeamMember?: V2NIMTeamMember
  private disposableBag: DisposableBag = new DisposableBag()

  onTeamInfoUpdated(team: V2NIMTeam) {
    if (team.teamId === this.teamInfo?.teamId) {
      this.teamInfo = team
    }
  }

  initTeamData(teamInfo?: V2NIMTeam) {
    this.destroy()
    this.teamInfo = teamInfo
    this.disposableBag.add(
      TeamEventRepo.onTeamInfoUpdated((team: V2NIMTeam): void => {
        this.onTeamInfoUpdated(team)
      })
    )
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
    this.disposableBag.dispose()
  }
}
