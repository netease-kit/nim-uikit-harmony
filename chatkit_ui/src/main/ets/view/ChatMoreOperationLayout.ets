/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { OperationItem } from './OperationItemLayout';
import { NEChatMoreOperationData } from '../model/NEChatMoreOperationData';

const OPERATION_ITEM_VISUAL_HEIGHT = 50
const OPERATION_ITEM_REAL_HEIGHT = 74

@ComponentV2
export struct NEChatMoreOperation {
  // 面板回调
  @Param @Require dataList: Array<NEChatMoreOperationData>;
  @Param @Require onDidClick?: (data: NEChatMoreOperationData) => void;

  build() {
    GridRow({
      columns: 12
    }) {
      ForEach(this.dataList, (data: NEChatMoreOperationData, index: number) => {
        GridCol({ span: 3 }) {
          Row() {
            OperationItem({
              operationData: data, onItemClick: (data) => {
                if (this.onDidClick) {
                  this.onDidClick(data);
                }
              }
            }).backgroundColor("rgba(255, 255, 255, 0)")
              .height(OPERATION_ITEM_VISUAL_HEIGHT)
          }
          .width("100%")
          .height(OPERATION_ITEM_REAL_HEIGHT)
          .alignItems(VerticalAlign.Top)
          .margin({ bottom: 10 })
        }.backgroundColor('#E9EFF5')
      })
    }
  }
}
