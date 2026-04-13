/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ErrorUtils } from '@nimkit/chatkit';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  NavigationBackBuilder,
  NECommonUtils,
  TailString
} from '@nimkit/common';
import { BotInfoViewModel } from '../viewmodel/BotInfoViewModel';
import { V2NIMUserAIBot } from '@nimsdk/base';

@ComponentV2
export struct BotInfoPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: BotInfoViewModel = new BotInfoViewModel()
  private shouldSyncResult: boolean = false

  private setPasteboard(content: string): void {
    const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content)
    pasteboard.getSystemPasteboard().setData(pasteboardData)
  }

  private showDeleteDialog(): void {
    AlertDialog.show({
      title: $r('app.string.bot_delete_confirm_title'),
      message: $r('app.string.bot_delete_confirm_message'),
      autoCancel: true,
      buttons: [
        {
          value: $r('app.string.cancel'),
          fontColor: '#666666',
          action: () => {}
        },
        {
          value: $r('app.string.bot_delete_btn'),
          fontColor: '#FF3B30',
          action: () => { this.doDelete() }
        }
      ]
    })
  }

  private showRefreshTokenDialog(): void {
    AlertDialog.show({
      title: $r('app.string.bot_refresh_token_confirm_title'),
      message: $r('app.string.bot_refresh_token_confirm_message'),
      autoCancel: true,
      buttons: [
        {
          value: $r('app.string.cancel'),
          fontColor: '#666666',
          action: () => {}
        },
        {
          value: $r('app.string.common_sure'),
          fontColor: '#337EFF',
          action: () => { this.doRefreshToken() }
        }
      ]
    })
  }

  private async doDelete(): Promise<void> {
    if (!ErrorUtils.checkNetworkAndToast()) return
    const success = await this.viewModel.deleteBot()
    if (success) {
      NECommonUtils.showToast($r('app.string.bot_delete_success'))
      // 把删除的 accid 带回给 MyBotsPage，直接从本地列表移除，不依赖重新拉接口
      this.pathStack.pop({ deleted: true, accid: this.viewModel.accid })
    }
  }

  private handleEditBotResult(popInfo: PopInfo): void {
    console.info('[BotInfoPage] handleEditBotResult, popInfo.result=' + JSON.stringify(popInfo.result))
    const result = popInfo.result as Record<string, string> | undefined
    if (result && result['name']) {
      console.info('[BotInfoPage] updateBotLocal, name=' + result['name'] + ', icon=' + (result['icon'] ?? 'empty'))
      this.viewModel.updateBotLocal(result['name'], result['icon'] ?? '')
      this.shouldSyncResult = true
      console.info('[BotInfoPage] after updateBotLocal, bot.name=' + (this.viewModel.bot?.name ?? 'undefined'))
    } else {
      console.info('[BotInfoPage] handleEditBotResult: no valid result, skipping')
    }
  }

  private popPage(): void {
    if (this.shouldSyncResult && this.viewModel.bot) {
      this.pathStack.pop(this.viewModel.bot)
      return
    }
    this.pathStack.pop()
  }

  private async doRefreshToken(): Promise<void> {
    if (!ErrorUtils.checkNetworkAndToast()) return
    try {
      const token = await this.viewModel.refreshToken()
      if (token) {
        this.setPasteboard(token)
        NECommonUtils.showToast($r('app.string.bot_refresh_token_success'))
      } else {
        NECommonUtils.showToast($r('app.string.bot_refresh_token_fail'))
      }
    } catch {
      NECommonUtils.showToast($r('app.string.bot_refresh_token_fail'))
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 导航栏
        NavigationBackBuilder({
          title: $r('app.string.bot_info_title'),
          showDivideLine: true,
          leftButtonAction: () => { this.popPage() }
        })

        // 第一组：头像 + 名称
        Column() {
          Row() {
            CommonAvatar({
              item: new AvatarItem(
                this.viewModel.bot?.icon,
                TailString(this.viewModel.bot?.name ?? this.viewModel.accid),
                AvatarColorUntil.getBackgroundColorById(this.viewModel.accid)
              ),
              roundRadius: 20,
              textSize: 16
            })
              .width(40).height(40).margin({ right: 12 })

            Text(this.viewModel.bot?.name ?? this.viewModel.accid)
              .fontSize(16).fontColor('#333333').fontWeight(FontWeight.Medium)
              .layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Image($r('app.media.arrow_right'))
              .width(4.92).height(9.54)
          }
          .width('100%').height(64)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.pathStack.pushPath({
              name: 'EditBotPage',
              param: this.viewModel.bot,
              onPop: (popInfo: PopInfo) => { this.handleEditBotResult(popInfo) }
            })
          })
        }
        .backgroundColor(Color.White)
        .width('100%')

        // 灰色分割条
        Row().width('100%').height(12).backgroundColor('#EFF1F4')

        // 第二组：查看配置串 / 刷新Token
        Column() {
          this.MenuRow($r('app.string.bot_config'), () => {
            this.pathStack.pushPath({ name: 'BotConfigPage', param: this.viewModel.accid })
          })
          Divider().strokeWidth(0.5).color('#F0F0F0').margin({ left: 16 })

          this.MenuRow($r('app.string.bot_refresh_token'), () => {
            this.showRefreshTokenDialog()
          })
        }
        .backgroundColor(Color.White)
        .width('100%')

        // 灰色分割条
        Row().width('100%').height(12).backgroundColor('#EFF1F4')

        // 第三组：聊天
        Column() {
          Row() {
            Text($r('app.string.bot_send_message'))
              .fontSize(16).fontColor('#337EFF')
              .textAlign(TextAlign.Center).width('100%')
          }
          .width('100%').height(56).justifyContent(FlexAlign.Center)
          .onClick(() => {
            const conversationId =
              ChatKitClient.nim.conversationIdUtil.p2pConversationId(this.viewModel.accid)
            this.pathStack.pushPath({ name: 'ChatP2PPage', param: conversationId })
          })
        }
        .backgroundColor(Color.White)
        .width('100%')

        // 灰色分割条
        Row().width('100%').height(12).backgroundColor('#EFF1F4')

        // 第四组：删除机器人
        Column() {
          Row() {
            Text($r('app.string.bot_delete_item'))
              .fontSize(16).fontColor('#FF3B30')
              .textAlign(TextAlign.Center).width('100%')
          }
          .width('100%').height(56).justifyContent(FlexAlign.Center)
          .onClick(() => { this.showDeleteDialog() })
        }
        .backgroundColor(Color.White)
        .width('100%')

        // 剩余区域灰色背景
        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#EFF1F4')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const param = this.pathStack.getParamByName('BotInfoPage')[0] as V2NIMUserAIBot | string
      if (typeof param === 'string') {
        // 从列表点击进入，传的是 accid 字符串
        this.viewModel.accid = param
        this.viewModel.loadBot()
      } else {
        // 从创建页进入，传的是完整 bot 对象，直接用，无需查列表
        const bot = param as V2NIMUserAIBot
        this.viewModel.accid = bot.accid ?? ''
        this.viewModel.bot = bot
      }
    })
    .onBackPressed(() => {
      this.popPage()
      return true
    })
  }

  @Builder
  MenuRow(title: ResourceStr, action: () => void) {
    Row() {
      Text(title)
        .fontSize(16).fontColor('#333333').layoutWeight(1)
        .margin({ left: 16 })
      Image($r('app.media.arrow_right'))
        .width(4.92).height(9.54).margin({ right: 16 })
    }
    .width('100%').height(56).alignItems(VerticalAlign.Center)
    .onClick(action)
  }
}

@Builder
export function BotInfoPageBuilder() {
  BotInfoPage()
}
