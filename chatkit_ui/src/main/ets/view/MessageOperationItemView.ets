/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { MessageOperationItem } from '../model/MessageOperationItem';

@Entry
@ComponentV2
export struct MessageOperationItemView {
  @Param @Require
  operationData: MessageOperationItem;

  build() {
    Column() {
      Image(this.operationData.operationImage).width(18).height(18)
      Text(this.operationData.operationText)
        .fontSize(14)
        .fontColor($r('app.color.color_chat_operation_item_text'))
        .margin({ top: 6 })
    }
  }
}