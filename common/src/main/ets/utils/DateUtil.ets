/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export class DateUtil {
  /**
   *将输入的日期字符串转换为Date日期类型
   * @param dateString
   * @returns
   */
  static parse(dateString: string): Date {
    return new Date(dateString);
  }

  /**
   *将传入的日期字符串按照传入的format进行格式化输出,不传默认为yyyy-MM-dd,日期格式化年月日时分秒为y-M-d H:m:s
   * @param value
   * @param format  格式化字符串
   * @returns
   */
  static formatDate(value: string, format: string = 'yyyy-MM-dd'): string {
    const date = new Date(value);
    if (value.split(' ').length <= 1 && value.split('T').length <= 1) {
      date.setHours(0);
      date.setMinutes(0);
      date.setSeconds(0);
    }
    const year = date.getFullYear();
    const month = DateUtil.padZero(date.getMonth() + 1);
    const day = DateUtil.padZero(date.getDate());
    const hours = DateUtil.padZero(date.getHours());
    const minutes = DateUtil.padZero(date.getMinutes());
    const seconds = DateUtil.padZero(date.getSeconds());
    let formattedDate = format.replace("yyyy", year.toString());
    formattedDate = formattedDate.replace("MM", month);
    formattedDate = formattedDate.replace("dd", day);
    formattedDate = formattedDate.replace("HH", hours);
    formattedDate = formattedDate.replace("mm", minutes);
    formattedDate = formattedDate.replace("ss", seconds);
    return formattedDate;
  }

  /**
   *将日期类型的Date根据传入的format格式化成日期字符串(format必传)
   * @param date
   * @param formatString  格式化字符串
   * @returns
   */
  static format(date: Date, formatString: string): string {
    const year = date.getFullYear();
    const month = DateUtil.padZero(date.getMonth() + 1);
    const day = DateUtil.padZero(date.getDate());
    const hours = DateUtil.padZero(date.getHours());
    const minutes = DateUtil.padZero(date.getMinutes());
    const seconds = DateUtil.padZero(date.getSeconds());

    let formattedDate = formatString.replace("yyyy", year.toString());
    formattedDate = formattedDate.replace("MM", month);
    formattedDate = formattedDate.replace("dd", day);
    formattedDate = formattedDate.replace("HH", hours);
    formattedDate = formattedDate.replace("mm", minutes);
    formattedDate = formattedDate.replace("ss", seconds);

    return formattedDate;
  }

  /**
   * 计算两个Date的日期差单位为天
   * @param startDate  开始日期
   * @param endDate  结束日期
   * @returns
   */
  static dateDiff(startDate: Date, endDate: Date): number {
    const oneDay = 24 * 60 * 60 * 1000; // 一天的毫秒数
    // 将时间戳转换为整数天数
    const start = Math.floor(startDate.getTime() / oneDay);
    const end = Math.floor(endDate.getTime() / oneDay);
    const difference = end - start; // 计算差值天数
    return difference;
  }

  /**
   *计算两个字符串日期的差单位为天
   * @param startDateStr 开始日期字符串
   * @param endDateStr   结束日期字符串
   * @returns
   */
  static strDateDiff(startDateStr: string, endDateStr: string): number {
    let startDate = new Date(startDateStr);
    let endDate = new Date(endDateStr);
    const oneDay = 24 * 60 * 60 * 1000; // 一天的毫秒数
    const difference = Math.floor((endDate.getTime() - startDate.getTime()) / oneDay); // 计算差值天数
    return difference;
  }

  /**
   * 判断传入字符串是否是日期字符串
   * @param value 待验证的字符串
   * @returns
   */
  public static isDate(value: string): boolean {
    //日期类型正则集合
    const dateTimeRegexList = [
      /^\d{8}$/,
      /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/,
      /^([01]\d|2[0-3]):[0-5]\d$/,
      /^\d{4}[-/]\d{2}[-/]\d{2}$/,
      /^\d{4}[-/]\d{2}[-/]\d{2} ([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/,
      /^\d{4}[/]\d{2}[/]\d{2}$/,
      /^\d{4}[/]\d{2}[/]\d{2} ([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/,
      /^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d:[0-5]\d\.\d{1,3}Z$/
    ];
    let result = dateTimeRegexList.filter(item => {
      return item.test(value)
    }).length;
    if (result > 0) {
      return true;
    }
    return false;
  }

  private static padZero(num: number): string {
    return num.toString().padStart(2, "0");
  }
}