/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ErrorUtils, UserAIBotRepo } from '@nimkit/chatkit';
import { NavigationBackBuilder, NECommonUtils } from '@nimkit/common';
import { pasteboard } from '@kit.BasicServicesKit';

@ComponentV2
export struct BotConfigPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local accid: string = ''
  @Local configStr: string = ''
  @Local maskedConfigStr: string = ''
  @Local isNetworkError: boolean = false

  private buildConfigStr(token: string): void {
    const appkey = ChatKitClient.appKey
    this.configStr = `${appkey}|${this.accid}|${token}`
    const len = this.configStr.length
    const showLen = Math.ceil(len / 3)
    this.maskedConfigStr = this.configStr.substring(0, showLen) + '...'
  }

  private copyConfig(): void {
    if (this.configStr.length === 0) {
      NECommonUtils.showToast($r('app.string.bot_token_empty_tip'))
      return
    }
    const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.configStr)
    const systemPasteboard = pasteboard.getSystemPasteboard()
    systemPasteboard.setData(pasteboardData)
    NECommonUtils.showToast($r('app.string.bot_config_copied'))
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.bot_config_title'),
          showDivideLine: true,
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Column({ space: 24 }) {
          // 配置串展示区域
          Column({ space: 12 }) {
            Text($r('app.string.bot_config'))
              .fontSize(14)
              .fontColor('#333333')
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)

            if (this.maskedConfigStr.length > 0) {
              Text(this.maskedConfigStr)
                .fontSize(14)
                .fontColor('#666666')
                .width('100%')
                .padding(16)
                .backgroundColor('#F5F8FC')
                .borderRadius(8)
                .wordBreak(WordBreak.BREAK_ALL)
            } else if (!this.isNetworkError) {
              Text($r('app.string.bot_token_empty_tip'))
                .fontSize(14)
                .fontColor('#FF3B30')
                .width('100%')
                .padding(16)
                .backgroundColor('#F5F8FC')
                .borderRadius(8)
            }
          }
          .width('100%')

          // 复制按钮
          Button($r('app.string.bot_config_copy_all'))
            .width('100%')
            .height(44)
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor(this.configStr.length > 0 ? '#337EFF' : '#CCCCCC')
            .borderRadius(8)
            .enabled(this.configStr.length > 0)
            .onClick(() => {
              this.copyConfig()
            })

          // 安全提示
          Text($r('app.string.bot_config_security_tip'))
            .fontSize(12)
            .fontColor('#A6ADB6')
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .padding({ left: 20, right: 20, top: 24 })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.accid = this.pathStack.getParamByName('BotConfigPage')[0] as string
      // 加载 token
      if (!ErrorUtils.checkNetworkAndToast()) {
        this.isNetworkError = true
        return
      }
      UserAIBotRepo.getUserAIBotList({ limit: 100 }).then((result) => {
        if (result && result.bots) {
          for (const bot of result.bots) {
            if (bot.accid === this.accid) {
              const accid = bot.accid
              const self = this
              const loadToken = async (): Promise<void> => {
                const botDetail = await UserAIBotRepo.getUserAIBot({ accid: accid })
                let token = botDetail?.token ?? ''
                if (token.length === 0) {
                  const refreshResult = await UserAIBotRepo.refreshUserAIBotToken({ accid: accid })
                  token = refreshResult?.token ?? ''
                }
                if (token.length > 0) {
                  self.buildConfigStr(token)
                }
              }
              loadToken().catch((_err: Error) => {
                if (!ErrorUtils.checkNetworkAndToast()) {
                  self.isNetworkError = true
                }
              })
              break
            }
          }
        }
      }).catch(() => {
        if (!ErrorUtils.checkNetworkAndToast()) {
          this.isNetworkError = true
        }
      })
    })
  }
}

@Builder
export function BotConfigPageBuilder() {
  BotConfigPage()
}