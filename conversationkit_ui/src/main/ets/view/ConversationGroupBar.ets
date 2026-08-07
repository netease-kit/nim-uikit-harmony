/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationGroupInfo } from '../model/ConversationGroupModel'
import { ConversationGroupViewModel } from '../viewmodel/ConversationGroupViewModel'

@ComponentV2
export struct ConversationGroupBar {
  @Param viewModel: ConversationGroupViewModel = new ConversationGroupViewModel()
  @Param onGroupClick?: (group: ConversationGroupInfo) => void = undefined
  @Param onManageClick?: () => void = undefined

  build() {
    Stack({ alignContent: Alignment.End }) {
      List() {
        ForEach(this.viewModel.visibleGroups, (group: ConversationGroupInfo) => {
          ListItem() {
            Row() {
              this.groupItemBuilder(group)
            }
            .height(48)
            .alignItems(VerticalAlign.Center)
          }
          .height(48)
        }, (group: ConversationGroupInfo): string => {
          return `${group.groupKey}|${group.name}|${group.unreadCount}|` +
            `${this.viewModel.selectedGroupKey === group.groupKey ? 1 : 0}`
        })
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .height(48)
      .width('100%')
      .padding({ right: 44 })

      Row() {
        Row()
          .width(24)
          .height(48)
          .linearGradient({
            direction: GradientDirection.Right,
            colors: [['rgba(255,255,255,0)', 0.0], ['#ffffffff', 1.0]]
          })
          .hitTestBehavior(HitTestMode.None)

        Row() {
          Image($r('app.media.ic_conversation_group_setting'))
            .width(16)
            .height(13.25)
        }
        .width(44)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#ffffffff')
        .onClick(() => {
          this.onManageClick?.()
        })
      }
      .width(68)
      .height(48)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(48)
    .padding({ left: 12 })
    .backgroundColor('#ffffffff')
  }

  @Builder
  private groupItemBuilder(group: ConversationGroupInfo) {
    Row() {
      Text(group.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.viewModel.selectedGroupKey === group.groupKey ? '#337EFF' : '#333333')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (group.unreadCount > 0) {
        Text(this.formatUnreadCount(group.unreadCount))
          .fontSize(12)
          .fontColor(this.viewModel.selectedGroupKey === group.groupKey ? '#337EFF' : '#999999')
          .margin({ left: 4 })
      }
    }
    .height(32)
    .padding({ left: 12, right: 12 })
    .margin({ right: 8 })
    .borderRadius(8)
    .backgroundColor(this.viewModel.selectedGroupKey === group.groupKey ? '#EAF2FF' : Color.Transparent)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onGroupClick?.(group)
    })
  }

  private formatUnreadCount(count: number): string {
    if (count > 99) {
      return '99+'
    }
    return count.toString()
  }
}
