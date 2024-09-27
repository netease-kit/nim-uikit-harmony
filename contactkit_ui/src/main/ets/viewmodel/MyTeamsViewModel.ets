/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, TeamRepo } from '@nimkit/chatkit'
import { V2NIMTeam, V2NIMTeamType } from '@nimsdk/base'

@ObservedV2
export class MyTeamsViewModel {
  @Trace teamList: V2NIMTeam[] = []

  constructor() {
    ChatKitClient.nim.teamService?.on("onTeamCreated", (team: V2NIMTeam) => {
      if (team.isValidTeam) {
        this.teamList.unshift(team)
      }
    })

    ChatKitClient.nim.teamService?.on("onTeamDismissed", (team: V2NIMTeam) => {
      for (let index = 0; index < this.teamList.length; index++) {
        if (this.teamList[index].teamId === team.teamId) {
          this.teamList.splice(index, 1)
        }
      }
    })

    ChatKitClient.nim.teamService?.on("onTeamJoined", (team: V2NIMTeam) => {
      if (team.isValidTeam) {
        this.teamList.unshift(team)
      }
    })

    ChatKitClient.nim.teamService?.on("onTeamLeft", (team: V2NIMTeam, isKicked: boolean) => {
      for (let index = 0; index < this.teamList.length; index++) {
        if (this.teamList[index].teamId === team.teamId) {
          this.teamList.splice(index, 1)
        }
      }
    })

    ChatKitClient.nim.teamService?.on("onTeamInfoUpdated", (team: V2NIMTeam) => {
      if (team.isValidTeam) {
        for (let index = 0; index < this.teamList.length; index++) {
          if (this.teamList[index].teamId === team.teamId) {
            this.teamList[index] = team
          }
        }
      }
    })
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
      console.log(err)
    }
  }
}