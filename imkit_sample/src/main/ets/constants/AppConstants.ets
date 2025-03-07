/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * Route constants for Router.
 */
export class AppConstants {
  /**
   * 【听筒模式】存储 key
   */
  static readonly KEY_SETTING_EARPIECE_MODE: string = 'KEY_SETTING_EARPIECE_MODE';
  /**
   * 【消息已读未读功能】存储 key
   */
  static readonly KEY_SETTING_MESSAGE_READ_OR: string = 'KEY_SETTING_MESSAGE_READ_OR';
  /**
   * use local conversation kit
   * if true , use local conversation kit
   * if false , use remote conversation kit
   */
  static readonly KEY_SETTING_LOCAL_CONVERSATION: string = 'KEY_SETTING_MESSAGE_READ_OR';
}