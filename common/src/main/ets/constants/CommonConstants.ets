/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * Common constants for all features.
 */
export class CommonConstants {
  /**
   * Breakpoint sm.
   */
  static readonly BREAKPOINTS_SM_NAME: string = 'sm';
  /**
   * Breakpoint md.
   */
  static readonly BREAKPOINTS_MD_NAME: string = 'md';
  /**
   * Breakpoint lg.
   */
  static readonly BREAKPOINTS_LG_NAME: string = 'lg';
  /**
   * Breakpoint xl.
   */
  static readonly BREAKPOINTS_XL_NAME: string = 'xl';
  /**
   * The break point value of sm device.
   */
  static readonly BREAKPOINTS_SM_SIZE: number = 0;
  /**
   * The break point value of md device.
   */
  static readonly BREAKPOINTS_MD_SIZE: number = 600;
  /**
   * The break point value of lg device.
   */
  static readonly BREAKPOINTS_LG_SIZE: number = 840;
  /**
   * The break point value of xl device.
   */
  static readonly BREAKPOINTS_XL_SIZE: number = 1320;
  /**
   * Initialize device breakpoints.
   */
  static readonly BREAKPOINTS_INITIALIZE_NAME: string = 'md';
  /**
   * Initialize device breakpoint Id.
   */
  static readonly BREAKPOINT_ID_INITIALIZE_NAME: string = 'unknown';
  /**
   * 【听筒模式】存储 key
   */
  static readonly KEY_SETTING_EARPIECE_MODE: string = 'KEY_SETTING_EARPIECE_MODE';
  /**
   * 【消息已读未读功能】存储 key
   */
  static readonly KEY_SETTING_MESSAGE_READ_OR: string = 'KEY_SETTING_MESSAGE_READ_OR';
}