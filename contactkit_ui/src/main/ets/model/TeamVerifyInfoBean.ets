/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEUserWithFriend } from '@nimkit/chatkit';
import {
  V2NIMTeam,
  V2NIMTeamJoinActionInfo,
  V2NIMTeamJoinActionStatus,
  V2NIMTeamJoinActionType
} from '@nimsdk/base';

export enum TeamVerifyActionTextType {
  APPLICATION,
  INVITATION,
  ACCEPT_APPLICATION,
  REJECT_APPLICATION,
  ACCEPT_INVITATION,
  REJECT_INVITATION
}

export function getTeamVerifyActionTextType(actionInfo: V2NIMTeamJoinActionInfo): TeamVerifyActionTextType {
  switch (actionInfo.actionType) {
    case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_ACCEPT_APPLICATION:
      return TeamVerifyActionTextType.ACCEPT_APPLICATION
    case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_REJECT_APPLICATION:
      return TeamVerifyActionTextType.REJECT_APPLICATION
    case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_ACCEPT_INVITATION:
      return TeamVerifyActionTextType.ACCEPT_INVITATION
    case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_REJECT_INVITATION:
      return TeamVerifyActionTextType.REJECT_INVITATION
    case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_INVITATION:
      if (actionInfo.actionStatus === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_AGREED) {
        return TeamVerifyActionTextType.ACCEPT_INVITATION
      }
      if (actionInfo.actionStatus === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED) {
        return TeamVerifyActionTextType.REJECT_INVITATION
      }
      return TeamVerifyActionTextType.INVITATION
    case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION:
    default:
      if (actionInfo.actionStatus === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_AGREED) {
        return TeamVerifyActionTextType.ACCEPT_APPLICATION
      }
      if (actionInfo.actionStatus === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED) {
        return TeamVerifyActionTextType.REJECT_APPLICATION
      }
      return TeamVerifyActionTextType.APPLICATION
  }
}

function isPendingTeamVerifyAction(status: V2NIMTeamJoinActionStatus): boolean {
  return status === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
}

function getApplicationApplicantAccountId(actionInfo: V2NIMTeamJoinActionInfo): string {
  return actionInfo.fromAccountId || actionInfo.operatorAccountId || ''
}

function isCurrentUserInvitationTarget(actionInfo: V2NIMTeamJoinActionInfo,
  currentAccountId: string): boolean {
  if (actionInfo.targetAccountId) {
    return currentAccountId === actionInfo.targetAccountId
  }

  return currentAccountId !== actionInfo.operatorAccountId
}

export function shouldShowTeamVerifyActionButtons(actionInfo: V2NIMTeamJoinActionInfo,
  currentAccountId?: string,
  actionStatus: V2NIMTeamJoinActionStatus = actionInfo.actionStatus): boolean {
  if (!currentAccountId || !isPendingTeamVerifyAction(actionStatus)) {
    return false
  }

  switch (actionInfo.actionType) {
    case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION: {
      const applicantAccountId = getApplicationApplicantAccountId(actionInfo)
      return currentAccountId !== applicantAccountId
    }
    case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_INVITATION:
      return isCurrentUserInvitationTarget(actionInfo, currentAccountId)
    default:
      return false
  }
}

@ObservedV2
export class TeamVerifyInfoBean {
  /**
   * 入群操作信息
   */
  actionInfo: V2NIMTeamJoinActionInfo
  /**
   * 关联的群信息
   */
  @Trace joinTeam?: V2NIMTeam
  /**
   * 操作者用户信息
   */
  @Trace operatorUser?: NEUserWithFriend
  /**
   * 操作状态
   */
  @Trace actionStatus: V2NIMTeamJoinActionStatus =
    V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
  /**
   * 未读数
   */
  @Trace unreadCount: number = 0

  constructor(actionInfo: V2NIMTeamJoinActionInfo) {
    this.actionInfo = actionInfo
    this.actionStatus = actionInfo.actionStatus
    this.unreadCount = actionInfo.read === false ? 1 : 0
  }

  setOperatorUser(user?: NEUserWithFriend) {
    this.operatorUser = user
  }

  setJoinTeam(team?: V2NIMTeam) {
    this.joinTeam = team
  }

  /**
   * 判断是否同一条记录：teamId + operatorAccountId + actionType + actionStatus
   * SDK 服务端会对同一用户对同一群的同类型操作进行合并，客户端需要配合去重
   */
  isSameMessage(other: V2NIMTeamJoinActionInfo): boolean {
    return this.actionInfo.teamId === other.teamId &&
      this.actionInfo.operatorAccountId === other.operatorAccountId &&
      this.actionInfo.actionType === other.actionType &&
      this.actionStatus === other.actionStatus
  }
}
