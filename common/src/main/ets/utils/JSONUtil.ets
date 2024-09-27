/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { DateConst } from '../constants/DateConst';
import { DateUtil } from './DateUtil';

export class JSONUtil {
  /**
   * 将传入的json对象格式化成json字符串
   * @param object 待转换的对象
   * @param formatStr 字符串格式化模版
   * @returns
   */
  static toJSONString(object: Object, formatStr?: string): string {
    const stringifyValue = (value: Object): string => {
      if (value instanceof Map) {
        let jsonObject: Record<string, Object> = {};
        value.forEach((val: string, key: Object) => {
          if (key !== undefined && val !== undefined) {
            jsonObject[key as string] = stringifyValue(val);
          }
        });
        return JSON.stringify(jsonObject);
      } else if (Array.isArray(value)) {
        let a: Object[] = value.map((item: Object) => stringifyValue(item));
        return JSON.stringify(a);
      } else if (value instanceof Date) {
        if (!formatStr) {
          formatStr = DateConst.YMD_HLINE
        }
        return DateUtil.format(value, formatStr);
      } else if (typeof value === 'number') {
        return new String(value).toString();
      } else if (typeof value === 'boolean') {
        return new String(value).toString();
      } else if (typeof value === 'object') {
        let result: Record<string, Object> = {};
        let val = value as Record<string, Object>;
        for (let key of Object.entries(val)) {
          result[key[0]] = stringifyValue(key[1]);
        }
        return JSON.stringify(result);
      } else {
        return value;
      }
    };

    if (Array.isArray(object)) {
      return JSON.stringify(object.map((item: Object) => stringifyValue(item)));
    } else {
      return stringifyValue(object);
    }
  }


  /**
   *将传入的json字符串格式化为Object对象
   * @param jsonStr
   * @returns
   * @deprecated 使用JSONObject或者JSONArray/JSONArrayList 方法代替
   */
  static parse(jsonStr: string): Object {
    return JSON.parse(jsonStr);
  }

  /**
   * 将传入的json字符串格式化为指定的实体对象,如果实体中有日期类型默认为yyyy-MM-dd，并且支持嵌套类
   * @param jsonStr  待转换字符串
   * @param formatStr 字符串格式化模版
   * @deprecated 使用JSONObject或者JSONArray/JSONArrayList 方法代替
   */
  static parseObject<T>(jsonStr: string, formatStr?: string): T {
    const parseValue = (value: Object): Object => {
      if (JSONUtil.isJSONStringArray(value as string)) {
        return JSONUtil.parseStringArray(value as string);
      } else if (!DateUtil.isDate(value as string) && JSONUtil.isNumber(value as string)) {
        return parseFloat(value as string);
      } else if (DateUtil.isDate(value as string)) {
        if (!formatStr) {
          formatStr = DateConst.YMD_HLINE
        }
        return DateUtil.formatDate(value as string, formatStr);
      } else if (JSONUtil.isBoolean(value as string)) {
        return new Boolean(value).valueOf();
      } else if (JSONUtil.isJSONString(value as string)) {
        return JSONUtil.parseObject(value as string);
      } else {
        return value;
      }
    };
    let result: Record<string, Object> = {};
    let json: Record<string, Object> = JSON.parse(jsonStr);
    for (let key of Object.entries(json)) {


      let value = key[1];
      if (Array.isArray(value)) {
        result[key[0]] = parseValue(value) as [];
      } else if (JSONUtil.isJSONStringArray(value as string)) {
        result[key[0]] = parseValue(value) as [];
      } else {
        result[key[0]] = parseValue(value);
      }
    }
    return result as T;
  }


  /**
   * 将传入的json字符串格式化为指定的实体对象集合
   * @param jsonStr
   * @param formatStr 字符串格式化模版
   * @returns
   * @deprecated 使用JSONObject或者JSONArray/JSONArrayList 方法代替
   */
  static parseArray<T>(jsonStr: string, formatStr?: string): Array<T> {
    let result: Array<T> = new Array<T>();
    let arr: Record<string, Object> = JSON.parse(jsonStr);
    for (let index = 0; index < arr.length; index++) {
      const item = arr[index];
      result.push(JSONUtil.parseObject<T>(item as string, formatStr));
    }
    return result;
  }

  /**
   * 将字符串格式Array转换成Array数组
   * @param str 待验证字符串
   * @returns
   */
  public static parseStringArray(jsonStr: string): Array<Object> {
    const jsonArray: Record<string, Object> = JSON.parse(jsonStr); // 解析字符串为对象数组
    const result: Array<Object> = new Array();
    for (let key of Object.entries(jsonArray as Record<string, Object>)) {
      const obj: Record<string, Object> = JSON.parse(key[1] as string); // 解析字符串为对象
      result.push(obj);
    }
    return result;
  }

  /**
   * 判断传入的字符串是否是布尔类型
   * @param str
   * @returns
   */
  public static isBoolean(str: string): boolean {
    return typeof str === 'boolean' || str === 'true' || str === 'false';
  }

  /**
   * 判断是否是字符串格式Array
   * @param str 待验证字符串
   * @returns
   */
  public static isJSONStringArray(str: string): boolean {
    try {
      const jsonArray: Record<string, Object> = JSON.parse(str);
      if (!Array.isArray(jsonArray)) {
        return false;
      }
      for (let key of Object.entries(jsonArray as Record<string, Object>)) {
        if (!JSONUtil.isJSONString(key[1] as string)) {
          return false;
        }
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 判断是否是json数组
   * @param str
   * @returns
   */
  public static isJSONArray(str: string): boolean {
    try {
      const jsonArray: Record<string, Object> = JSON.parse(str);
      if (!Array.isArray(jsonArray)) {
        return false;
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 判断是否是字符串格式json
   * @param str 待验证字符串
   * @returns
   */
  public static isJSONString(str: string): boolean {
    try {
      JSON.parse(str);
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 是否是字符串
   * @param str 待验证字符串
   * @returns
   */
  public static isNumber(str: string): boolean {
    return /^\d+(\.\d+)?$/.test(str);
  }
}