/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ErrorUtils, NEFriendUserCache, NEUserWithFriend } from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  NavigationBackBuilder,
  StringIsEmpty,
  TailString
} from '@nimkit/common';
import { EditType, PersonInfoArrowItem, PersonInfoItem, PersonInfoSwitchItem } from '../model/MineInfoItem';
import { PersonInfoViewModel } from '../viewmodel/PersonInfoViewModel';
import { EditInfoParam } from './EditInfoPage';

/// 删除好友底部悬浮弹窗
@CustomDialog
export struct DeleteFriendDialog {
  controller?: CustomDialogController
  userWithFriend?: NEUserWithFriend
  alias?: string
  // 【删除好友】按钮点击事件
  onDeleteFriendClick = async () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      const accountId = this.userWithFriend?.user?.accountId
      if (accountId) {
        try {
          await ContactRepo.deleteFriend(accountId, { deleteAlias: true })
        } catch (err) {
          console.error(err)
        }
      }
      this.controller?.close()
    }
  }
  // 【取消】按钮点击事件
  cancel = () => {
    this.controller?.close()
  }

  build() {
    Column() {
      Column() {
        Text($r('app.string.person_info_delete_tip', this.alias ?? this.userWithFriend?.user?.name))
          .fontSize(13)
          .fontColor("#8F8F8F")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')

        Row()
          .height(1)
          .width('100%')
          .backgroundColor("#EFF1F4")

        Text($r('app.string.person_info_delete'))
          .fontSize(14)
          .fontColor("#E6605C")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.onDeleteFriendClick)
      }
      .height(85)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 12, right: 12 })

      Column() {
        Text($r('app.string.mine_edit_cancel'))
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.cancel)
      }
      .height(42)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ top: 10, left: 12, right: 12 })

    }
    .backgroundColor(Color.Transparent)
  }
}

@Builder
export function PersonInfoItemBuilder(item: PersonInfoItem | PersonInfoArrowItem | PersonInfoSwitchItem) {
  Column() {
    Row() {
      Text(item.title)
        .height(18)
        .margin({ left: 20 })
        .layoutWeight(1)

      if (item.subTitle !== undefined) {
        Text(item.subTitle)
          .fontSize(14)
          .fontColor('#A6ADB6')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ right: 20 })
          .textAlign(TextAlign.End)
          .layoutWeight(2)
          .height(38)
          .copyOption(CopyOptions.LocalDevice)
      }

      if ((item as PersonInfoArrowItem).rightIcon !== undefined) {
        Image((item as PersonInfoArrowItem).rightIcon)
          .width(4.92)
          .height(9.54)
          .margin({ right: 21.54 })
      }

      if ((item as PersonInfoSwitchItem).switchChange !== undefined) {
        Toggle({ type: ToggleType.Switch, isOn: (item as PersonInfoSwitchItem).isOpen })
          .selectedColor("#337EFF")
          .width(46)
          .height(28)
          .margin({ right: 16 })
          .onChange((item as PersonInfoSwitchItem).switchChange)
      }
    }
    .height((item.itemHeight ?? 1) - 1)
    .alignSelf(ItemAlign.Center)

    Row()
      .height(1)
      .width('100%')
      .backgroundColor('#F5F8FC')
      .margin({ left: 32 })
  }
  .width('100%')
  .height(item.itemHeight)
}

// 跳转页面入口函数
@Builder
export function PersonInfoPageBuilder() {
  PersonInfoPage()
}

@ComponentV2
export struct PersonInfoPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: PersonInfoViewModel = new PersonInfoViewModel()
  @Local alias?: string =
    StringIsEmpty(this.viewModel.userWithFriend?.friend?.alias) ? undefined :
      this.viewModel.userWithFriend?.friend?.alias
  @Local isBlock: boolean = false
  @Local personInfoItems1: PersonInfoArrowItem[] = [
    new PersonInfoArrowItem($r("app.string.person_info_alias"))
  ]
  @Local personInfoItems2: PersonInfoItem[] = []
  @Local personInfoItems3: PersonInfoSwitchItem[] = []
  deleteFriendDialog: CustomDialogController = new CustomDialogController({
    builder: DeleteFriendDialog({
      userWithFriend: this.viewModel.userWithFriend,
      alias: this.alias
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    height: 140,
  })

  getGenderString() {
    return this.viewModel.userWithFriend?.user?.gender === 2 ? $r("app.string.person_gender_female") :
      (this.viewModel.userWithFriend?.user?.gender === 1 ? $r("app.string.person_gender_male") :
      $r("app.string.person_gender_unknown"))
  }

  async requestData(): Promise<void> {
    const accountId = this.pathStack.getParamByName("PersonInfoPage")[0] as string
    this.viewModel.init(accountId).then(() => {
      this.alias = StringIsEmpty(this.viewModel.userWithFriend?.friend?.alias) ? undefined :
        this.viewModel.userWithFriend?.friend?.alias
      this.isBlock = NEFriendUserCache.getInstance().isBlockAccount(this.viewModel.accountId)

      this.personInfoItems2 = [
        new PersonInfoItem($r("app.string.person_info_gender"), this.getGenderString()),
        new PersonInfoItem($r('app.string.person_info_birthday'), this.viewModel.userWithFriend?.user?.birthday),
        new PersonInfoItem($r('app.string.person_info_mobile'), this.viewModel.userWithFriend?.user?.mobile),
        new PersonInfoItem($r('app.string.person_info_email'), this.viewModel.userWithFriend?.user?.email),
        new PersonInfoItem($r('app.string.person_info_sign'), this.viewModel.userWithFriend?.user?.sign, 66),
      ]

      this.personInfoItems3 = [
      // new PersonInfoSwitchItem($r("app.string.person_setting_remind"), true),
        new PersonInfoSwitchItem($r("app.string.person_setting_add_block"), this.isBlock,
          this.viewModel.onAddBlockClick)
      ]
    })
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Row() {
          CommonAvatar({
            item: new AvatarItem(this.viewModel.userWithFriend?.user?.avatar,
              (this.alias?.length ?? 0) > 0 ? TailString(this.alias) : this.viewModel.userWithFriend?.shortName(),
              AvatarColorUntil.getBackgroundColorById(this.viewModel.accountId)),
            roundRadius: 30,
            textSize: 22
          })
            .width(60)
            .height(60)
            .margin({
              left: 20
            })

          Column({ space: 8 }) {
            Text((this.alias?.length ?? 0) > 0 ? this.alias : this.viewModel.userWithFriend?.user?.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .ellipsisMode(EllipsisMode.CENTER)
              .copyOption(CopyOptions.LocalDevice)

            if ((this.alias?.length ?? 0) > 0) {
              Text($r('app.string.mine_account_nick', this.viewModel.userWithFriend?.user?.name))
                .fontSize(12)
                .fontColor('#666666')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .ellipsisMode(EllipsisMode.CENTER)
                .copyOption(CopyOptions.LocalDevice)
            }

            Text($r("app.string.mine_account_id_tip", this.viewModel.userWithFriend?.user?.accountId))
              .fontSize(this.alias ? 12 : 16)
              .fontColor(this.alias ? '#666666' : '#333333')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .ellipsisMode(EllipsisMode.CENTER)
              .copyOption(CopyOptions.LocalDevice)
          }
          .layoutWeight(1)
          .margin({ left: 16, right: 16 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(108)
        .backgroundColor(Color.White)

        Column({ space: 6 }) {
          if (this.viewModel.userWithFriend?.friend) {
            List() {
              ForEach(this.personInfoItems1, (item: PersonInfoArrowItem) => {
                ListItem() {
                  PersonInfoItemBuilder(item)
                }
                .width('100%')
                .height(item.itemHeight)
                .onClick(() => {
                  if ((item as PersonInfoArrowItem).routerUrl !== undefined) {
                    this.pathStack.pushPath({
                      name: (item as PersonInfoArrowItem).routerUrl,
                      param: new EditInfoParam(item.title, this.viewModel.userWithFriend?.friend?.alias, EditType.nick,
                        this.viewModel.userWithFriend?.user?.accountId),
                      onPop: (popInfo: PopInfo) => {
                        const alias = popInfo.result as string
                        this.alias = alias
                      }
                    })
                  }
                })
              })
            }
            .backgroundColor(Color.White)

            List() {
              ForEach(this.personInfoItems2, (item: PersonInfoItem) => {
                ListItem() {
                  PersonInfoItemBuilder(item)
                }
                .width('100%')
                .height(item.itemHeight)
              })
            }
            .backgroundColor(Color.White)

            List() {
              ForEach(this.personInfoItems3, (item: PersonInfoSwitchItem) => {
                ListItem() {
                  PersonInfoItemBuilder(item)
                }
                .width('100%')
                .height(item.itemHeight)
              })
            }
            .backgroundColor(Color.White)
          }

          List() {
            if (this.viewModel.userWithFriend?.friend) {
              ListItem() {
                Column() {
                  Row() {
                    Text($r('app.string.person_info_chat'))
                      .fontColor("#337EFF")
                      .textAlign(TextAlign.Center)
                      .width('100%')
                  }
                  .height(47)
                  .alignItems(VerticalAlign.Center)

                  Row()
                    .height(1)
                    .width('100%')
                    .backgroundColor("#F5F8FC")
                }
              }
              .height(48)
              .onClick(() => {
                this.pathStack.popToName('ChatP2PPage')
                this.pathStack.popToName('ChatTeamPage')
                this.pathStack.replacePath({
                  name: 'ChatP2PPage',
                  param: ChatKitClient.nim.conversationIdUtil.p2pConversationId(this.viewModel.userWithFriend?.user?.accountId)
                })
              })

              ListItem() {
                Column() {
                  Row() {
                    Text($r('app.string.person_info_delete'))
                      .fontColor("#E6605C")
                      .textAlign(TextAlign.Center)
                      .width('100%')
                  }
                  .height(47)
                  .alignItems(VerticalAlign.Center)

                  Row()
                    .height(1)
                    .width('100%')
                    .backgroundColor("#F5F8FC")
                }
              }
              .height(48)
              .onClick(() => {
                this.deleteFriendDialog.open()
              })
            } else {
              ListItem() {
                Column() {
                  Row() {
                    Text($r('app.string.person_info_add'))
                      .fontColor("#337EFF")
                      .textAlign(TextAlign.Center)
                      .width('100%')
                  }
                  .height(47)
                  .alignItems(VerticalAlign.Center)

                  Row()
                    .height(1)
                    .width('100%')
                    .backgroundColor("#F5F8FC")
                }
              }
              .height(48)
              .onClick(this.viewModel.onAddFriendClick)
            }
          }
          .backgroundColor(Color.White)
        }
        .width('100%')
        .margin({
          top: 6,
          bottom: 170
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor("#EFF1F4")
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
    .onDisAppear(() => {
      this.viewModel.onDestroy()
    })
  }
}
