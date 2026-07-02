/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatKitClient, ConversationRepo, ErrorUtils, IMKitConfigCenter, LocalConversationRepo, UserAIBotManager } from '@nimkit/chatkit';
import { BusinessError } from '@kit.BasicServicesKit';
import { V2NIMGetUserAIBotListParams, V2NIMGetUserAIBotListResult, V2NIMUserAIBot } from '@nimsdk/base';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  NavigationBackBuilder,
  NECommonUtils,
  TailString,
  VerticalAlertDialog
} from '@nimkit/common';

const BOT_MAX_COUNT = 10

@ComponentV2
export struct BindBotPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local qrcode: string = ''
  @Local bots: V2NIMUserAIBot[] = []
  @Local isLoading: boolean = false
  @Local isBinding: boolean = false
  @Local selectedBot: V2NIMUserAIBot | undefined = undefined

  private showConfirmBindDialog(): void {
    AlertDialog.show({
      title: $r('app.string.bot_bind_confirm_title'),
      message: $r('app.string.bot_bind_confirm_message'),
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
          action: () => {
            if (this.selectedBot) {
              this.doConfirmBind(this.selectedBot)
            }
          }
        }
      ]
    })
  }

  private async loadBotList(): Promise<void> {
    this.isLoading = true
    try {
      let allBots: V2NIMUserAIBot[] = []
      let nextToken: string | undefined = undefined
      let hasMore = true
      while (hasMore) {
        const params: V2NIMGetUserAIBotListParams = nextToken
          ? { pageToken: nextToken, limit: 100 }
          : { limit: 100 }
        const result: V2NIMGetUserAIBotListResult | undefined = await UserAIBotManager.getUserAIBotList(params)
        if (result && result.bots) {
          for (const bot of result.bots) {
            allBots.push(bot)
          }
        }
        if (result && result.hasMore && result.nextToken && result.nextToken.length > 0) {
          nextToken = result.nextToken
        } else {
          hasMore = false
        }
      }
      this.bots = allBots
      // 已达上限：弹出选择弹窗
      if (this.bots.length >= BOT_MAX_COUNT) {
        this.limitDialogController.open()
      }
    } catch (err) {
      Logger.error('ContactKit', 'loadBotList error: ' + JSON.stringify(err))
    } finally {
      this.isLoading = false
    }
  }

  limitDialogController: CustomDialogController = new CustomDialogController({
    builder: VerticalAlertDialog({
      title: $r('app.string.bot_limit_bind_title'),
      message: $r('app.string.bot_limit_bind_message'),
      firstButtonText: $r('app.string.bot_limit_select_existing'),
      secondButtonText: $r('app.string.bot_limit_go_delete'),
      firstAction: () => {
        // 留在当前页面，用户从列表选择已有机器人
      },
      secondAction: () => {
        // 返回上一页，让用户去删除机器人
        this.pathStack.pop()
      }
    }),
    autoCancel: false,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  private async ensureConversationCreated(accid: string): Promise<void> {
    const conversationId = ChatKitClient.nim.conversationIdUtil.p2pConversationId(accid)
    try {
      if (IMKitConfigCenter.enableLocalConversation) {
        await LocalConversationRepo.createConversation(conversationId)
      } else {
        await ConversationRepo.createConversation(conversationId)
      }
    } catch (err) {
      Logger.error('ContactKit', 'ensureConversationCreated error: ' + JSON.stringify(err))
    }
  }

  private async doConfirmBind(bot: V2NIMUserAIBot): Promise<void> {
    if (this.isBinding) return
    if (!ErrorUtils.checkNetworkAndToast()) return
    this.isBinding = true
    try {
      // 先从 getUserAIBot 读 token，若为空再 fallback 到 refreshUserAIBotToken
      const botDetail = await UserAIBotManager.getUserAIBot({ accid: bot.accid })
      let token = botDetail?.token ?? ''
      if (token.length === 0) {
        const refreshResult = await UserAIBotManager.refreshUserAIBotToken({ accid: bot.accid })
        token = refreshResult?.token ?? ''
      }
      if (token.length === 0) {
        NECommonUtils.showToast($r('app.string.bot_bind_fail'))
        return
      }

      // 通过 SDK 协议 37-7 发起绑定
      await UserAIBotManager.bindUserAIBotToQrCode({
        accid: bot.accid,
        token: token,
        qrCode: this.qrcode
      })

      // 绑定成功后补建会话入口，兼容本地/云端会话模式。
      await this.ensureConversationCreated(bot.accid)

      NECommonUtils.showToast($r('app.string.bot_bind_success'))
      // pop 回调用方，由调用方跳转 BotInfoPage
      this.pathStack.pop(botDetail ?? bot)
    } catch (err) {
      Logger.error('ContactKit', 'doConfirmBind error: ' + JSON.stringify(err))
      // 网络异常优先判断
      if (!ErrorUtils.checkNetworkAndToast()) {
        // checkNetworkAndToast 内部已弹网络异常 Toast，无需再弹
      } else {
        const bizErr = err as BusinessError
        const errMsg = bizErr?.message
        NECommonUtils.showToast(errMsg && errMsg.length > 0 ? errMsg : $r('app.string.bot_bind_fail'))
      }
    } finally {
      this.isBinding = false
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.bot_bind_title'),
          showDivideLine: true,
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        List() {
          // 上限提示横幅
          if (this.bots.length >= BOT_MAX_COUNT) {
            ListItem() {
              Text($r('app.string.bot_limit_bind_title'))
                .fontSize(13)
                .fontColor('#FF6600')
                .width('100%')
                .padding({ left: 20, right: 20, top: 12, bottom: 12 })
                .backgroundColor('#FFF8F0')
            }
          }

          // 新建机器人入口
          if (this.bots.length < BOT_MAX_COUNT) {
            ListItem() {
              Row() {
                Image($r('app.media.nav_add'))
                  .width(36)
                  .height(36)
                  .margin({ left: 20 })

                Text($r('app.string.bot_bind_create_new'))
                  .fontSize(14)
                  .fontColor('#07C160')
                  .margin({ left: 16 })
                  .layoutWeight(1)
              }
              .height(60)
              .width('100%')
              .backgroundColor(Color.White)
            }
            .onClick(() => {
              this.pathStack.pushPath({
                name: 'CreateBotPage',
                param: this.qrcode,
                onPop: (popInfo: PopInfo) => {
                  const result = popInfo.result as V2NIMUserAIBot | string | undefined
                  if (!result) return
                  if (typeof result === 'string') {
                    // 兼容旧版：只有 accid，需要再查列表
                    const newAccid = result
                    UserAIBotManager.getUserAIBotList({ limit: 100 }).then((listResult) => {
                      if (listResult && listResult.bots) {
                        for (const bot of listResult.bots) {
                          if (bot.accid === newAccid) {
                            this.doConfirmBind(bot)
                            break
                          }
                        }
                      }
                    })
                  } else {
                    // 直接用完整 bot 对象，无需再拉列表，自动完成绑定
                    this.doConfirmBind(result as V2NIMUserAIBot)
                  }
                }
              })
            })
          }

          // 分组标题
          if (this.bots.length > 0) {
            ListItem() {
              Text($r('app.string.bot_bind_select_existing'))
                .fontSize(12)
                .fontColor('#A6ADB6')
                .width('100%')
                .padding({ left: 20, right: 20, top: 12, bottom: 8 })
            }
            .backgroundColor('#EFF1F4')
          }

          // 已有机器人列表
          ForEach(this.bots, (bot: V2NIMUserAIBot) => {
            ListItem() {
              Row() {
                CommonAvatar({
                  item: new AvatarItem(
                    bot.icon,
                    TailString(bot.name ?? bot.accid),
                    AvatarColorUntil.getBackgroundColorById(bot.accid)
                  ),
                  roundRadius: 18,
                  textSize: 14
                })
                  .width(36)
                  .height(36)
                  .margin({ left: 20 })

                Text(bot.name ?? bot.accid)
                  .fontSize(14)
                  .fontColor('#333333')
                  .margin({ left: 16 })
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .height(60)
              .width('100%')
              .backgroundColor(Color.White)
            }
            .onClick(() => {
              this.selectedBot = bot
              this.showConfirmBindDialog()
            })
          }, (bot: V2NIMUserAIBot) => bot.accid)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#EFF1F4')
        .divider({
          strokeWidth: 1,
          startMargin: 20,
          color: '#F5F8FC'
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.qrcode = this.pathStack.getParamByName('BindBotPage')[0] as string
      this.loadBotList()
    })
  }
}

@Builder
export function BindBotPageBuilder() {
  BindBotPage()
}
