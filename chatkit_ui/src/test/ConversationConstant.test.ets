/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';

/**
 * Conversationkit_UI Constant 常量验证 & PageState 枚举测试
 */

class Constant {
  static readonly PAGE_SIZE: number = 100;
  static readonly Y_OFF_SET_COEFFICIENT: number = 0.1;
  static readonly ANIMATION_DURATION: number = 2000;
  static readonly DELAY_TIME: number = 1000;
  static readonly CUSTOM_LAYOUT_HEIGHT: number = 70;
}

const enum PageState {
  Loading = 0,
  Success = 1,
  Fail = 2
}

export default function conversationConstantTest() {
  describe('ConversationKit_Constant', () => {
    it('should_have_correct_PAGE_SIZE', 0, () => {
      expect(Constant.PAGE_SIZE).assertEqual(100);
    });

    it('should_have_correct_Y_OFF_SET_COEFFICIENT', 0, () => {
      expect(Constant.Y_OFF_SET_COEFFICIENT).assertEqual(0.1);
    });

    it('should_have_correct_ANIMATION_DURATION', 0, () => {
      expect(Constant.ANIMATION_DURATION).assertEqual(2000);
    });

    it('should_have_correct_DELAY_TIME', 0, () => {
      expect(Constant.DELAY_TIME).assertEqual(1000);
    });

    it('should_have_correct_CUSTOM_LAYOUT_HEIGHT', 0, () => {
      expect(Constant.CUSTOM_LAYOUT_HEIGHT).assertEqual(70);
    });
  });

  describe('ConversationKit_PageState', () => {
    it('should_have_Loading_as_0', 0, () => {
      expect(PageState.Loading).assertEqual(0);
    });

    it('should_have_Success_as_1', 0, () => {
      expect(PageState.Success).assertEqual(1);
    });

    it('should_have_Fail_as_2', 0, () => {
      expect(PageState.Fail).assertEqual(2);
    });
  });
}
