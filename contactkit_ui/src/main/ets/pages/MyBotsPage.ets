/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonEmptyResult,
  NavigationBackBuilder,
  TailString,
  VerticalAlertDialog,
  ViewItemBuilder
} from '@nimkit/common';
import { V2NIMUserAIBot } from '@nimsdk/base';
import { MyBotsViewModel } from '../viewmodel/MyBotsViewModel';

@ComponentV2
export struct MyBotsPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: MyBotsViewModel = new MyBotsViewModel()

  private handleBotInfoResult(info: PopInfo): void {
    const recordResult = info.result as Record<string, string | boolean> | undefined
    if (recordResult && recordResult['deleted'] === true) {
      this.viewModel.removeBot(recordResult['accid'] as string)
      return
    }
    const botResult = info.result as V2NIMUserAIBot | undefined
    if (botResult && typeof botResult.accid === 'string' && botResult.accid.length > 0) {
      const updated = this.viewModel.updateBot(botResult)
      if (!updated) {
        this.requestData()
      }
      return
    }
    this.requestData()
  }

  limitDialogController: CustomDialogController = new CustomDialogController({
    builder: VerticalAlertDialog({
      title: $r('app.string.bot_limit_reached_title'),
      message: $r('app.string.bot_limit_reached_message'),
      firstButtonText: $r('app.string.bot_limit_select_existing'),
      secondButtonText: $r('app.string.bot_limit_go_delete'),
      firstAction: () => {
        // 留在机器人列表页，不做跳转
      },
      secondAction: () => {
        // 留在机器人列表页，不做跳转
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  private showLimitDialog(): void {
    this.limitDialogController.open()
  }

  async requestData(): Promise<void> {
    try {
      await this.viewModel.loadBotList()
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          NavigationBackBuilder({
            title: $r('app.string.contact_my_bots'),
            showDivideLine: true,
            leftButtonAction: () => {
              this.pathStack.pop()
            },
            rightButtonIcon: $r('app.media.nav_add'),
            rightButtonAction: () => {
              if (this.viewModel.isLimitReached()) {
                this.showLimitDialog()
              } else {
                this.pathStack.pushPath({
                  name: 'CreateBotPage',
                  onPop: (info: PopInfo) => {
                    this.requestData()
                    const result = info.result as V2NIMUserAIBot | string | undefined
                    if (result) {
                      const accid = typeof result === 'string' ? result : (result as V2NIMUserAIBot).accid
                      if (accid && accid.length > 0) {
                        this.pathStack.pushPath({
                          name: 'BotInfoPage',
                          param: result, // 带完整 bot 对象传入，避免 BotInfoPage 重复查找
                          onPop: (popInfo: PopInfo) => { this.handleBotInfoResult(popInfo) }
                        })
                      }
                    }
                  }
                })
              }
            }
          })
          List() {
            ForEach(this.viewModel.botList, (item: V2NIMUserAIBot) => {
              ListItem() {
                ViewItemBuilder({
                  avatarItem: new AvatarItem(item.icon, TailString(item.name ?? item.accid),
                    AvatarColorUntil.getBackgroundColorById(item.accid)),
                  title: item.name ?? item.accid,
                  titleIconSize: 40,
                  titleFontSize: 16,
                  itemHeight: 64,
                  showDivideLine: true,
                  rightIcon: $r('app.media.arrow_right')
                })
              }
              .backgroundColor(Color.White)
              .onClick(() => {
                this.pathStack.pushPath({
                  name: 'BotInfoPage',
                  param: item.accid,
                  onPop: (popInfo: PopInfo) => { this.handleBotInfoResult(popInfo) }
                })
              })
            }, (item: V2NIMUserAIBot) => {
              return item.accid + '_' + (item.name ?? '') + '_' + (item.icon ?? '')
            })
          }
          .width('100%')
          .margin({ bottom: 56 })
        }

        if (this.viewModel.botList.length <= 0 && !this.viewModel.isLoading) {
          CommonEmptyResult({
            tips: $r('app.string.no_bot')
          })
            .margin({
              top: 56 + 74,
            })
        }
      }
      .alignContent(Alignment.Top)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }
}

@Builder
export function MyBotsPageBuilder() {
  MyBotsPage()
}
