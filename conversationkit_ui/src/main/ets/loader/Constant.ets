/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export class Constant {
  /**
   * The page size.
   */
  static readonly PAGE_SIZE: number = 100;
  /**
   * The off set coefficient.
   */
  static readonly Y_OFF_SET_COEFFICIENT: number = 0.1;
  /**
   * The animation duration.
   */
  static readonly ANIMATION_DURATION: number = 2000;
  /**
   * The delay time.
   */
  static readonly DELAY_TIME: number = 1000;
  /**
   * The refresh and load height.
   */
  static readonly CUSTOM_LAYOUT_HEIGHT: number = 70;
}

/**
 * The newsList state enum.
 */
export const enum PageState {
  Loading = 0,
  Success = 1,
  Fail = 2
}