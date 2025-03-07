/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEChatMoreOperationData } from '../model/NEChatMoreOperationData';

@Entry
@ComponentV2
export struct OperationItem {
  @Param @Require onItemClick?: (data: NEChatMoreOperationData) => void;
  @Param @Require operationData: NEChatMoreOperationData;

  build() {
    RelativeContainer() {
      Button()
        .size({ width: 56, height: 56 })
        .backgroundColor("#FFFFFF")
        .type(ButtonType.Normal)
        .borderRadius(10)
        .id("operation_item")
        .alignRules({
          center: { anchor: "__container__", align: VerticalAlign.Center },
          middle: { anchor: "__container__", align: HorizontalAlign.Center }
        })
        .onClick(() => {
          if (this.onItemClick) {
            this.onItemClick(this.operationData)
          }
        })

      Image($r(this.operationData.imageSource))
        .width(30)
        .height(30)
        .alignRules({
          center: { anchor: "__container__", align: VerticalAlign.Center },
          middle: { anchor: "__container__", align: HorizontalAlign.Center }
        }).hitTestBehavior(HitTestMode.None)

      Text(this.operationData.operationTitle)
        .fontColor("#666666")
        .fontSize(10)
        .offset({ y: 5 })
        .alignRules({
          middle: { anchor: "__container__", align: HorizontalAlign.Center },
          top: { anchor: "operation_item", align: VerticalAlign.Bottom }
        })

    }
  }
}