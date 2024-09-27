/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { webview } from '@kit.ArkWeb';
import { NavigationBackBuilder } from '@nimkit/common';

// 跳转页面入口函数
@Builder
function IntroducePageBuilder() {
  IntroducePage()
}

@Component
struct IntroducePage {
  pathStack: NavPathStack = new NavPathStack()
  webController: webview.WebviewController = new webview.WebviewController();
  src: string = "https://netease.im/m/";
  @State isLoading: boolean = true

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.mine_about'),
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })

      Stack() {
        Web({
          src: this.src,
          controller: this.webController
        })
          .onAppear(() => {
            webview.WebviewController.prepareForPageLoad(this.src, true, 2)
          })
          .onRefreshAccessedHistory(() => {
            this.isLoading = false
          })

        if (this.isLoading) {
          LoadingProgress()
            .color("#DEDEDE")
            .width(60)
            .height(60)
        }
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}