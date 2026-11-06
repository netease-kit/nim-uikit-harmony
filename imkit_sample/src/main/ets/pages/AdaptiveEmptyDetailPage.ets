/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { CommonEmptyResult } from '@nimkit/common'

export function resolveAdaptiveEmptyDetailTip(target: string): ResourceStr {
  if (target === 'contact') {
    return $r('app.string.adaptive_detail_empty_contact')
  }
  if (target === 'mine') {
    return $r('app.string.adaptive_detail_empty_mine')
  }
  return $r('app.string.adaptive_detail_welcome')
}

@ComponentV2
struct AdaptiveEmptyDetailPage {
  @Local placeholderTarget: string = 'conversation'

  build() {
    NavDestination() {
      CommonEmptyResult({
        tips: resolveAdaptiveEmptyDetailTip(this.placeholderTarget),
        emptyImage: this.placeholderTarget === 'conversation' ?
          $r('app.media.adaptive_welcome_yunxin') : $r('app.media.empty_image'),
        emptyImageWidth: this.placeholderTarget === 'conversation' ? 220 : 122,
        emptyImageHeight: this.placeholderTarget === 'conversation' ? 180 : 91,
        centerContent: true
      })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      const params = context.pathStack.getParamByName('AdaptiveEmptyDetailPage') as string[]
      const target = params.length > 0 ? params[0] as string : 'conversation'
      if (target === 'contact' || target === 'mine' || target === 'conversation') {
        this.placeholderTarget = target
      }
    })
  }
}

@Builder
export function AdaptiveEmptyDetailPageBuilder() {
  AdaptiveEmptyDetailPage()
}
