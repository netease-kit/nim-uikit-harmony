/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMTeam,
  V2NIMTeamJoinActionInfo,
  V2NIMTeamMember
} from '@nimsdk/base'
import { ChatKitClient } from '../ChatKitClient'
import { EventDisposer } from '../utils/DisposableBag'
import { createEventListenerHandle } from '../utils/EventListenerHandle'

export type TeamEventDisposer = EventDisposer

export class TeamEventRepo {
  static onTeamSyncFinished(callback: () => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: () => void): void => {
      service?.on('onSyncFinished', listener)
    }, (listener: () => void): void => {
      service?.off('onSyncFinished', listener)
    }, callback)
  }

  static onTeamCreated(callback: (team: V2NIMTeam) => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (team: V2NIMTeam) => void): void => {
      service?.on('onTeamCreated', listener)
    }, (listener: (team: V2NIMTeam) => void): void => {
      service?.off('onTeamCreated', listener)
    }, callback)
  }

  static onTeamDismissed(callback: (team: V2NIMTeam) => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (team: V2NIMTeam) => void): void => {
      service?.on('onTeamDismissed', listener)
    }, (listener: (team: V2NIMTeam) => void): void => {
      service?.off('onTeamDismissed', listener)
    }, callback)
  }

  static onTeamJoined(callback: (team: V2NIMTeam) => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (team: V2NIMTeam) => void): void => {
      service?.on('onTeamJoined', listener)
    }, (listener: (team: V2NIMTeam) => void): void => {
      service?.off('onTeamJoined', listener)
    }, callback)
  }

  static onTeamLeft(callback: (team: V2NIMTeam, isKicked: boolean) => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (team: V2NIMTeam, isKicked: boolean) => void): void => {
      service?.on('onTeamLeft', listener)
    }, (listener: (team: V2NIMTeam, isKicked: boolean) => void): void => {
      service?.off('onTeamLeft', listener)
    }, callback)
  }

  static onTeamInfoUpdated(callback: (team: V2NIMTeam) => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (team: V2NIMTeam) => void): void => {
      service?.on('onTeamInfoUpdated', listener)
    }, (listener: (team: V2NIMTeam) => void): void => {
      service?.off('onTeamInfoUpdated', listener)
    }, callback)
  }

  static onTeamMemberJoined(callback: (teamMembers: V2NIMTeamMember[]) => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (teamMembers: V2NIMTeamMember[]) => void): void => {
      service?.on('onTeamMemberJoined', listener)
    }, (listener: (teamMembers: V2NIMTeamMember[]) => void): void => {
      service?.off('onTeamMemberJoined', listener)
    }, callback)
  }

  static onTeamMemberKicked(
    callback: (operateAccountId: string, teamMembers: V2NIMTeamMember[]) => void
  ): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle(
      (listener: (operateAccountId: string, teamMembers: V2NIMTeamMember[]) => void): void => {
        service?.on('onTeamMemberKicked', listener)
      },
      (listener: (operateAccountId: string, teamMembers: V2NIMTeamMember[]) => void): void => {
        service?.off('onTeamMemberKicked', listener)
      },
      callback
    )
  }

  static onTeamMemberLeft(callback: (teamMembers: V2NIMTeamMember[]) => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (teamMembers: V2NIMTeamMember[]) => void): void => {
      service?.on('onTeamMemberLeft', listener)
    }, (listener: (teamMembers: V2NIMTeamMember[]) => void): void => {
      service?.off('onTeamMemberLeft', listener)
    }, callback)
  }

  static onTeamMemberInfoUpdated(callback: (teamMembers: V2NIMTeamMember[]) => void): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (teamMembers: V2NIMTeamMember[]) => void): void => {
      service?.on('onTeamMemberInfoUpdated', listener)
    }, (listener: (teamMembers: V2NIMTeamMember[]) => void): void => {
      service?.off('onTeamMemberInfoUpdated', listener)
    }, callback)
  }

  static onReceiveTeamJoinActionInfo(
    callback: (joinActionInfo: V2NIMTeamJoinActionInfo) => void
  ): TeamEventDisposer {
    const service = ChatKitClient.nim.teamService
    return createEventListenerHandle((listener: (joinActionInfo: V2NIMTeamJoinActionInfo) => void): void => {
      service?.on('onReceiveTeamJoinActionInfo', listener)
    }, (listener: (joinActionInfo: V2NIMTeamJoinActionInfo) => void): void => {
      service?.off('onReceiveTeamJoinActionInfo', listener)
    }, callback)
  }

}
