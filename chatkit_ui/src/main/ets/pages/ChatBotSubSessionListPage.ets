/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { CommonEmptyResult, MatchSearchText, NECommonUtils } from '@nimkit/common';
import { ErrorUtils } from '@nimkit/chatkit';
import {
  ChatBotSubSessionListParam,
  ChatBotSubSessionParam,
  ChatBotSubSessionResult,
  ChatBotSubSessionSettingParam
} from '../model/ChatBotSubSessionParam';
import { ChatBotSubSessionItem, ChatBotSubSessionListViewModel } from '../viewmodel/ChatBotSubSessionListViewModel';

const CHAT_BOT_TOPIC_LIST_PAGE_TAG = '[ChatBotSubSessionListPage]'

@CustomDialog
struct ChatBotTopicRenameDialog {
  controller?: CustomDialogController
  title: string = ''
  onCancel?: () => void
  onConfirm?: (title: string) => void
  @State inputTitle: string = ''

  aboutToAppear(): void {
    this.inputTitle = this.title
  }

  build() {
    Column() {
      Text($r('app.string.chat_bot_sub_session_rename'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2329')
        .margin({ top: 20 })

      TextInput({ text: this.inputTitle })
        .fontSize(16)
        .fontColor('#1F2329')
        .height(44)
        .margin({ left: 20, right: 20, top: 18 })
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F5F6F8')
        .borderRadius(8)
        .maxLength(20)
        .type(InputType.Normal)
        .onChange((value: string) => {
          this.inputTitle = value
        })

      Row()
        .height(1)
        .width('100%')
        .backgroundColor('#EFF1F4')
        .margin({ top: 18 })

      Row() {
        Text($r('app.string.chat_msg_dialog_cancel'))
          .fontSize(17)
          .fontColor('#666666')
          .width(135)
          .height(44)
          .textAlign(TextAlign.Center)
          .align(Alignment.Center)
          .onClick(() => {
            this.onCancel?.()
          })

        Column()
          .width(1)
          .height('100%')
          .backgroundColor('#EFF1F4')

        Text($r('app.string.chat_bot_sub_session_save'))
          .fontSize(17)
          .fontColor('#337EFF')
          .width(135)
          .height(44)
          .textAlign(TextAlign.Center)
          .align(Alignment.Center)
          .onClick(() => {
            const title = this.inputTitle.trim()
            if (title.length > 0) {
              this.onConfirm?.(title)
            }
          })
      }
      .height(44)
      .width(270)
      .alignItems(VerticalAlign.Center)
    }
    .width(270)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .clip(true)
  }
}

@ComponentV2
export struct ChatBotSubSessionListPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local param: ChatBotSubSessionListParam = new ChatBotSubSessionListParam('', '', '')
  @Local viewModel: ChatBotSubSessionListViewModel = new ChatBotSubSessionListViewModel()
  private renameDialog?: CustomDialogController = undefined

  build() {
    NavDestination() {
      Column() {
        this.topicListNavigationBuilder()

        this.searchBuilder()

        if (this.viewModel.items.length <= 0 && !this.viewModel.loading) {
          CommonEmptyResult({
            tips: this.viewModel.keyword.length > 0 ?
              $r('app.string.chat_bot_sub_session_search_empty') :
              $r('app.string.chat_bot_sub_session_empty')
          })
            .margin({ top: 120 })
        } else {
          List() {
            ForEach(this.viewModel.items, (item: ChatBotSubSessionItem) => {
              ListItem() {
                this.topicItemBuilder(item)
              }
            }, (item: ChatBotSubSessionItem) => this.getTopicItemKey(item))
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor(Color.White)
          .onReachEnd(() => {
            this.viewModel.loadMore()
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const routeParams = this.pathStack.getParamByName('ChatBotSubSessionListPage') as string[][]
      const params = routeParams[0] as string[]
      if (params && params.length >= 3) {
        const botName = params[2].length > 0 ? params[2] : params[1]
        this.param = new ChatBotSubSessionListParam(params[0], params[1], botName)
        Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_PAGE_TAG} onReady conversationId=${this.param.conversationId} botAccid=${this.param.botAccid} botName=${this.param.botName}`)
        this.viewModel.init(this.param.conversationId)
      }
    })
    .onShown(() => {
      this.viewModel.resume()
    })
    .onDisAppear(() => {
      this.viewModel.destroy()
    })
  }

  @Builder
  searchBuilder() {
    Row() {
      Row() {
        Image($r('app.media.nav_search'))
          .width(18)
          .height(18)
          .margin({ left: 12, right: 8 })

        TextInput({ placeholder: $r('app.string.chat_bot_sub_session_search_hint') })
          .fontSize(14)
          .fontColor('#1F2329')
          .placeholderColor('#A7ABB3')
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .height(40)
          .padding({ left: 0, right: 0, top: 0, bottom: 0 })
          .cancelButton({
            style: CancelButtonStyle.INPUT,
            icon: {
              src: $r('app.media.input_clean'),
              size: 16,
              color: '#B3B7BC'
            }
          })
          .onChange((value: string) => {
            this.viewModel.search(value)
          })
      }
      .layoutWeight(1)
      .height(40)
      .borderRadius(8)
      .backgroundColor('#F5F6F8')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(40)
    .padding({ left: 16, right: 16 })
    .margin({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  topicListNavigationBuilder() {
    Column() {
      Stack() {
        Text(this.param.botName)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2329')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 112, right: 112 })

        Row() {
          Row() {
            Image($r('app.media.nav_back'))
              .width(32)
              .height(26)
              .objectFit(ImageFit.Contain)
              .padding({
                left: 9,
                right: 15,
                top: 5,
                bottom: 5.5
              })
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.pathStack.pop()
          })

          Blank()
            .layoutWeight(1)

          Row() {
            Image($r('app.media.ic_chat_sub_session_add'))
              .width(24)
              .height(24)
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            if (!ErrorUtils.checkNetworkAndToast()) {
              return
            }
            this.openSubSession(undefined)
          })

          Row() {
            Image($r('app.media.ic_public_more_dot'))
              .width(26)
              .height(26)
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.openSettingPage()
            })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 12, right: 8 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(56)

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#E9EFF5')
    }
    .width('100%')
    .backgroundColor(Color.White)
    .zIndex(1)
  }

  @Builder
  topicItemBuilder(item: ChatBotSubSessionItem) {
    Row() {
      Stack() {
        Image($r('app.media.ic_chat_sub_session'))
          .width(42)
          .height(42)

        if (item.showUnreadDot) {
          Circle()
            .width(8)
            .height(8)
            .fill('#F24957')
            .position({ x: 32, y: 2 })
        }
      }
      .width(42)
      .height(42)
      .margin({ left: 16, right: 12 })

      Column() {
        Row() {
          MatchSearchText({
            allText: item.title,
            searchText: this.viewModel.keyword,
            fontSize: 16,
            normalFontColor: '#1F2329',
            highlightFontColor: '#337EFF',
            showFullText: false
          })
            .layoutWeight(1)

          if (item.timeText.length > 0) {
            Text(item.timeText)
              .fontSize(12)
              .fontColor('#A7ABB3')
              .margin({ left: 8 })
          }
        }
        .width('100%')

        Row() {
          Text(item.summary)
            .fontSize(14)
            .fontColor('#8A8F99')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding({ right: 16 })
    }
    .height(72)
    .width('100%')
    .backgroundColor(Color.White)
    .onClick(() => {
      this.openSubSession(item)
    })
    .gesture(LongPressGesture().onAction(() => {
      this.showTopicAction(item)
    }))
  }

  private openSubSession(item?: ChatBotSubSessionItem): void {
    Logger.info('ChatKitUI', `${CHAT_BOT_TOPIC_LIST_PAGE_TAG} openSubSession conversationId=${this.param.conversationId} topicId=${item?.topic.topicId ?? -1} placeholder=${item === undefined}`)
    this.pathStack.pushPath({
      name: 'ChatBotSubSessionPage',
      param: new ChatBotSubSessionParam(
        this.param.conversationId,
        this.param.botAccid,
        this.param.botName,
        item?.topic
      ),
      onPop: (popInfo: PopInfo) => {
        const result = popInfo.result as ChatBotSubSessionResult | undefined
        if (!result?.changed || !result.topic) {
          return
        }
        if (result.removed) {
          this.viewModel.removeTopicFromChat(result.topic)
        } else {
          this.viewModel.updateTopicFromChat(result.topic, true)
        }
      }
    })
  }

  private getTopicItemKey(item: ChatBotSubSessionItem): string {
    return `${item.topic.topicId}-${item.topic.createTime}-${item.title}-${item.summary}-${item.timeText}-${item.showUnreadDot}`
  }

  private openSettingPage(): void {
    this.pathStack.pushPath({
      name: 'UserSettingPage',
      param: new ChatBotSubSessionSettingParam(this.param.conversationId, true)
    })
  }

  private showTopicAction(item: ChatBotSubSessionItem): void {
    AlertDialog.show({
      title: item.title,
      message: '',
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      gridCount: 4,
      offset: { dx: 0, dy: -20 },
      buttons: [
        {
          value: $r('app.string.chat_bot_sub_session_rename'),
          fontColor: '#337EFF',
          action: () => {
            this.showRenameDialog(item)
          }
        },
        {
          value: $r('app.string.chat_bot_sub_session_delete'),
          fontColor: '#F24957',
          action: () => {
            this.showDeleteConfirm(item)
          }
        }
      ]
    })
  }

  private showRenameDialog(item: ChatBotSubSessionItem): void {
    const dialog = new CustomDialogController({
      builder: ChatBotTopicRenameDialog({
        title: item.title,
        onCancel: () => {
          this.renameDialog?.close()
        },
        onConfirm: (title: string) => {
          this.viewModel.renameTopic(item.topic, title)
            .then(() => {
              this.renameDialog?.close()
            })
            .catch(() => {
              NECommonUtils.showToast($r('app.string.chat_bot_sub_session_rename_failed'))
            })
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      customStyle: true
    })
    this.renameDialog = dialog
    this.renameDialog.open()
  }

  private showDeleteConfirm(item: ChatBotSubSessionItem): void {
    AlertDialog.show({
      title: $r('app.string.chat_bot_sub_session_delete_title'),
      message: $r('app.string.chat_bot_sub_session_delete_confirm'),
      autoCancel: true,
      buttons: [
        {
          value: $r('app.string.chat_msg_dialog_cancel'),
          fontColor: '#666666',
          action: () => {}
        },
        {
          value: $r('app.string.chat_bot_sub_session_delete'),
          fontColor: '#F24957',
          action: () => {
            this.viewModel.removeTopic(item.topic)
              .catch(() => {
                NECommonUtils.showToast($r('app.string.chat_bot_sub_session_delete_failed'))
              })
          }
        }
      ]
    })
  }
}

@Builder
export function ChatBotSubSessionListPageBuilder() {
  ChatBotSubSessionListPage()
}
