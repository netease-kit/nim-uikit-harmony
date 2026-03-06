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
  /**
   * 是否反垃圾检测提示消息，控制消息发送后命中反垃圾，是否提示TIPS消息
   */
  @Trace static enableAntiSpamTipMessage: boolean = true;
  /**
   * 是否开启云端搜索功能
   */
  @Trace static enableCloudSearch = false
}