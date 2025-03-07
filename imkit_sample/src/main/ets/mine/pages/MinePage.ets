/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMUser } from '@nimsdk/base';
import { ViewItem } from '@nimkit/common/src/main/ets/model/ViewItem';
import { AvatarColorUntil, AvatarItem, CommonAvatar, CommonConstants, ViewItemBuilder } from '@nimkit/common';
import { ChatKitClient, NEFriendUserCache } from '@nimkit/chatkit';

// 跳转页面入口函数
@Builder
function MinePageBuilder() {
  MinePage()
}

PersistentStorage.persistProp(CommonConstants.KEY_SETTING_EARPIECE_MODE, true)
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_MESSAGE_READ_OR, true)

@ComponentV2
export struct MinePage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Local myUser?: V2NIMUser = NEFriendUserCache.mineUserCache?.user;
  @Local mineItems: ViewItem[] = [
    {
      avatarItem: new AvatarItem($r('app.media.mine_setting')),
      title: $r("app.string.mine_setting"),
      itemHeight: 52,
      titleIconSize: 24,
      titleFontSize: 16,
      routerUrl: "SettingPage"
    },
    {
      avatarItem: new AvatarItem($r('app.media.mine_collection')),
      title: $r("app.string.chat_operation_collection"),
      itemHeight: 52,
      titleIconSize: 24,
      titleFontSize: 16,
      routerUrl: "CollectionMessagePage"
    },
    {
      avatarItem: new AvatarItem($r('app.media.mine_about')),
      title: $r("app.string.mine_about"),
      itemHeight: 52,
      titleIconSize: 24,
      titleFontSize: 16,
      routerUrl: "AboutPage"
    },
  ]

  getAvatarName(): string {
    let user = NEFriendUserCache.mineUserCache?.user
    let avatarName = ChatKitClient.getLoginUserId()
    if (user && user.name.length > 0) {
      if (user.name.length > 2) {
        avatarName = user.name.substring(user.name.length - 2, user.name.length)
      } else {
        avatarName = user.name
      }
    }
    return avatarName
  }

  build() {
    NavDestination() {
      Column({ space: 6 }) {
        Row() {
          CommonAvatar({
            item: new AvatarItem(NEFriendUserCache.mineUserCache?.user?.avatar,
              this.getAvatarName(),
              AvatarColorUntil.getBackgroundColorById(NEFriendUserCache.mineUserCache?.user?.accountId ?? "")),
            roundRadius: 30,
            textSize: 22
          })
            .width(60)
            .height(60)
            .margin({ left: 20 })
            .borderRadius(30)

          Column({ space: 8 }) {

            Text(NEFriendUserCache.mineUserCache?.user?.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text($r("app.string.mine_account_id_tip", NEFriendUserCache.mineUserCache?.user?.accountId))
              .fontSize(16)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .copyOption(CopyOptions.LocalDevice)
          }
          .layoutWeight(1)
          .margin({ left: 16, right: 16 })
          .alignItems(HorizontalAlign.Start)

          Image($r('app.media.arrow_right'))
            .width(4.92)
            .height(9.54)
            .margin({ right: 36 })
        }
        .width('100%')
        .height(143)
        .backgroundColor(Color.White)
        .onClick(() => {
          this.pathStack.pushPath({
            name: 'MineInfoPage'
          })
        })

        List() {
          ForEach(this.mineItems, (item: ViewItem) => {
            ListItem() {
              ViewItemBuilder(item)
            }
            .onClick(() => {
              this.pathStack.pushPath({
                name: item.routerUrl
              })
            })
          })
        }
        .height('100%')
        .width('100%')
        .backgroundColor(Color.White)
      }
      .width('100%')
      .height('100%')
      .backgroundColor("#EFF1F4")
    }
    .hideTitleBar(true)
  }
}
