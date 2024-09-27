/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationModel } from '../viewmodel/ConversationModel';
import { Constant } from './Constant';

export function listTouchEvent(that: ConversationModel, event: TouchEvent) {
  switch (event.type) {
    case TouchType.Down:
      that.downY = event.touches[0].y;
      that.lastMoveY = event.touches[0].y;
      break;
    case TouchType.Move:
      if ((that.isRefreshing === true) || (that.isLoading === true)) {
        return;
      }
      let isDownPull = event.touches[0].y - that.lastMoveY > 0;
      if (((isDownPull === true) || (that.isPullRefreshOperation === true)) && (that.isCanLoadMore === false)) {
        // Finger movement, processing pull-down refresh.
        // touchMovePullRefresh(that, event);
      } else {
        // Finger movement, processing load more.
        touchMoveLoadMore(that, event);
      }
      that.lastMoveY = event.touches[0].y;
      break;
    case TouchType.Cancel:
      break;
    case TouchType.Up:
      if ((that.isRefreshing === true) || (that.isLoading === true)) {
        return;
      }
      if ((that.isPullRefreshOperation === true)) {
        // Lift your finger and pull down to refresh.
        // touchUpPullRefresh(that);
      } else {
        // Fingers up, handle loading more.
        touchUpLoadMore(that);
      }
      break;
    default:
      break;
  }
}

export function touchMoveLoadMore(that: ConversationModel, event: TouchEvent) {
  if (that.endIndex === that.conversationList.length - 1 || that.endIndex === that.conversationList.length) {
    that.offsetY = event.touches[0].y - that.downY;
    if (Math.abs(that.offsetY) > vp2px(that.pullUpLoadHeight) / 2) {
      that.isCanLoadMore = true;
      that.isVisiblePullUpLoad = true;
      that.offsetY = -vp2px(that.pullUpLoadHeight) + that.offsetY * Constant.Y_OFF_SET_COEFFICIENT;
    }
  }
}


export function touchUpLoadMore(that: ConversationModel) {
  let self = that;
  animateTo({
    duration: Constant.ANIMATION_DURATION,
  }, () => {
    self.offsetY = 0;
  })
  if ((self.isCanLoadMore === true) && (self.hasMore === true)) {
    self.isLoading = true;
    setTimeout(() => {
      closeLoadMore(that);
      // NewsViewModel.getNewsList(self.currentPage, self.pageSize, Const.GET_NEWS_LIST).then((data: NewsData[]) => {
      //   if (data.length === self.pageSize) {
      //     self.currentPage++;
      //     self.hasMore = true;
      //   } else {
      //     self.hasMore = false;
      //   }
      //   self.newsData = self.newsData.concat(data);
      // }).catch((err: string | Resource) => {
      //   promptAction.showToast({ message: err });
      // })
    }, Constant.DELAY_TIME);
  } else {
    closeLoadMore(self);
  }
}

export function closeLoadMore(that: ConversationModel) {
  that.isCanLoadMore = false;
  that.isLoading = false;
  that.isVisiblePullUpLoad = false;
}