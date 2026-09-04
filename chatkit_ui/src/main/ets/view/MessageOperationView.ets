/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { MessageOperationItem } from '../model/MessageOperationItem';
import { MessageOperationItemView } from '../view/MessageOperationItemView';
import { ChatConst } from '../constants/ChatConst';
import { ChatKitConfig } from '../ChatKitConfig';
import { getOperateMenu, getTopStickyMenuItem } from '../common/ChatUtils';
import { MessageReactionPicker } from './MessageReactionPicker';
import { canShowMessageReaction } from '../utils/MessageReactionUtils';

@ComponentV2
export struct MessageOperationView {
  @Local operationMoreDataList: Array<MessageOperationItem> = Array();
  @Param
  operationItems?: Array<MessageOperationItem> = undefined;
  @Param @Require
  operateMsg: NIMMessageInfo | undefined = undefined;
  /** 当前置顶消息（用于判断「置顶」还是「取消置顶」） */
  @Param topMessage: NIMMessageInfo | undefined = undefined;
  @Param @Require
  didClickItem?: (item: MessageOperationItem) => void = undefined;
  @Param
  didClickReaction?: (index: number) => void = undefined;
  @Param
  onReactionExpandedChange?: (expanded: boolean) => void = undefined;
  @Param
  enableReaction: boolean = false;
  @Param
  reactionExpanded: boolean = false;
  //撤回时间限制2分钟
  revokeTime: number = ChatKitConfig.messageRevokeTimeLimit;
  @Local viewHeight: number = 0;
  @Local viewWidth: number = 0;

  aboutToAppear(): void {
    this.updateOperationData()
  }

  @Monitor('operationItems')
  onOperationItemsChange(): void {
    this.updateOperationData()
  }

  @Monitor('operateMsg')
  onOperateMsgChange(): void {
    this.updateOperationData()
  }

  private updateOperationData(): void {
    if (this.operationItems && this.operationItems.length > 0) {
      this.operationMoreDataList = this.operationItems
    } else {
      this.operationMoreDataList = getOperateMenu(this.operateMsg, this.topMessage)
    }
    this.viewHeight =
      ChatConst.menuItemHeight * (Math.ceil(this.operationMoreDataList.length / ChatConst.menuItemColumnNum))
    this.viewWidth = this.shouldShowReaction() ? 320 :
      ChatConst.menuItemWidth * Math.min(this.operationMoreDataList.length, ChatConst.menuItemColumnNum)
  }

  private shouldShowReaction(): boolean {
    return this.enableReaction && this.operateMsg !== undefined &&
      canShowMessageReaction(this.operateMsg.message, this.operateMsg.isRevokeMsg)
  }

  build() {
    Column() {
      if (this.shouldShowReaction()) {
        MessageReactionPicker({
          expanded: this.reactionExpanded,
          onExpandedChange: (expanded: boolean): void => {
            this.onReactionExpandedChange?.(expanded)
          },
          onReactionClick: (index: number): void => {
            this.didClickReaction?.(index)
          }
        })
      }
      if (!this.reactionExpanded) {
        Grid() {
          ForEach(this.operationMoreDataList, (item: MessageOperationItem) => {
            GridItem() {
              MessageOperationItemView({ operationData: item })
                .width(ChatConst.menuItemWidth)
                .height(ChatConst.menuItemHeight)
                .onClick(() => {
                  if (this.didClickItem) {
                    this.didClickItem(item)
                  }
                })
                .align(Alignment.Center)
            }
          })
        }
      }
    }.backgroundColor(Color.White).borderRadius(8)
    .width(this.viewWidth)
    .constraintSize({ minHeight: this.viewHeight })
  }
}
