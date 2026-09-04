/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatKitClient, ErrorUtils } from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  NavigationBackBuilder
} from '@nimkit/common';
import {
  V2NIMTeamJoinActionInfo,
  V2NIMTeamJoinActionStatus,
  V2NIMTeamJoinActionType
} from '@nimsdk/base';
import {
  getTeamVerifyActionTextType,
  shouldShowTeamVerifyActionButtons,
  TeamVerifyActionTextType,
  TeamVerifyInfoBean
} from '../model/TeamVerifyInfoBean';
import { TeamVerifyViewModel } from '../viewmodel/TeamVerifyViewModel';

/**
 * 格式化未读数：超过 99 显示 "99+"
 */
function getUnreadCountStr(unreadCount: number): string {
  if (unreadCount < 100) {
    return unreadCount + ''
  } else {
    return '99+'
  }
}

function getTeamVerifyActionText(actionInfo: V2NIMTeamJoinActionInfo): ResourceStr {
  switch (getTeamVerifyActionTextType(actionInfo)) {
    case TeamVerifyActionTextType.ACCEPT_APPLICATION:
      return $r('app.string.team_verify_accept_application')
    case TeamVerifyActionTextType.REJECT_APPLICATION:
      return $r('app.string.team_verify_reject_application')
    case TeamVerifyActionTextType.ACCEPT_INVITATION:
      return $r('app.string.team_verify_accept_invitation')
    case TeamVerifyActionTextType.REJECT_INVITATION:
      return $r('app.string.team_verify_reject_invitation')
    case TeamVerifyActionTextType.INVITATION:
      return $r('app.string.team_verify_invitation')
    case TeamVerifyActionTextType.APPLICATION:
    default:
      return $r('app.string.team_verify_application')
  }
}

function getTeamVerifyTargetText(bean: TeamVerifyInfoBean): string {
  const teamId = bean.actionInfo.teamId
  const teamName = bean.joinTeam?.name?.trim()
  if (teamName && teamName.length > 0 && teamName !== teamId) {
    return `${teamName} (${teamId})`
  }
  return teamName && teamName.length > 0 ? teamName : teamId
}

@Builder
function TeamVerifyStatusBuilder(status: V2NIMTeamJoinActionStatus) {
  if (status === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_AGREED) {
    Row({ space: 6 }) {
      Image($r('app.media.validation_accepted'))
        .width(16)
        .height(16)

      Text($r('app.string.contact_validation_accepted'))
        .fontSize(14)
        .fontColor('#B3B7BC')
    }
    .margin({ right: 20, top: 16 })
    .alignSelf(ItemAlign.Start)
  }

  if (status === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED ||
    status === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_EXPIRED) {
    Row({ space: 6 }) {
      Image($r('app.media.validation_refused'))
        .width(16)
        .height(16)

      Text(status === V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED ?
      $r('app.string.contact_validation_refused') :
      $r('app.string.contact_validation_expired'))
        .fontSize(14)
        .fontColor('#B3B7BC')
    }
    .margin({ right: 20, top: 16 })
    .alignSelf(ItemAlign.Start)
  }
}

interface TeamVerifyItemBuilderParams {
  bean: TeamVerifyInfoBean;
  onAcceptClick?: (actionInfo: V2NIMTeamJoinActionInfo) => void;
  onRefuseClick?: (actionInfo: V2NIMTeamJoinActionInfo) => void;
}

@Builder
function TeamVerifyItemBuilder($$: TeamVerifyItemBuilderParams) {
  Column() {
    Row() {
      // 头像 + 未读数角标
      Stack({ alignContent: Alignment.TopEnd }) {
        CommonAvatar({
          item: new AvatarItem($$.bean.operatorUser?.user?.avatar,
            $$.bean.operatorUser?.getAvatarName() ?? '',
            AvatarColorUntil.getBackgroundColorById($$.bean.actionInfo.operatorAccountId ?? ''))
        })
          .width(36)
          .height(36)

        // 未读数角标
        if ($$.bean.unreadCount > 1) {
          Text(getUnreadCountStr($$.bean.unreadCount))
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#F24957')
            .borderRadius(10)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .textAlign(TextAlign.Center)
            .constraintSize({ minWidth: 16, minHeight: 16 })
            .translate({ x: 3, y: -3 })
        }
      }
      .width(36)
      .height(36)
      .margin({ left: 20, top: 12 })

      Column({ space: 4 }) {
        // 操作者名称
        Text($$.bean.operatorUser?.showName() ?? $$.bean.actionInfo.operatorAccountId)
          .fontSize(14)
          .fontColor('#333333')
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(getTeamVerifyTargetText($$.bean))
          .fontSize(13)
          .fontColor('#666666')
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(getTeamVerifyActionText($$.bean.actionInfo))
          .fontSize(12)
          .fontColor('#999999')
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .margin({ left: 12, right: 12, top: 10, bottom: 10 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 操作按钮
      if (shouldShowTeamVerifyActionButtons($$.bean.actionInfo, ChatKitClient.getLoginUserId(),
        $$.bean.actionStatus)) {
        Column({ space: 6 }) {
          Button($r('app.string.contact_validation_refuse'), { type: ButtonType.Normal })
            .height(26)
            .constraintSize({ minWidth: 52 })
            .padding({ left: 8, right: 8 })
            .fontSize(12)
            .fontColor('#333333')
            .borderWidth(1)
            .borderColor('#D9D9D9')
            .borderRadius(4)
            .backgroundColor(Color.White)
            .onClick(() => {
              if ($$.onRefuseClick) {
                $$.onRefuseClick($$.bean.actionInfo)
              }
            })

          Button($r('app.string.contact_validation_accept'), { type: ButtonType.Normal })
            .height(26)
            .constraintSize({ minWidth: 52 })
            .padding({ left: 8, right: 8 })
            .fontSize(12)
            .fontColor('#337EFF')
            .borderWidth(1)
            .borderColor('#337EFF')
            .borderRadius(4)
            .backgroundColor(Color.White)
            .onClick(() => {
              if ($$.onAcceptClick) {
                $$.onAcceptClick($$.bean.actionInfo)
              }
            })
        }
        .margin({ right: 20, top: 12 })
        .alignSelf(ItemAlign.Start)
      }

      if ($$.bean.actionStatus !== V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT) {
        TeamVerifyStatusBuilder($$.bean.actionStatus)
      }
    }
    .width('100%')
    .height(84)
  }
  .width('100%')
  .height(84)
  .backgroundColor($$.bean.unreadCount > 0 ? '#F3F5F7' : Color.White)
}

// 跳转页面入口函数
@Builder
export function TeamVerifyPageBuilder() {
  TeamVerifyPage()
}

@ComponentV2
export struct TeamVerifyPage {
  pathStack: NavPathStack = new NavPathStack()
  viewModel: TeamVerifyViewModel = new TeamVerifyViewModel()
  hasPop: boolean = false

  backAction = async () => {
    this.hasPop = true
    try {
      await this.viewModel.setVerifyRead()
      this.pathStack.pop(0)
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  async requestData(): Promise<void> {
    try {
      await this.viewModel.getVerifyList()
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  onAcceptClick = (actionInfo: V2NIMTeamJoinActionInfo) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (actionInfo.actionType === V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION) {
        this.viewModel.acceptApplication(actionInfo)
      } else {
        this.viewModel.acceptInvitation(actionInfo)
      }
    }
  }

  onRefuseClick = (actionInfo: V2NIMTeamJoinActionInfo) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (actionInfo.actionType === V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION) {
        this.viewModel.rejectApplication(actionInfo)
      } else {
        this.viewModel.rejectInvitation(actionInfo)
      }
    }
  }

  onCleanClick = () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      this.viewModel.clearAll()
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.team_verify_title'),
          showDivideLine: true,
          rightButtonTitle: $r('app.string.contact_clean'),
          rightButtonColor: '#666666',
          rightButtonAction: this.onCleanClick,
          leftButtonAction: () => {
            this.backAction()
          }
        })

        if (this.viewModel.verifyList.length <= 0) {
          CommonEmptyResult({
            tips: $r('app.string.team_verify_empty')
          })
            .margin({
              top: 74
            })
        }

        List() {
          ForEach(this.viewModel.verifyList, (item: TeamVerifyInfoBean) => {
            ListItem() {
              TeamVerifyItemBuilder({
                bean: item,
                onAcceptClick: this.onAcceptClick,
                onRefuseClick: this.onRefuseClick
              })
            }
          })
        }
        .width('100%')
        .backgroundColor(Color.White)
        .margin({
          bottom: 56
        })
        .divider({
          strokeWidth: 1,
          startMargin: 20,
          endMargin: 20,
          color: '#EFF1F4'
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
    .onHidden(() => {
      if (!this.hasPop) {
        this.viewModel.setVerifyRead()
      }
    })
    .onBackPressed(() => {
      this.backAction()
      return true
    })
    .onDisAppear(() => {
      this.viewModel.onDestroy()
    })
  }
}
