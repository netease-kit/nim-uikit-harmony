/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@ObservedV2
export class IMKitConfigCenter {
  // 是否使用本地会话列表
  @Trace static enableLocalConversation: boolean = true;
}

