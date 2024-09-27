/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMConversation } from '@nimsdk/base';
import { Constant, PageState } from '../loader/Constant';

@ObservedV2
export class ConversationModel {
  @Trace conversationList: Array<V2NIMConversation> = [];
  offset: number = 1;
  pageSize: number = Constant.PAGE_SIZE;
  isVisiblePullDown: boolean = false;
  pullUpLoadText: Resource = $r('app.string.pull_up_load_text');
  pullUpLoadImage: Resource = $r('app.media.nav_search');
  pullUpLoadHeight: number = Constant.CUSTOM_LAYOUT_HEIGHT;
  isVisiblePullUpLoad: boolean = false;
  offsetY: number = 0;
  pageState: number = PageState.Loading;
  hasMore: boolean = true;
  startIndex = 0;
  endIndex = 0;
  downY = 0;
  lastMoveY = 0;
  isRefreshing: boolean = false;
  isPullRefreshOperation = false;
  isLoading: boolean = false;
  isCanLoadMore: boolean = false;
}