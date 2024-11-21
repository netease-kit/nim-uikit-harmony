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
import { getOperateMenu } from '../common/ChatUtils';

@ComponentV2
export struct MessageOperationView {
  @Local operationMoreDataList: Array<MessageOperationItem> = Array();
  @Param @Require
  operateMsg: NIMMessageInfo | undefined = undefined;
  @Param @Require
  didClickItem?: (item: MessageOperationItem) => void;
  //撤回时间限制2分钟
  revokeTime: number = ChatKitConfig.messageRevokeTimeLimit;
  @Local viewHeight: number = 0;
  @Local viewWidth: number = 0;

  aboutToAppear(): void {
    this.operationMoreDataList = getOperateMenu(this.operateMsg)
    this.viewHeight =
      ChatConst.menuItemHeight * (Math.ceil(this.operationMoreDataList.length / ChatConst.menuItemColumnNum))
    this.viewWidth = ChatConst.menuItemWidth * Math.min(this.operationMoreDataList.length, ChatConst.menuItemColumnNum)
  }

  build() {
    Column() {
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
    }.backgroundColor(Color.White).borderRadius(8)
    .width(this.viewWidth)
    .height(this.viewHeight)
  }
}