/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ErrorUtils } from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  GetUnreadCountStr,
  NavigationBackBuilder
} from '@nimkit/common';
import { V2NIMFriendAddApplication, V2NIMFriendAddApplicationStatus } from '@nimsdk/base';
import { NEFriendAddApplication } from '../model/NEFriendAddApplication';
import { ValidationMessageViewModel } from '../viewmodel/ValidationMessageViewModel';


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
            .width(62)
            .height(32)
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
            .width(62)
            .height(32)
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

// 跳转页面入口函数
@Builder
export function ValidationMessagePageBuilder() {
  ValidationMessagePage()
}

@ComponentV2
export struct ValidationMessagePage {
  pathStack: NavPathStack = new NavPathStack()
  viewModel: ValidationMessageViewModel = new ValidationMessageViewModel()
  hasPop: boolean = false
  // 返回前设置验证消息已读
  backAction = async () => {
    this.hasPop = true
    try {
      await this.viewModel.setAddApplicationRead()
      this.pathStack.pop(0)
    } catch (err) {
      console.error(err)
    }
  }

  async requestData(): Promise<void> {
    try {
      await this.viewModel.getAddApplicationList()
    } catch (err) {
      console.error(err)
    }
  }

  // 【同意】按钮点击事件
  onAcceptClick = (application?: V2NIMFriendAddApplication) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (application) {
        this.viewModel.acceptAddApplication(application)
      }
    }
  }
  // 【拒绝】按钮点击事件
  onRefuseClick = (application?: V2NIMFriendAddApplication) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (application) {
        this.viewModel.rejectAddApplication(application)
      }
    }
  }
  // 【清空】按钮点击事件
  onCleanClick = () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      this.viewModel.clearAllAddApplication()
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.contact_validation_message'),
          showDivideLine: true,
          rightButtonTitle: $r('app.string.contact_clean'),
          rightButtonColor: "#666666",
          rightButtonAction: this.onCleanClick,
          leftButtonAction: () => {
            this.backAction()
          }
        })

        if (this.viewModel.friendAddApplications.length <= 0) {
          CommonEmptyResult({
            tips: $r('app.string.validation_empty')
          })
            .margin({
              top: 74
            })
        }

        List() {
          ForEach(this.viewModel.friendAddApplications, (item: NEFriendAddApplication) => {
            ListItem() {
              ValidationMessageItemBuilder({
                application: item,
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
        this.viewModel.setAddApplicationRead()
      }
    })
    .onBackPressed(() => {
      this.backAction()
      return true;
    })
    .onDisAppear(() => {
      this.viewModel.onDestroy()
    })
  }
}