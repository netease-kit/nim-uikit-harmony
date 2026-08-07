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
  @Trace teamAvatar: string = ''
  //本人的群成员身份
  @Trace mineTeamMember?: V2NIMTeamMember
  private disposableBag: DisposableBag = new DisposableBag()
  private teamInfoRequestVersion: number = 0

  onTeamInfoUpdated(team: V2NIMTeam) {
    if (team.teamId === this.teamInfo?.teamId) {
      this.refreshTeamInfo(team)
    }
  }

  initTeamData(teamInfo?: V2NIMTeam, teamAvatar?: string) {
    this.destroy()
    this.teamInfo = teamInfo
    this.teamAvatar = teamAvatar ?? teamInfo?.avatar ?? ''
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

  applyLocalTeamAvatar(avatar: string) {
    this.teamInfoRequestVersion += 1
    this.teamAvatar = avatar
  }

  private refreshTeamInfo(callbackTeam?: V2NIMTeam) {
    const currentTeamInfo = this.teamInfo
    if (!currentTeamInfo) {
      return
    }
    const requestVersion = ++this.teamInfoRequestVersion
    TeamRepo.getTeamInfo(currentTeamInfo.teamId, currentTeamInfo.teamType).then((team) => {
      if (requestVersion !== this.teamInfoRequestVersion) {
        return
      }
      const finalTeam = team ?? callbackTeam
      if (!finalTeam) {
        return
      }
      this.teamInfo = finalTeam
      this.teamAvatar = finalTeam.avatar ?? callbackTeam?.avatar ?? this.teamAvatar
    })
  }

  destroy() {
    this.teamInfoRequestVersion += 1
    this.disposableBag.dispose()
  }
}
