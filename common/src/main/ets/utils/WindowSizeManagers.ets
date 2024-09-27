/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { window } from '@kit.ArkUI';

/*
  获取屏幕尺寸
 */
export class WindowSizeManager {
  public size: window.Size = { width: 0, height: 0 };
  public topRectHeight: number = 0;
  public bottomRectHeight: number = 0;

  constructor(context?: Context) {
    window.getLastWindow(context ?? getContext(this)).then((value: window.Window) => {
      const avoidAreaType = window.AvoidAreaType.TYPE_SYSTEM; // 系统默认区域，包括状态栏，导航栏
      const avoidArea = value.getWindowAvoidArea(avoidAreaType);
      this.topRectHeight = px2vp(avoidArea.topRect.height);
      this.bottomRectHeight = px2vp(avoidArea.bottomRect.height);

      const rect: window.Rect = value.getWindowProperties().windowRect;
      this.size.width = px2vp(rect.width);
      this.size.height = px2vp(rect.height);
      console.log(`[windowWidth]${this.size.width} [windowHeight]${this.size.height}`);
    })
  }
}

export const windowSizeManager: WindowSizeManager = new WindowSizeManager();