/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils, NEFriendUserCache, NEUserWithFriend, PersonSelectParam } from '@nimkit/chatkit';
import { AvatarColorUntil, AvatarItem, CommonAvatar, NavigationBackBuilder } from '@nimkit/common';
import { BlocklistViewModel } from '../viewmodel/BlocklistViewModel';

interface BlockListItemBuilderParams {
  users: NEUserWithFriend[];
  titleIconSize?: number;
  titleFontSize?: number;
  backgroundColor?: ResourceColor;
  showDivideLine?: boolean;
  itemHeight?: number;
  onClick?: (accountId: string | undefined) => void;
}

@Builder
export function BlockListItemBuilder(params: BlockListItemBuilderParams) {
  ForEach(params.users, (item: NEUserWithFriend) => {
    ListItem() {
      Column() {
        Row() {
          CommonAvatar({
            item: new AvatarItem(item.user?.avatar, item.shortName(),
              AvatarColorUntil.getBackgroundColorById(item.user?.accountId ?? ""))
          })
            .width(params.titleIconSize ?? 36)
            .height(params.titleIconSize ?? 36)
            .borderRadius((params.titleIconSize ?? 36 / 2))
            .margin({ left: 20 })

          Text(item.showName())
            .fontSize(params.titleFontSize ?? 14)
            .fontColor("#333333")
            .height(18)
            .margin({ left: 12, right: 12 })
            .layoutWeight(2)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row()
            .layoutWeight(1)

          Button($r('app.string.contact_blockList_relieve'), { type: ButtonType.Normal })
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
              if (params.onClick) {
                params.onClick(item.user?.accountId)
              }
            })
        }
        .width('100%')
        .height(params.itemHeight ?? 60)

        if (params.showDivideLine ?? true) {
          Row()
            .width('100%')
            .height(1)
            .backgroundColor('#F5F8FC')
            .margin({ left: 40 })
        }
      }
      .width('100%')
      .height(params.itemHeight)
      .backgroundColor(params.backgroundColor ?? Color.White)
      .onClick(() => {

      })
    }
  })
}

// 跳转页面入口函数
@Builder
export function BlockListPageBuilder() {
  BlockListPage()
}

@ComponentV2
export struct BlockListPage {
  pathStack: NavPathStack = new NavPathStack()
  viewModel: BlocklistViewModel = new BlocklistViewModel()
  // 添加黑名单，【确定】按钮点击事件
  onClickSureButton = async (selectedList: NEUserWithFriend[]) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      try {
        this.pathStack.pop()
        await this.viewModel.addUserToBlockList(selectedList)
      } catch (err) {
        console.error(err)
      }
    }
  }

  async requestData(): Promise<void> {
    try {
      await this.viewModel.getBlockList()
    } catch (err) {
      console.error(err)
    }
  }

  // 【解除】按钮点击事件
  onRemoveClick = (accountId?: string) => {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (accountId) {
        this.viewModel.removeUserFromBlockList(accountId)
      }
    }
  }
  // 【➕】按钮点击事件
  onAddClick = () => {
    this.pathStack.pushPath({
      name: 'PersonSelectPage',
      param: new PersonSelectParam(this.onClickSureButton, [], 10)
    })
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.contact_blocklist'),
          showDivideLine: true,
          rightButtonIcon: $r('app.media.contact_block_add'),
          rightButtonAction: this.onAddClick,
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Row() {
          Text($r('app.string.contact_blockList_tip'))
            .fontSize(14)
            .fontColor('#B3B7BC')
            .width('100%')
            .margin({ left: 20 })
        }
        .width('100%')
        .height(48)
        .alignSelf(ItemAlign.Center)

        List() {
          BlockListItemBuilder({
            users: this.viewModel.blockList,
            onClick: this.onRemoveClick
          })
        }
        .width('100%')
        .backgroundColor('#EFF1F4')
        .margin({
          bottom: 104
        })
      }
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
