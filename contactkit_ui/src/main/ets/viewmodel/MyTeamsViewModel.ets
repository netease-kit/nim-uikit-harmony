/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { DisposableBag, TeamEventRepo, TeamRepo } from '@nimkit/chatkit'
import { V2NIMTeam, V2NIMTeamType } from '@nimsdk/base'

@ObservedV2
export class MyTeamsViewModel {
  @Trace teamList: V2NIMTeam[] = []
  private disposableBag: DisposableBag = new DisposableBag()

  onTeamCreatedFun = (team: V2NIMTeam) => {
    if (team.isValidTeam) {
      this.teamList.unshift(team)
    }
  }
  onTeamDismissedFun = (team: V2NIMTeam) => {
    for (let index = 0; index < this.teamList.length; index++) {
      if (this.teamList[index].teamId === team.teamId) {
        this.teamList.splice(index, 1)
      }
    }
  }
  onTeamJoinedFun = (team: V2NIMTeam) => {
    if (team.isValidTeam) {
      this.teamList.unshift(team)
    }
  }
  onTeamLeftFun = (team: V2NIMTeam, isKicked: boolean) => {
    for (let index = 0; index < this.teamList.length; index++) {
      if (this.teamList[index].teamId === team.teamId) {
        this.teamList.splice(index, 1)
      }
    }
  }
  onTeamInfoUpdatedFun = (team: V2NIMTeam) => {
    if (team.isValidTeam) {
      for (let index = 0; index < this.teamList.length; index++) {
        if (this.teamList[index].teamId === team.teamId) {
          this.teamList[index] = team
        }
      }
    }
  }

  constructor() {
    this.initEventListeners()
  }

  initEventListeners(): void {
    this.onDestroy()
    this.disposableBag.addAll([
      TeamEventRepo.onTeamCreated(this.onTeamCreatedFun),
      TeamEventRepo.onTeamDismissed(this.onTeamDismissedFun),
      TeamEventRepo.onTeamJoined(this.onTeamJoinedFun),
      TeamEventRepo.onTeamLeft(this.onTeamLeftFun),
      TeamEventRepo.onTeamInfoUpdated(this.onTeamInfoUpdatedFun)
    ])
  }

  async getJoinedTeamList() {
    try {
      const teamList = await TeamRepo.getJoinedTeamList([V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL])
      if (teamList) {
        this.teamList = teamList.sort((t1, t2) => {
          if (t1.createTime < t2.createTime) {
            return 1
          }
          if (t1.createTime > t2.createTime) {
            return -1
          }
          return 0
        })
      }
    } catch (err) {
      Logger.info('ContactKit', err)
    }
  }

  onDestroy() {
    this.disposableBag.dispose()
  }
}
