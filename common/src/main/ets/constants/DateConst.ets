/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export class DateConst {
  /**
   * yyyyMMdd 格式年月日
   */
  static YMD: string = "yyyyMMdd";
  /**
   * HH:mm:ss 格式时间
   */
  static HMS: string = "HH:mm:ss";
  /**
   * HH:mm 格式时间
   */
  static HM: string = "HH:mm";
  /**
   *yyyy-MM-dd 格式年月日
   */
  static YMD_HLINE: string = "yyyy-MM-dd";
  /**
   *yyyy-MM-dd HH:mm:ss  格式日期时间
   */
  static YMD_HLINE_HMS: string = "yyyy-MM-dd HH:mm:ss";
  /**
   *yyyy-MM-dd HH:mm  格式日期时间
   */
  static YMD_HLINE_HM: string = "yyyy-MM-dd HH:mm";
  /**
   *yyyy/MM/dd 格式日期(注:官方bug对/兼容问题可能会有问题只显示yyyy格式日期)
   */
  static YMD_BLINE: string = "yyyy/MM/dd";
  /**
   *yyyy/MM/dd HH:mm:ss 格式日期(注:官方bug对/兼容问题可能会有问题只显示yyyy格式日期)
   */
  static YMD_BLINE_HMS: string = "yyyy/MM/dd HH:mm:ss";
  /**
   *yyyy/MM/dd HH:mm  格式日期(注:官方bug对/兼容问题可能会有问题只显示yyyy格式日期)
   */
  static YMD_BLINE_HM: string = "yyyy/MM/dd HH:mm";
}