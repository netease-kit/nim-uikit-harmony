/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatKitClient, ErrorUtils, IMKitConfigCenter } from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  GetUnreadCountStr,
  NavigationBackBuilder
} from '@nimkit/common';
import {
  V2NIMFriendAddApplication,
  V2NIMFriendAddApplicationStatus,
  V2NIMTeamJoinActionInfo,
  V2NIMTeamJoinActionStatus,
  V2NIMTeamJoinActionType
} from '@nimsdk/base';
import { NEFriendAddApplication } from '../model/NEFriendAddApplication';
import {
  getTeamVerifyActionTextType,
  shouldShowTeamVerifyActionButtons,
  TeamVerifyActionTextType,
  TeamVerifyInfoBean
} from '../model/TeamVerifyInfoBean';
import { ValidationMessageViewModel } from '../viewmodel/ValidationMessageViewModel';
import { TeamVerifyViewModel } from '../viewmodel/TeamVerifyViewModel';


interface ValidationMessageItemBuilderParams {
  application: NEFriendAddApplication;
  titleIconSize?: number;
  titleFontSize?: number;
  backgroundColor?: ResourceColor;
  itemHeight?: number;
  onAcceptClick?: (application?: V2NIMFriendAddApplication) => void;
  onRefuseClick?: (application?: V2NIMFriendAddApplication) => void;
}

@Builder
export function ValidationMessageItemBuilder($$: ValidationMessageItemBuilderParams) {
  Column() {
    Row() {
      Stack({
        alignContent: Alignment.TopEnd
      }) {
        CommonAvatar({
          item: new AvatarItem($$.application.displayUserWithFriend?.user?.avatar,
            $$.application.displayUserWithFriend?.shortName(),
            AvatarColorUntil.getBackgroundColorById($$.application.displayUserWithFriend?.user?.accountId ?? ""))
        })
          .width($$.titleIconSize ?? 36)
          .height($$.titleIconSize ?? 36)

        if ($$.application.unreadCount > 1) {
          Text(GetUnreadCountStr($$.application.unreadCount))
            .fontSize(12)
            .fontColor('#ffFFFFFF')
            .textAlign(TextAlign.Center)
            .backgroundColor('#ffF24957')
            .borderRadius(20)
            .height(18)
            .width(18 + (GetUnreadCountStr($$.application.unreadCount).length - 1) * 4)
        }

      }
      .width(36)
      .height(36)
      .margin({ left: 20 })

      Column({ space: 4 }) {
        Text($$.application.displayUserWithFriend?.showName())
          .fontSize($$.titleFontSize ?? 14)
          .fontColor("#333333")
          .height(16)
          .width('100%')
          .margin({ top: 12 })
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text($$.application.description)
          .fontSize(($$.titleFontSize ?? 14) - 1)
          .fontColor("#333333")
          .height(16)
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height($$.itemHeight ?? 60)
      .margin({ left: 12, right: 12 })
      .layoutWeight(1)
      .alignSelf(ItemAlign.Start)

      if ($$.application.friendAddApplication.applicantAccountId !== ChatKitClient.getLoginUserId()) { // 未处理
        if ($$.application.status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT) {
          Button($r('app.string.contact_validation_refuse'), { type: ButtonType.Normal })
            .height(32)
            .constraintSize({ minWidth: 62 })
            .padding({ left: 10, right: 10 })
            .margin({ right: 16 })
            .fontSize(14)
            .fontColor('#333333')
            .borderWidth(1)
            .borderColor('#D9D9D9')
            .borderRadius(4)
            .backgroundColor(Color.White)
            .onClick(() => {
              if ($$.onRefuseClick) {
                $$.onRefuseClick($$.application.friendAddApplication)
              }
            })

          Button($r('app.string.contact_validation_accept'), { type: ButtonType.Normal })
            .height(32)
            .constraintSize({ minWidth: 62 })
            .padding({ left: 10, right: 10 })
            .margin({ right: 20 })
            .fontSize(14)
            .fontColor('#337EFF')
            .borderWidth(1)
            .borderColor('#337EFF')
            .borderRadius(4)
            .backgroundColor(Color.White)
            .onClick(() => {
              if ($$.onAcceptClick) {
                $$.onAcceptClick($$.application.friendAddApplication)
              }
            })
        }

        // 已同意/直接添加
        if ($$.application.status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_AGREED ||
          $$.application.status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_DIRECT_ADD) {
          Image($r('app.media.validation_accepted'))
            .width(16)
            .height(16)
            .margin({ right: 6 })

          Text($r('app.string.contact_validation_accepted'))
            .fontSize(14)
            .fontColor('#B3B7BC')
            .width(42)
            .height(16)
            .margin({ right: 20 })
        }

        // 已拒绝/已过期
        if ($$.application.status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_REJECTED ||
          $$.application.status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_EXPIRED) {
          Image($r('app.media.validation_refused'))
            .width(16)
            .height(16)
            .margin({ right: 6 })

          Text($$.application.status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_REJECTED ?
          $r('app.string.contact_validation_refused') :
          $r('app.string.contact_validation_expired'))
            .fontSize(14)
            .fontColor('#B3B7BC')
            .width(42)
            .height(16)
            .margin({ right: 20 })
        }
      }
    }
    .width('100%')
    .height($$.itemHeight ?? 60)
  }
  .width('100%')
  .height($$.itemHeight ?? 60)
  .backgroundColor($$.application.unreadCount > 0 ? '#F3F5F7' : $$.backgroundColor ?? Color.White)
}

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
            $$.bean.operatorUser?.shortName() ?? '',
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
export function ValidationMessagePageBuilder() {
  ValidationMessagePage()
}

@ComponentV2
export struct ValidationMessagePage {
  pathStack: NavPathStack = new NavPathStack()
  @Local currentTabIndex: number = 0
  @Local friendViewModel: ValidationMessageViewModel = new ValidationMessageViewModel()
  @Local teamViewModel: TeamVerifyViewModel = new TeamVerifyViewModel()
  hasPop: boolean = false
  
  // 返回前设置验证消息已读
  backAction = async () => {
    this.hasPop = true
    try {
      await this.friendViewModel.setAddApplicationRead()
      if (IMKitConfigCenter.enableTeam) {
        await this.teamViewModel.setVerifyRead()
      }
      this.pathStack.pop(0)
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  async requestData(): Promise<void> {
    try {
      await this.friendViewModel.getAddApplicationList()
      if (IMKitConfigCenter.enableTeam) {
        await this.teamViewModel.getVerifyList()
      }
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  // 【好友】同意按钮点击事件
  onFriendAcceptClick = (application?: V2NIMFriendAddApplication) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (application) {
        this.friendViewModel.acceptAddApplication(application)
      }
    }
  }
  
  // 【好友】拒绝按钮点击事件
  onFriendRefuseClick = (application?: V2NIMFriendAddApplication) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (application) {
        this.friendViewModel.rejectAddApplication(application)
      }
    }
  }
  
  // 【好友】清空按钮点击事件
  onFriendCleanClick = () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      this.friendViewModel.clearAllAddApplication()
    }
  }

  // 【群】同意按钮点击事件
  onTeamAcceptClick = (actionInfo: V2NIMTeamJoinActionInfo) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (actionInfo.actionType === V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION) {
        this.teamViewModel.acceptApplication(actionInfo)
      } else {
        this.teamViewModel.acceptInvitation(actionInfo)
      }
    }
  }

  // 【群】拒绝按钮点击事件
  onTeamRefuseClick = (actionInfo: V2NIMTeamJoinActionInfo) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (actionInfo.actionType === V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION) {
        this.teamViewModel.rejectApplication(actionInfo)
      } else {
        this.teamViewModel.rejectInvitation(actionInfo)
      }
    }
  }

  // 【群】清空按钮点击事件
  onTeamCleanClick = () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      this.teamViewModel.clearAll()
    }
  }

  @Builder
  tabBuilder(index: number, name: ResourceStr) {
    Column() {
      Text(name)
        .height(16)
        .fontColor(this.currentTabIndex === index ? '#337EFF' : '#333333')
        .font({
          size: 14,
          weight: this.currentTabIndex === index ? 500 : 400
        })
        .margin({
          top: 10,
          bottom: 10
        })

      Divider()
        .strokeWidth(2)
        .color('#337EFF')
        .opacity(this.currentTabIndex === index ? 1 : 0)
    }
    .width('100%')
    .height(40)
    .backgroundColor(Color.White)
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.contact_validation_message'),
          showDivideLine: true,
          rightButtonTitle: $r('app.string.contact_clean'),
          rightButtonColor: "#666666",
          rightButtonAction: () => {
            // 根据当前 Tab 执行对应的清空操作
            if (this.currentTabIndex === 0) {
              this.onFriendCleanClick()
            } else {
              this.onTeamCleanClick()
            }
          },
          leftButtonAction: () => {
            this.backAction()
          }
        })

        // 如果启用了群功能，显示 Tabs，否则只显示好友验证
        if (IMKitConfigCenter.enableTeam) {
          Tabs({ barPosition: BarPosition.Start, index: this.currentTabIndex }) {
            // 好友 Tab
            TabContent() {
              Column() {
                if (this.friendViewModel.friendAddApplications.length <= 0) {
                  CommonEmptyResult({
                    tips: $r('app.string.validation_empty')
                  })
                    .margin({
                      top: 74
                    })
                } else {
                  List() {
                    ForEach(this.friendViewModel.friendAddApplications, (item: NEFriendAddApplication) => {
                      ListItem() {
                        ValidationMessageItemBuilder({
                          application: item,
                          onAcceptClick: this.onFriendAcceptClick,
                          onRefuseClick: this.onFriendRefuseClick
                        })
                      }
                    })
                  }
                  .width('100%')
                  .backgroundColor(Color.White)
                  .divider({
                    strokeWidth: 1,
                    startMargin: 20,
                    endMargin: 20,
                    color: '#EFF1F4'
                  })
                }
              }
              .width('100%')
              .height('100%')
              .backgroundColor(Color.White)
            }
            .tabBar(this.tabBuilder(0, $r('app.string.verify_tab_friend')))

            // 群 Tab
            TabContent() {
              Column() {
                if (this.teamViewModel.verifyList.length <= 0) {
                  CommonEmptyResult({
                    tips: $r('app.string.team_verify_empty')
                  })
                    .margin({
                      top: 74
                    })
                } else {
                  List() {
                    ForEach(this.teamViewModel.verifyList, (item: TeamVerifyInfoBean) => {
                      ListItem() {
                        TeamVerifyItemBuilder({
                          bean: item,
                          onAcceptClick: this.onTeamAcceptClick,
                          onRefuseClick: this.onTeamRefuseClick
                        })
                      }
                    })
                  }
                  .width('100%')
                  .backgroundColor(Color.White)
                  .divider({
                    strokeWidth: 1,
                    startMargin: 20,
                    endMargin: 20,
                    color: '#EFF1F4'
                  })
                }
              }
              .width('100%')
              .height('100%')
              .backgroundColor(Color.White)
            }
            .tabBar(this.tabBuilder(1, $r('app.string.verify_tab_team')))
          }
          .width('100%')
          .layoutWeight(1)
          .barMode(BarMode.Fixed)
          .barHeight(40)
          .backgroundColor(Color.White)
          .onChange((index: number) => {
            this.currentTabIndex = index
          })
        } else {
          // 没有启用群功能，只显示好友验证列表
          Column() {
            if (this.friendViewModel.friendAddApplications.length <= 0) {
              CommonEmptyResult({
                tips: $r('app.string.validation_empty')
              })
                .margin({
                  top: 74
                })
            } else {
              List() {
                ForEach(this.friendViewModel.friendAddApplications, (item: NEFriendAddApplication) => {
                  ListItem() {
                    ValidationMessageItemBuilder({
                      application: item,
                      onAcceptClick: this.onFriendAcceptClick,
                      onRefuseClick: this.onFriendRefuseClick
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
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor(Color.White)
        }
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
        this.friendViewModel.setAddApplicationRead()
        if (IMKitConfigCenter.enableTeam) {
          this.teamViewModel.setVerifyRead()
        }
      }
    })
    .onBackPressed(() => {
      this.backAction()
      return true;
    })
    .onDisAppear(() => {
      this.friendViewModel.onDestroy()
      if (IMKitConfigCenter.enableTeam) {
        this.teamViewModel.onDestroy()
      }
    })
  }
}
