/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

// 自定义加载更多布局
interface CustomLoadMoreBuilderParams {
  isVisibleLoadMore?: Boolean;
}

@Builder
export function CustomLoadMoreBuilder(params: CustomLoadMoreBuilderParams) {

  Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
    LoadingProgress()
      .width(18)
      .height(18)

    Text('加载更多中...')
      .margin({ left: 7, bottom: 1 })
      .fontSize(17)
  }
  .width('100%')
  .height(40)
  .backgroundColor('#f4f4f4')
  .visibility(params.isVisibleLoadMore ? Visibility.Visible : Visibility.None)
}