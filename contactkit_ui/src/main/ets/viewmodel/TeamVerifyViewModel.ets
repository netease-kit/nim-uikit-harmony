/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, TeamRepo } from '@nimkit/chatkit'
import {
  V2NIMError,
  V2NIMErrorCode,
  V2NIMTeam,
  V2NIMTeamJoinActionInfo,
  V2NIMTeamJoinActionInfoResult,
  V2NIMTeamJoinActionStatus,
  V2NIMTeamJoinActionType,
  V2NIMTeamMemberRole,
  V2NIMTeamType
} from '@nimsdk/base'
import { TeamVerifyInfoBean } from '../model/TeamVerifyInfoBean'
import { NECommonUtils } from '@nimkit/common'

const TEAM_MEMBER_LIMIT_ERROR_CODE = 801
const NO_PERMISSION_ERROR_CODE = 802
const ALREADY_IN_TEAM_ERROR_CODE = 809
const VALIDATE_PROCESSED_EXPIRED_ERROR_CODE = 509

export enum TeamVerifyActionErrorToastType {
  VALIDATE_PROCESSED,
  TEAM_MEMBER_LIMIT,
  JOINED_TEAM_LIMIT,
  ALREADY_IN_TEAM,
  NO_PERMISSION,
  TEAM_NOT_EXIST
}

export interface TeamVerifyActionErrorResult {
  toastType: TeamVerifyActionErrorToastType
  nextStatus?: V2NIMTeamJoinActionStatus
}

export interface TeamVerifyActionErrorRefineContext {
  alreadyInTeam?: boolean
  noPermission?: boolean
}

export function resolveTeamVerifyActionError(code?: number,
  actionStatus?: V2NIMTeamJoinActionStatus): TeamVerifyActionErrorResult {
  if (code === TEAM_MEMBER_LIMIT_ERROR_CODE) {
    return {
      toastType: TeamVerifyActionErrorToastType.TEAM_MEMBER_LIMIT,
      nextStatus: V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED
    }
  }

  if (code === V2NIMErrorCode.V2NIM_ERROR_CODE_JOINED_TEAM_LIMIT) {
    return {
      toastType: TeamVerifyActionErrorToastType.JOINED_TEAM_LIMIT
    }
  }

  if (code === V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_NOT_EXIST) {
    return {
      toastType: TeamVerifyActionErrorToastType.TEAM_NOT_EXIST,
      nextStatus: V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED
    }
  }

  if (code === ALREADY_IN_TEAM_ERROR_CODE ||
    code === V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_MEMBER_ALREADY_EXIST) {
    return {
      toastType: TeamVerifyActionErrorToastType.ALREADY_IN_TEAM,
      nextStatus: V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED
    }
  }

  if (code === NO_PERMISSION_ERROR_CODE ||
    code === V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_OWNER_OPERATION_PERMISSION_REQUIRED ||
    code === V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_OWNER_OR_MANAGER_OPERATION_PERMISSION_REQUIRED) {
    return {
      toastType: TeamVerifyActionErrorToastType.NO_PERMISSION,
      nextStatus: V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED
    }
  }

  if (code === VALIDATE_PROCESSED_EXPIRED_ERROR_CODE) {
    return {
      toastType: TeamVerifyActionErrorToastType.VALIDATE_PROCESSED,
      nextStatus: V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED
    }
  }

  return {
    toastType: TeamVerifyActionErrorToastType.VALIDATE_PROCESSED,
    nextStatus: V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED
  }
}

export function refineTeamVerifyActionErrorResult(result: TeamVerifyActionErrorResult,
  context: TeamVerifyActionErrorRefineContext): TeamVerifyActionErrorResult {
  if (context.alreadyInTeam &&
    (result.toastType === TeamVerifyActionErrorToastType.VALIDATE_PROCESSED ||
    result.toastType === TeamVerifyActionErrorToastType.ALREADY_IN_TEAM)) {
    return {
      toastType: TeamVerifyActionErrorToastType.ALREADY_IN_TEAM,
      nextStatus: V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED
    }
  }

  if (context.noPermission &&
    result.toastType === TeamVerifyActionErrorToastType.VALIDATE_PROCESSED) {
    return {
      toastType: TeamVerifyActionErrorToastType.NO_PERMISSION,
      nextStatus: V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED
    }
  }

  return result
}

@ObservedV2
export class TeamVerifyViewModel {
  offset: number = 0
  limit: number = 100
  finished: boolean = false
  @Trace verifyList: TeamVerifyInfoBean[] = []

  onReceiveTeamJoinActionInfoFun = async (actionInfo: V2NIMTeamJoinActionInfo) => {
    try {
      const bean = await this.convertToVerifyInfoBean(actionInfo, true)
      if (bean) {
        this.verifyList.unshift(bean)
      }
    } catch (err) {
      console.error('TeamVerifyViewModel onReceiveTeamJoinActionInfo error', err)
    }
  }

  constructor() {
    ChatKitClient.nim.teamService?.on('onReceiveTeamJoinActionInfo', this.onReceiveTeamJoinActionInfoFun)
  }

  async convertToVerifyInfoBean(actionInfo: V2NIMTeamJoinActionInfo,
    move: boolean = false): Promise<TeamVerifyInfoBean | undefined> {
    // 检查是否已存在相同记录（去重合并）
    // SDK 服务端会对同一用户对同一群的同类型操作进行合并，所以客户端也需要去重
    for (let index = 0; index < this.verifyList.length; index++) {
      const existing = this.verifyList[index]
      if (existing.isSameMessage(actionInfo)) {
        if (actionInfo.read === false) {
          existing.unreadCount += 1
        }
        // 更新时间戳为最新
        if (actionInfo.timestamp > existing.actionInfo.timestamp) {
          existing.actionInfo = actionInfo
        }
        if (move && index !== 0) {
          this.verifyList.splice(index, 1)
          this.verifyList.unshift(existing)
        }
        return undefined
      }
    }

    const bean = new TeamVerifyInfoBean(actionInfo)

    // 查询操作者用户信息
    if (actionInfo.operatorAccountId) {
      try {
        const users = await ContactRepo.getUserWithFriendByIds([actionInfo.operatorAccountId])
        if (users.length > 0) {
          bean.setOperatorUser(users[0])
        }
      } catch (err) {
        console.error('TeamVerifyViewModel getUserInfo error', err)
      }
    }

    // 查询群信息
    try {
      const team = await TeamRepo.getTeamInfo(actionInfo.teamId,
        actionInfo.teamType ?? V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
      if (team) {
        bean.setJoinTeam(team)
      }
    } catch (err) {
      console.error('TeamVerifyViewModel getTeamInfo error', err)
    }

    return bean
  }

  /**
   * 获取入群验证消息列表
   */
  async getVerifyList() {
    if (this.finished) {
      return
    }

    try {
      const result: V2NIMTeamJoinActionInfoResult | undefined =
        await TeamRepo.getTeamJoinActionInfoList({
          offset: this.offset,
          limit: this.limit
        })

      if (result) {
        this.offset = result.offset
        this.finished = result.finished

        for (const item of result.infos) {
          const bean = await this.convertToVerifyInfoBean(item)
          if (bean) {
            this.verifyList.push(bean)
          }
        }

        // 循环拉取
        if (!this.finished) {
          this.getVerifyList()
        }
      }
    } catch (err) {
      console.error('TeamVerifyViewModel getVerifyList error', err)
    }
  }

  /**
   * 同意入群申请
   */
  async acceptApplication(actionInfo: V2NIMTeamJoinActionInfo) {
    try {
      await TeamRepo.acceptJoinApplication(actionInfo)
      this.setActionStatus(actionInfo, V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_AGREED)
    } catch (err) {
      console.error('TeamVerifyViewModel acceptApplication error', err)
      await this.handleActionError(actionInfo, err)
    }
  }

  /**
   * 拒绝入群申请
   */
  async rejectApplication(actionInfo: V2NIMTeamJoinActionInfo) {
    try {
      await TeamRepo.rejectJoinApplication(actionInfo)
      this.setActionStatus(actionInfo, V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED)
    } catch (err) {
      console.error('TeamVerifyViewModel rejectApplication error', err)
      await this.handleActionError(actionInfo, err)
    }
  }

  /**
   * 接受邀请入群
   */
  async acceptInvitation(actionInfo: V2NIMTeamJoinActionInfo) {
    try {
      await TeamRepo.acceptInvitation(actionInfo)
      this.setActionStatus(actionInfo, V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_AGREED)
    } catch (err) {
      console.error('TeamVerifyViewModel acceptInvitation error', err)
      await this.handleActionError(actionInfo, err)
    }
  }

  /**
   * 拒绝邀请入群
   */
  async rejectInvitation(actionInfo: V2NIMTeamJoinActionInfo) {
    try {
      await TeamRepo.rejectInvitation(actionInfo)
      this.setActionStatus(actionInfo, V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED)
    } catch (err) {
      console.error('TeamVerifyViewModel rejectInvitation error', err)
      await this.handleActionError(actionInfo, err)
    }
  }

  private async handleActionError(actionInfo: V2NIMTeamJoinActionInfo, err: Object) {
    const error = err as V2NIMError
    let result = resolveTeamVerifyActionError(error?.code, actionInfo.actionStatus)
    result = await this.refineActionErrorResult(actionInfo, result)
    if (result.nextStatus !== undefined) {
      this.setActionStatus(actionInfo, result.nextStatus)
    }
    this.showActionErrorToast(result.toastType)
  }

  private async refineActionErrorResult(actionInfo: V2NIMTeamJoinActionInfo,
    result: TeamVerifyActionErrorResult): Promise<TeamVerifyActionErrorResult> {
    if (result.toastType !== TeamVerifyActionErrorToastType.VALIDATE_PROCESSED &&
      result.toastType !== TeamVerifyActionErrorToastType.ALREADY_IN_TEAM) {
      return result
    }

    const targetAccountId = this.getActionTargetAccountId(actionInfo)
    if (targetAccountId) {
      try {
        const members = await TeamRepo.getTeamMembersByIds(actionInfo.teamId, actionInfo.teamType, [targetAccountId])
        const alreadyInTeam = members.some(member => member.teamMember.inTeam)
        result = refineTeamVerifyActionErrorResult(result, { alreadyInTeam })
      } catch (err) {
        console.error('TeamVerifyViewModel refineActionErrorResult alreadyInTeam error', err)
      }
    }

    if (result.toastType !== TeamVerifyActionErrorToastType.VALIDATE_PROCESSED ||
      !this.needCheckOperatorPermission(actionInfo)) {
      return result
    }

    const operatorAccountId = ChatKitClient.getLoginUserId()
    if (!operatorAccountId) {
      return result
    }

    try {
      const members = await TeamRepo.getTeamMembersByIds(actionInfo.teamId, actionInfo.teamType, [operatorAccountId])
      const operatorMember = members.find(member => member.teamMember.accountId === operatorAccountId)
      const noPermission = this.isOperatorWithoutApplicationPermission(operatorMember?.teamMember.inTeam,
        operatorMember?.teamMember.memberRole)
      return refineTeamVerifyActionErrorResult(result, { noPermission })
    } catch (err) {
      console.error('TeamVerifyViewModel refineActionErrorResult permission error', err)
      return result
    }
  }

  private needCheckOperatorPermission(actionInfo: V2NIMTeamJoinActionInfo): boolean {
    switch (actionInfo.actionType) {
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION:
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_ACCEPT_APPLICATION:
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_REJECT_APPLICATION:
        return true
      default:
        return false
    }
  }

  private isOperatorWithoutApplicationPermission(inTeam?: boolean,
    memberRole?: V2NIMTeamMemberRole): boolean {
    if (!inTeam || memberRole === undefined) {
      return false
    }

    return memberRole !== V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER &&
      memberRole !== V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER
  }

  private getActionTargetAccountId(actionInfo: V2NIMTeamJoinActionInfo): string {
    switch (actionInfo.actionType) {
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION:
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_ACCEPT_APPLICATION:
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_REJECT_APPLICATION:
        return actionInfo.fromAccountId ?? actionInfo.operatorAccountId ?? ''
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_INVITATION:
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_ACCEPT_INVITATION:
      case V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_REJECT_INVITATION:
        return actionInfo.targetAccountId ?? ChatKitClient.getLoginUserId()
      default:
        return actionInfo.targetAccountId ?? actionInfo.fromAccountId ?? actionInfo.operatorAccountId ?? ''
    }
  }

  private showActionErrorToast(toastType: TeamVerifyActionErrorToastType) {
    switch (toastType) {
      case TeamVerifyActionErrorToastType.TEAM_MEMBER_LIMIT:
        NECommonUtils.showToast($r('app.string.team_member_limit_tip'))
        break
      case TeamVerifyActionErrorToastType.JOINED_TEAM_LIMIT:
        NECommonUtils.showToast($r('app.string.joined_team_limit_tip'))
        break
      case TeamVerifyActionErrorToastType.ALREADY_IN_TEAM:
        NECommonUtils.showToast($r('app.string.already_in_team_tip'))
        break
      case TeamVerifyActionErrorToastType.NO_PERMISSION:
        NECommonUtils.showToast($r('app.string.no_permission_tip'))
        break
      case TeamVerifyActionErrorToastType.TEAM_NOT_EXIST:
        NECommonUtils.showToast($r('app.string.team_not_exist_tip'))
        break
      default:
        NECommonUtils.showToast($r('app.string.validate_processed'))
        break
    }
  }

  private setActionStatus(actionInfo: V2NIMTeamJoinActionInfo, status: V2NIMTeamJoinActionStatus) {
    actionInfo.actionStatus = status
    for (const bean of this.verifyList) {
      if (this.isSameActionInfo(bean.actionInfo, actionInfo)) {
        bean.actionStatus = status
        bean.actionInfo.actionStatus = status
        bean.unreadCount = 0
      }
    }
  }

  private isSameActionInfo(left: V2NIMTeamJoinActionInfo, right: V2NIMTeamJoinActionInfo): boolean {
    if (left === right) {
      return true
    }
    if (left.serverId && right.serverId) {
      return left.serverId === right.serverId
    }
    return left.teamId === right.teamId &&
      left.teamType === right.teamType &&
      (left.operatorAccountId ?? '') === (right.operatorAccountId ?? '') &&
      (left.targetAccountId ?? '') === (right.targetAccountId ?? '') &&
      left.actionType === right.actionType &&
      left.timestamp === right.timestamp
  }

  /**
   * 设置验证消息已读
   */
  async setVerifyRead() {
    try {
      await ChatKitClient.nim.teamService?.setTeamJoinActionInfoRead()
    } catch (err) {
      console.error('TeamVerifyViewModel setVerifyRead error', err)
    }
  }

  /**
   * 清空所有验证消息
   */
  async clearAll() {
    if (this.verifyList.length < 1) {
      return
    }
    try {
      await ChatKitClient.nim.teamService?.clearAllTeamJoinActionInfo()
      this.verifyList = []
    } catch (err) {
      console.error('TeamVerifyViewModel clearAll error', err)
    }
  }

  onDestroy() {
    ChatKitClient.nim.teamService?.off('onReceiveTeamJoinActionInfo', this.onReceiveTeamJoinActionInfoFun)
  }
}
