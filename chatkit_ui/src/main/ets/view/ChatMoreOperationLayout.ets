/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { OperationItem } from './OperationItemLayout';
import { NEChatMoreOperationData } from '../model/NEChatMoreOperationData';

@ComponentV2
export struct NEChatMoreOperation {
  // 面板回调
  @Param @Require dataList: Array<NEChatMoreOperationData>;
  @Param @Require onDidClick?: (data: NEChatMoreOperationData) => void;

  build() {
    GridRow({
      breakpoints: {
        reference: BreakpointsReference.WindowSize
      }
    }) {
      ForEach(this.dataList, (data: NEChatMoreOperationData) => {
        GridCol({ span: 3 }) {
          Row() {
            OperationItem({
              operationData: data, onItemClick: (data) => {
                if (this.onDidClick) {
                  this.onDidClick(data);
                }
              }
            }).backgroundColor("rgba(255, 255, 255, 0)")
          }.width("100%").height('50vp')
        }.backgroundColor('#E9EFF5')
      })
    }
  }
}