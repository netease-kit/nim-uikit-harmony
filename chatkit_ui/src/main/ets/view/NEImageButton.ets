/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@Entry
@Component
export struct NEImageButton {
  @Prop image: Resource;
  onDidClick?: () => void;

  build() {
    RelativeContainer() {
      Image(this.image)
        .width(24)
        .height(24)
        .alignRules({
          middle: { anchor: "__container__", align: HorizontalAlign.Center },
          center: { anchor: "__container__", align: VerticalAlign.Center }
        })
        .hitTestBehavior(HitTestMode.None)

      Button().alignRules({
        left: { anchor: "__container__", align: HorizontalAlign.Start },
        right: { anchor: "__container__", align: HorizontalAlign.End },
        bottom: { anchor: "__container__", align: VerticalAlign.Bottom },
        top: { anchor: "__container__", align: VerticalAlign.Top }
      }).onClick(() => {
        if (this.onDidClick) {
          this.onDidClick()
        }
      }).backgroundColor('rgba(0, 0, 0, 0)')
    }
  }
}