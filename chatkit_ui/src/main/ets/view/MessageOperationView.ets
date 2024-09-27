/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { NIMMessageInfo } from '../model/NIMMessageInfo';
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.
import { MessageOperationItem, MessageOperationType } from '../model/MessageOperationItem';
import { MessageOperationItemView } from '../view/MessageOperationItemView';
import { V2NIMMessageType } from '@nimsdk/base/src/main/ets/nim/sdk/V2NIMMessageService';
import { systemDateTime } from '@kit.BasicServicesKit';
import { ChatKitClient } from '@nimkit/chatkit';
import { ChatConst } from '../constants/ChatConst';
import { V2NIMMessageSendingState } from '@nimsdk/base';

@ComponentV2
export struct MessageOperationView {
  @Local operationMoreDataList: Array<MessageOperationItem> = Array();
  @Param @Require
  operateMsg: NIMMessageInfo | undefined = undefined;
  @Param @Require
  didClickItem?: (item: MessageOperationItem) => void;
  //撤回时间限制2分钟
  revokeTime: number = ChatConst.messageRevokeTimeLimit;
  @Local viewHeight: number = 0;
  @Local viewWidth: number = 0;

  static computeViewWidth(msg: NIMMessageInfo | undefined) {
    if (msg == undefined) {
      return 0
    }
    let localExtension = msg?.message.localExtension;
    let count = 0
    if (localExtension == undefined || !localExtension.includes(ChatConst.revokeLocalKey)) {
      count++
      if (msg !== undefined &&
        msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
        count++
      }
      if (msg !== undefined &&
        msg.message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
        && systemDateTime.getTime() - msg.message.createTime < ChatConst.messageRevokeTimeLimit
        && msg.message.senderId == ChatKitClient.getLoginUserId()) {
        count++
      }
    }
    return ChatConst.menuItemWidth * count
  }

  aboutToAppear(): void {
    // 撤回消息长按没有任何操作按钮
    let localExtension = this.operateMsg?.message.localExtension;
    if (localExtension == undefined || !localExtension.includes(ChatConst.revokeLocalKey)) {
      let deleteItem = new MessageOperationItem()
      deleteItem.operationType = MessageOperationType.Delete;
      deleteItem.operationText = $r('app.string.chat_operation_delete');
      deleteItem.operationImage = $r('app.media.ic_public_chat_operation_delete');
      this.operationMoreDataList.push(deleteItem);
      if (this.operateMsg !== undefined &&
        this.operateMsg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
        let copyItem = new MessageOperationItem()
        copyItem.operationType = MessageOperationType.Copy;
        copyItem.operationText = $r('app.string.chat_operation_copy');
        copyItem.operationImage = $r('app.media.ic_public_chat_operation_copy');
        this.operationMoreDataList.push(copyItem)
      }
      if (this.operateMsg !== undefined &&
        this.operateMsg.message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED
        && systemDateTime.getTime() - this.operateMsg.message.createTime < this.revokeTime
        && this.operateMsg.message.senderId == ChatKitClient.getLoginUserId()) {

        let undoItem = new MessageOperationItem()
        undoItem.operationImage = $r('app.media.ic_public_chat_operation_undo');
        undoItem.operationText = $r('app.string.chat_operation_undo');
        undoItem.operationType = MessageOperationType.Undo;
        this.operationMoreDataList.push(undoItem)
      }
    }
    this.viewWidth = ChatConst.menuItemWidth * this.operationMoreDataList.length
    this.viewHeight = ChatConst.menuItemHeight
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