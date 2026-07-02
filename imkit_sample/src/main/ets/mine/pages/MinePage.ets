/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMUser } from '@nimsdk/base';
import { AvatarColorUntil, AvatarItem, CommonAvatar, ViewItemBuilder } from '@nimkit/common';
import { ChatKitClient, ContactRepo, IMKitConfigCenter, NEFriendUserCache } from '@nimkit/chatkit';
import {
  resolveMineAvatarName,
  resolveMineDisplayAccountId,
  resolveMineDisplayName,
  resolveMineUser
} from '../viewmodel/MineProfileUtils';

// 跳转页面入口函数
@Builder
function MinePageBuilder() {
  MinePage()
}

@ComponentV2
export struct MinePage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Local myUser?: V2NIMUser = resolveMineUser(NEFriendUserCache.mineUserCache?.user, ChatKitClient.getLoginUserId());

  getAvatarName(): string {
    return resolveMineAvatarName(this.myUser, ChatKitClient.getLoginUserId())
  }

  aboutToAppear(): void {
    this.refreshMineUserFromCache()
    ChatKitClient.nim.userService?.off('onUserProfileChanged', this.onUserProfileChanged)
    ChatKitClient.nim.userService?.on('onUserProfileChanged', this.onUserProfileChanged)
    this.loadMineUser()
  }

  aboutToDisappear(): void {
    ChatKitClient.nim.userService?.off('onUserProfileChanged', this.onUserProfileChanged)
  }

  private refreshMineUserFromCache(): void {
    const loginUserId = ChatKitClient.getLoginUserId()
    this.myUser = resolveMineUser(NEFriendUserCache.mineUserCache?.user, loginUserId)
  }

  private async loadMineUser(): Promise<void> {
    try {
      const users = await ContactRepo.getUserListFromCloud([ChatKitClient.getLoginUserId()])
      if (users.length > 0 && users[0].accountId === ChatKitClient.getLoginUserId()) {
        this.myUser = users[0]
      }
    } catch (e) {
      console.error(`MinePage loadMineUser failed: ${e}`)
    }
  }

  private onUserProfileChanged = (users: V2NIMUser[]) => {
    const loginUserId = ChatKitClient.getLoginUserId()
    const mineUser = users.find((user: V2NIMUser) => user.accountId === loginUserId)
    if (mineUser) {
      if (NEFriendUserCache.mineUserCache) {
        NEFriendUserCache.mineUserCache.user = mineUser
      }
      this.myUser = mineUser
    }
  }

  build() {
    NavDestination() {
      Column({ space: 6 }) {
        Row() {
          CommonAvatar({
            item: new AvatarItem(this.myUser?.avatar,
              this.getAvatarName(),
              AvatarColorUntil.getBackgroundColorById(resolveMineDisplayAccountId(this.myUser, ChatKitClient.getLoginUserId()))),
            roundRadius: 30,
            textSize: 22
          })
            .width(60)
            .height(60)
            .margin({ left: 20 })
            .borderRadius(30)

          Column({ space: 8 }) {

            Text(resolveMineDisplayName(this.myUser, ChatKitClient.getLoginUserId()))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text($r("app.string.mine_account_id_tip", resolveMineDisplayAccountId(this.myUser, ChatKitClient.getLoginUserId())))
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
          // 设置
          ListItem() {
            ViewItemBuilder({
              avatarItem: new AvatarItem($r('app.media.mine_setting')),
              title: $r("app.string.mine_setting"),
              itemHeight: 52,
              titleIconSize: 24,
              titleFontSize: 16,
              routerUrl: "SettingPage"
            })
          }
          .onClick(() => {
            this.pathStack.pushPath({ name: 'SettingPage' })
          })

          // 收藏（根据配置显示/隐藏）
          if (IMKitConfigCenter.enableCollection) {
            ListItem() {
              ViewItemBuilder({
                avatarItem: new AvatarItem($r('app.media.mine_collection')),
                title: $r("app.string.chat_operation_collection"),
                itemHeight: 52,
                titleIconSize: 24,
                titleFontSize: 16,
                routerUrl: "CollectionMessagePage"
              })
            }
            .onClick(() => {
              this.pathStack.pushPath({ name: 'CollectionMessagePage' })
            })
          }

          // 关于
          ListItem() {
            ViewItemBuilder({
              avatarItem: new AvatarItem($r('app.media.mine_about')),
              title: $r("app.string.mine_about"),
              itemHeight: 52,
              titleIconSize: 24,
              titleFontSize: 16,
              routerUrl: "AboutPage"
            })
          }
          .onClick(() => {
            this.pathStack.pushPath({ name: 'AboutPage' })
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
