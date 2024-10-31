/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatKitClient, TeamMemberWithUser } from '@nimkit/chatkit'
import { ChatReadReceiptViewModel } from '../viewmodel/ChatReadReceiptViewModel'
import { AvatarColorUntil, AvatarItem, CommonAvatar, CommonEmptyResult, NavigationBackBuilder } from '@nimkit/common'
import { V2NIMMessage } from '@nimsdk/base'

@ComponentV2
export struct ChatReadReceiptPage {
  pathStack: NavPathStack = new NavPathStack()
  //群Id
  teamId?: string
  //消息
  message?: V2NIMMessage
  @Local viewModel: ChatReadReceiptViewModel = new ChatReadReceiptViewModel()

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.chat_read_receipt_title'),
        backgroundColor: '#ffffffff',
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })
      if (this.viewModel.readReceiptDetail !== null) {
        Tabs({
          barPosition: BarPosition.Start
        }) {

          TabContent() {
            if (this.viewModel.readReceiptDetail.readAccountList.length <= 0) {
              CommonEmptyResult({
                tips: $r('app.string.chat_read_receipt_all_unread')
              })
            } else {
              List() {
                ForEach(this.viewModel.readMemberList, (member: TeamMemberWithUser) => {
                  ListItem() {
                    Row() {
                      CommonAvatar({
                        item: new AvatarItem(
                          member.getAvatar(),
                          member.getAvatarName(),
                          AvatarColorUntil.getBackgroundColorById(member.getAccId())
                        )
                      })
                        .width(42)
                        .height(42)
                        .margin({
                          right: 14
                        })

                      Text(member.getNickname())
                        .fontColor('#ff333333')
                        .fontSize(16)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .ellipsisMode(EllipsisMode.END)
                        .width(280)
                    }
                    .padding({
                      left: 20,
                      right: 20,
                      top: 10,
                      bottom: 10
                    })
                    .width('100%')
                  }
                })
              }
              .listDirection(Axis.Vertical)
              .scrollBar(BarState.Off)
              .width('100%')
              .height('100%')
              .backgroundColor('#ffFFFFFF')
            }

          }
          .tabBar($r('app.string.chat_read_receipt_read',
            this.viewModel.readReceiptDetail.readReceipt.readCount))

          TabContent() {
            if (this.viewModel.readReceiptDetail.unreadAccountList.length <= 0) {
              CommonEmptyResult({
                tips: $r('app.string.chat_read_receipt_all_read')
              }).margin({
                top: 80
              })
            } else {
              List() {
                ForEach(this.viewModel.unreadMemberList, (member: TeamMemberWithUser) => {
                  ListItem() {
                    Row() {
                      CommonAvatar({
                        item: new AvatarItem(
                          member.getAvatar(),
                          member.getAvatarName(),
                          AvatarColorUntil.getBackgroundColorById(member.getAccId())
                        )
                      })
                        .width(42)
                        .height(42)
                        .margin({
                          right: 14
                        })

                      Text(member.getNickname())
                        .fontColor('#ff333333')
                        .fontSize(16)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .ellipsisMode(EllipsisMode.END)
                        .width(280)
                    }
                    .padding({
                      left: 20,
                      right: 20,
                      top: 10,
                      bottom: 10
                    })
                  }
                })
              }
              .listDirection(Axis.Vertical)
              .scrollBar(BarState.Off)
              .width('100%')
              .height('100%')
              .backgroundColor('#ffFFFFFF')
            }

          }.tabBar($r('app.string.chat_read_receipt_unread', this.viewModel.readReceiptDetail.readReceipt.unreadCount))
          .onAttach(() => {
            if (this.viewModel.readReceiptDetail) {
              this.viewModel.getMemberList(this.viewModel.readReceiptDetail.unreadAccountList, false)
            }

          })

        }
      }

    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.message = context.pathStack.getParamByName('ChatReadReceiptPage')[0] as V2NIMMessage
      this.teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.message.conversationId)
      this.viewModel.init(this.message)
      this.viewModel.getMessageReadReceipt()
    })
  }
}

@Builder
export function ChatReadReceiptPageBuilder() {
  ChatReadReceiptPage()
}

