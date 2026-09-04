/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
@ObservedV2
export class ChatKitConfig {
  //消息撤回时间限制
  static messageRevokeTimeLimit: number = 2 * 60 * 1000;
  //消息时间展示的间隔，默认5分钟
  static messageTimeGap: number = 5 * 60 * 1000;
  //消息分页拉取，每页大小
  static chatMessagePageSize: number = 50;
  // 消息已读未读功能
  static messageReadState: boolean = true;
  // 消息表情快捷回复功能
  @Trace static enableEmojiReaction: boolean = true;
  // 跳转到最早未读消息功能
  @Trace static enableLastReadPosition: boolean = true;
}
