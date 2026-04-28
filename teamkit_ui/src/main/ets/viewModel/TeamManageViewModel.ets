/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import {
  ChatKitClient,
  ErrorUtils,
  getTopStickyPermissionMode,
  keyExtensionAtAll,
  TeamRepo,
  typeExtensionAllowAll
} from '@nimkit/chatkit'
import { JSONUtil, NECommonUtils } from '@nimkit/common'
import {
  V2NIMError,
  V2NIMErrorCode,
  V2NIMTeam,
  V2NIMTeamAgreeMode,
  V2NIMTeamJoinMode,
  V2NIMTeamMember,
  V2NIMTeamMemberRole,
  V2NIMTeamMemberRoleQueryType,
  V2NIMTeamUpdateExtensionMode,
  V2NIMUpdateTeamInfoParams
} from '@nimsdk/base'

export function getAgreeModeToggleState(agreeMode?: V2NIMTeamAgreeMode): boolean {
  return agreeMode === V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_AUTH
}

export function getJoinModeToggleState(joinMode?: V2NIMTeamJoinMode): boolean {
  return joinMode !== V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_FREE
}

export function getAgreeModeByToggleState(isOn: boolean): V2NIMTeamAgreeMode {
  return isOn ? V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_AUTH :
    V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_NO_AUTH
}

export function getJoinModeByToggleState(isOn: boolean): V2NIMTeamJoinMode {
  return isOn ? V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_APPLY :
    V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_FREE
}

export function getTopStickyUpdateExtensionMode(permission: string): V2NIMTeamUpdateExtensionMode {
  return permission === typeExtensionAllowAll ?
  V2NIMTeamUpdateExtensionMode.V2NIM_TEAM_UPDATE_EXTENSION_MODE_ALL :
  V2NIMTeamUpdateExtensionMode.V2NIM_TEAM_UPDATE_EXTENSION_MODE_MANAGER
}

@ObservedV2
export class TeamManageViewModel {
  @Trace teamInfo?: V2NIMTeam = undefined
  @Trace managerCount?: number = undefined
  @Trace agreeModeToggleOn: boolean = false
  @Trace joinModeToggleOn: boolean = false
  agreeModeValue?: V2NIMTeamAgreeMode = undefined
  joinModeValue?: V2NIMTeamJoinMode = undefined
  //管理员
  managerList: V2NIMTeamMember[] = []

  init(teamInfo?: V2NIMTeam) {
    this.applyTeamInfo(teamInfo)
    this.initTeamListener()
  }

  //获取管理员数量
  getTeamManagerCount() {
    if (this.teamInfo) {
      TeamRepo.getTeamMemberList(
        this.teamInfo.teamId, this.teamInfo.teamType,
        { roleQueryType: V2NIMTeamMemberRoleQueryType.V2NIM_TEAM_MEMBER_ROLE_QUERY_TYPE_MANAGER }
      ).then((result) => {
        if (result !== undefined) {
          this.managerList = result.memberList
          this.managerCount = result.memberList.length - 1
        }
      }).catch((e: Error) => {
        ChatKitClient.logger?.debug(`getTeamManagerCount ${e.message}`)
      })
    }
  }

  /**
   * 更新群信息
   */
  updateTeamInfo() {
    if (this.teamInfo) {
      TeamRepo.getTeamInfo(this.teamInfo.teamId, this.teamInfo.teamType)
        .then((team) => {
          this.applyTeamInfo(team)
        })
    }
  }

  onTeamInfoUpdated(team: V2NIMTeam) {
    if (team.teamId === this.teamInfo?.teamId) {
      this.applyTeamInfo(team)
    }
  }

  onSyncFinished() {
    this.updateTeamInfo()
    this.getTeamManagerCount()
  }

  onTeamMemberInfoUpdated(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamInfo?.teamId) {
      let managerMembers = members.filter((e) => {
        let exitManager = this.managerList.find(m => m.accountId === e.accountId)
        if (exitManager) {
          return false
        }
        return e.memberRole ===
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_MANAGER || e.memberRole ===
        V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_OWNER
      })

      this.managerList.push(...managerMembers)

      let normalMembers = members.filter((e) => e.memberRole ===
      V2NIMTeamMemberRole.V2NIM_TEAM_MEMBER_ROLE_NORMAL
        && this.managerList.find((a) => a.accountId === e.accountId))

      this.managerList = this.managerList.filter((m) => !normalMembers.find((e) => e.accountId === m.accountId))

      this.managerCount = this.managerList.length - 1;
    }
  }

  /**
   * 获取@所有人的权限
   * @param team
   */
  getAitAllPermission(): string {
    let result = typeExtensionAllowAll
    if (this.teamInfo?.serverExtension) {
      if (JSONUtil.isJSONString(this.teamInfo.serverExtension)) {
        let localObject = JSON.parse(this.teamInfo.serverExtension) as object
        if (localObject?.[keyExtensionAtAll]) {
          result = localObject?.[keyExtensionAtAll]
        }
      }
    }
    return result
  }

  /**
   * 获取消息置顶权限
   * 从 serverExtension 中读取 yxAllowTop
   * 讨论组默认所有人可置顶，高级群默认群主和管理员可置顶
   */
  getTopStickyPermission(): string {
    return getTopStickyPermissionMode(this.teamInfo?.serverExtension,
      this.teamInfo ? TeamRepo.isGroupTeam(this.teamInfo) : false)
  }

  async updateAgreeModeToggle(isOn: boolean) {
    const teamInfo = this.teamInfo
    if (!teamInfo) {
      this.syncJoinManageToggleState()
      return
    }

    const previousAgreeMode = this.agreeModeValue
    this.agreeModeToggleOn = isOn
    this.agreeModeValue = getAgreeModeByToggleState(isOn)

    if (!ErrorUtils.checkNetworkAndToast()) {
      this.rollbackAgreeMode(previousAgreeMode)
      return
    }

    const param: V2NIMUpdateTeamInfoParams = {
      agreeMode: this.agreeModeValue
    }

    try {
      await TeamRepo.updateTeamInfo(teamInfo.teamId, teamInfo.teamType, param)
    } catch (e) {
      this.rollbackAgreeMode(previousAgreeMode)
      this.handleUpdateJoinManageModeError(e as V2NIMError)
    }
  }

  async updateJoinModeToggle(isOn: boolean) {
    const teamInfo = this.teamInfo
    if (!teamInfo) {
      this.syncJoinManageToggleState()
      return
    }

    const previousJoinMode = this.joinModeValue
    this.joinModeToggleOn = isOn
    this.joinModeValue = getJoinModeByToggleState(isOn)

    if (!ErrorUtils.checkNetworkAndToast()) {
      this.rollbackJoinMode(previousJoinMode)
      return
    }

    const param: V2NIMUpdateTeamInfoParams = {
      joinMode: this.joinModeValue
    }

    try {
      await TeamRepo.updateTeamInfo(teamInfo.teamId, teamInfo.teamType, param)
    } catch (e) {
      this.rollbackJoinMode(previousJoinMode)
      this.handleUpdateJoinManageModeError(e as V2NIMError)
    }
  }

  private applyTeamInfo(teamInfo?: V2NIMTeam) {
    this.teamInfo = teamInfo
    this.agreeModeValue = teamInfo?.agreeMode
    this.joinModeValue = teamInfo?.joinMode
    this.syncJoinManageToggleState()
  }

  private syncJoinManageToggleState() {
    this.agreeModeToggleOn = getAgreeModeToggleState(this.agreeModeValue)
    this.joinModeToggleOn = getJoinModeToggleState(this.joinModeValue)
  }

  private rollbackAgreeMode(previousAgreeMode?: V2NIMTeamAgreeMode) {
    this.agreeModeValue = previousAgreeMode
    this.agreeModeToggleOn = getAgreeModeToggleState(previousAgreeMode)
  }

  private rollbackJoinMode(previousJoinMode?: V2NIMTeamJoinMode) {
    this.joinModeValue = previousJoinMode
    this.joinModeToggleOn = getJoinModeToggleState(previousJoinMode)
  }

  private handleUpdateJoinManageModeError(error: V2NIMError) {
    if (error.code === V2NIMErrorCode.V2NIM_ERROR_CODE_TEAM_OWNER_OR_MANAGER_OPERATION_PERMISSION_REQUIRED) {
      NECommonUtils.showToast($r('app.string.team_operate_no_permission_tip'))
      return
    }
    ChatKitClient.logger?.debug(`update join manage mode error = ${error.message}`)
  }

  /**
   * 初始化监听
   */
  initTeamListener() {
    ChatKitClient.nim.teamService?.on('onTeamInfoUpdated', this.onTeamInfoUpdated.bind(this))
    ChatKitClient.nim.teamService?.on('onSyncFinished', this.onSyncFinished.bind(this))
    ChatKitClient.nim?.teamService?.on('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated.bind(this))
  }

  destroy() {
    ChatKitClient.nim.teamService?.off('onTeamInfoUpdated', this.onTeamInfoUpdated)
    ChatKitClient.nim.teamService?.off('onSyncFinished', this.onSyncFinished)
    ChatKitClient.nim?.teamService?.off('onTeamMemberInfoUpdated', this.onTeamMemberInfoUpdated)
  }
}
