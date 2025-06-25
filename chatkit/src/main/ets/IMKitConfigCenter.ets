/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@ObservedV2
export class IMKitConfigCenter {
  /**
   * 是否使用本地会话列表
   */
  @Trace static enableLocalConversation: boolean = true;
  /**
   * 是否显示在线状态
   */
  @Trace static enableShownOnlineState: boolean = true;
  /**
   * 是否启用 AI 数字人功能
   */
  @Trace static enableAI: boolean = false;
}