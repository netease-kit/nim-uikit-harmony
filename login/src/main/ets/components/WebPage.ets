/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { webview } from '@kit.ArkWeb';

@Entry
@ComponentV2
struct WebPage {
  webController: webview.WebviewController = new webview.WebviewController();
  @Local isLoading: boolean = true
  @Local webParams: WebParams | null = null

  build() {
    NavDestination() {
      if (this.webParams !== null && this.webParams.src &&
        this.webParams.src.length > 0) {
        Stack() {
          Web({
            src: this.webParams.src,
            controller: this.webController
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

    }
    .title(this.webParams?.title ?? '')
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      let paramsStr: string = JSON.stringify(context.pathStack.getParamByName('WebPage')[0])
      this.webParams = JSON.parse(paramsStr)
    })
  }
}

export class WebParams {
  src?: string
  title?: string
}

@Builder
export function WebPageBuilder() {
  WebPage()
}