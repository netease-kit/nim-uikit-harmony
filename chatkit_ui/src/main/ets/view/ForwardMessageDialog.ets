/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel'
import { ChatRepo } from '@nimkit/chatkit/src/main/ets/repo/ChatRepo'
import { AvatarColorUntil, AvatarItem, CommonAvatar, NECommonUtils } from '@nimkit/common'
import { V2NIMMessage } from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService'

/**
 * 转发弹框
 */
@CustomDialog
export struct ForwardMessageDialog {
  controller?: CustomDialogController
  conversationList: ConversationSelectModel[] = []
  leaveText?: string // 留言
  forwardType: ResourceStr = $r('app.string.chat_operation_forward') // 转发类型：转发、合并转发、逐条转发
  currentConversationName?: string
  sendForwardMsg?: (leaveText: string | undefined) => void

  build() {
    Column() {
      Text($r('app.string.chat_send_tips', ""))
        .fontSize(16)
        .padding({ top: 16, left: 16 })
        .height(34)
        .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        List({ space: 9 }) {
          ForEach(this.conversationList, (item: ConversationSelectModel) => {
            ListItem() {
              CommonAvatar({
                item: new AvatarItem(item.avatar, NECommonUtils.shortName(item.name),
                  AvatarColorUntil.getBackgroundColorById(item.conversationId ?? "")),
                roundRadius: 16
              })
                .height(32)
                .width(32)
            }
            .width(32)
            .height(32)
          })
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(48)
        .backgroundColor(Color.White)
        .padding({
          top: 16,
          left: 16,
          right: 16
        })

        if (this.conversationList.length === 1) {
          Text(this.conversationList[0].name)
            .fontSize(14)
            .height(18)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .ellipsisMode(EllipsisMode.END)
            .margin({
              top: 18,
              left: 56,
              right: 12
            })
        }
      }

      Column() {
        Text() {
          Span('[')
          Span(this.forwardType)
          Span(']')
          Span($r('app.string.chat_operation_forward_desc', this.currentConversationName))
        }
        .alignSelf(ItemAlign.Start)
        .fontSize(14)
        .height(16)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .ellipsisMode(EllipsisMode.CENTER)
        .margin({
          top: 8,
          left: 12,
          right: 12
        })
      }
      .width(244)
      .height(32)
      .borderRadius(4)
      .backgroundColor('#F2F4F5')
      .margin({
        top: 12,
        left: 16,
        right: 16
      })

      TextInput({ placeholder: $r('app.string.forward_dialog_leave_message') })
        .fontSize(14)
        .height(32)
        .placeholderColor('#A6ADB6')
        .placeholderFont({ size: 14 })
        .backgroundColor(Color.White)
        .borderRadius(4)
        .borderColor('#E1E6E8')
        .borderWidth(1)
        .onChange((value: string, previewText?: PreviewText) => {
          this.leaveText = value
        })
        .margin({
          top: 12,
          left: 16,
          right: 16
        })

      Row()
        .height(1)
        .width('100%')
        .backgroundColor("#EFF1F4")
        .margin({ top: 24 })

      Row() {
        Button($r('app.string.mine_edit_cancel'), { type: ButtonType.Normal })
          .fontSize(17)
          .fontColor("#666666")
          .backgroundColor(Color.White)
          .width(135)
          .height(52)
          .onClick(() => {
            this.controller?.close()
          })

        Column()
          .width(1)
          .height('100%')
          .backgroundColor("#EFF1F4")

        Button($r('app.string.chat_send'), { type: ButtonType.Normal })
          .fontSize(17)
          .fontColor("#007AFF")
          .backgroundColor(Color.White)
          .width(135)
          .height(52)
          .onClick(() => {
            this.sendForwardMsg?.(this.leaveText)
            this.controller?.close()
          })
      }
      .height(52)
      .width(270)
      .alignItems(VerticalAlign.Center)
    }
    .height(140)
    .width(270)
    .backgroundColor(Color.White)
  }
}