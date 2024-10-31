/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationSelectedParam } from '@nimkit/chatkit';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  NavigationBackBuilder,
  TailString
} from '@nimkit/common';


/// 会话选择结果详情页
@ComponentV2
export struct ConversationSelectedPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local selectedList?: ConversationSelectModel[] = []
  @Local onRemoveButtonClick?: (item: ConversationSelectModel) => void = undefined

  async requestData(): Promise<void> {
    const param = this.pathStack.getParamByName('ConversationSelectedPage')[0] as ConversationSelectedParam
    if (param) {
      this.selectedList = param.selectedList
      this.onRemoveButtonClick = param.onRemoveButtonClick
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          NavigationBackBuilder({
            title: $r('app.string.conversation_selected'),
            showDivideLine: false,
            leftButtonAction: () => {
              this.pathStack.pop()
            }
          })

          List() {
            ForEach(this.selectedList, (item: ConversationSelectModel) => {
              ListItem() {
                Row() {
                  Column() {
                    Row() {
                      CommonAvatar({
                        item: new AvatarItem(item.avatar, TailString(item.name),
                          AvatarColorUntil.getBackgroundColorById(item.conversationId ?? ""))
                      })
                        .width(42)
                        .height(42)
                        .borderRadius(21)
                        .margin({ left: 20 })

                      Text(item.name)
                        .fontSize(16)
                        .fontColor("#333333")
                        .height(18)
                        .margin({ left: 12, right: 12 })
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .ellipsisMode(EllipsisMode.END)

                      if (item.memberCount > 0) {
                        Text(`(${item.memberCount})`)
                          .width(50)
                          .fontSize(16)
                          .fontColor("#333333")
                          .height(18)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .ellipsisMode(EllipsisMode.END)
                      }

                      Image($r('app.media.list_remove'))
                        .width(20)
                        .height(20)
                        .onClick(() => {
                          if (this.onRemoveButtonClick) {
                            this.onRemoveButtonClick(item)
                          }
                        })
                        .margin({
                          right: 16
                        })

                    }
                    .alignSelf(ItemAlign.Center)
                    .height(61)

                    Row()
                      .width('100%')
                      .height(1)
                      .backgroundColor('#F5F8FC')
                      .margin({ left: 40 })
                  }
                  .width('100%')
                  .height(62)
                }
                .width('100%')
              }
            })
          }
          .width('100%')
          .margin({
            bottom: 56
          })
        }

        if (this.selectedList === undefined || this.selectedList.length <= 0) {
          CommonEmptyResult({
            tips: $r('app.string.common_content_empty')
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


// 跳转页面入口函数
@Builder
export function ConversationSelectedPageBuilder() {
  ConversationSelectedPage()
}