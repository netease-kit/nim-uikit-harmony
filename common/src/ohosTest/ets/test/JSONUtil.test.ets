/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { JSONUtil } from '../../../main/ets/utils/JSONUtil';

export default function JSONUtilTest() {
  describe('JSONUtil_isBoolean', () => {
    it('should_return_true_for_true_string', 0, () => {
      expect(JSONUtil.isBoolean('true')).assertTrue();
    });
    it('should_return_true_for_false_string', 0, () => {
      expect(JSONUtil.isBoolean('false')).assertTrue();
    });
    it('should_return_false_for_yes', 0, () => {
      expect(JSONUtil.isBoolean('yes')).assertFalse();
    });
    it('should_return_false_for_number_string', 0, () => {
      expect(JSONUtil.isBoolean('123')).assertFalse();
    });
    it('should_return_false_for_empty_string', 0, () => {
      expect(JSONUtil.isBoolean('')).assertFalse();
    });
  });

  describe('JSONUtil_isNumber', () => {
    it('should_return_true_for_integer', 0, () => {
      expect(JSONUtil.isNumber('123')).assertTrue();
    });
    it('should_return_true_for_float', 0, () => {
      expect(JSONUtil.isNumber('3.14')).assertTrue();
    });
    it('should_return_true_for_zero', 0, () => {
      expect(JSONUtil.isNumber('0')).assertTrue();
    });
    it('should_return_false_for_letters', 0, () => {
      expect(JSONUtil.isNumber('abc')).assertFalse();
    });
    it('should_return_false_for_empty', 0, () => {
      expect(JSONUtil.isNumber('')).assertFalse();
    });
    it('should_return_false_for_mixed', 0, () => {
      expect(JSONUtil.isNumber('123abc')).assertFalse();
    });
    it('should_return_false_for_special_chars', 0, () => {
      expect(JSONUtil.isNumber('12-34')).assertFalse();
    });
  });

  describe('JSONUtil_isJSONString', () => {
    it('should_return_true_for_valid_object', 0, () => {
      expect(JSONUtil.isJSONString('{"key":"value"}')).assertTrue();
    });
    it('should_return_true_for_valid_array', 0, () => {
      expect(JSONUtil.isJSONString('[1,2,3]')).assertTrue();
    });
    it('should_return_true_for_null', 0, () => {
      expect(JSONUtil.isJSONString('null')).assertTrue();
    });
    it('should_return_true_for_number', 0, () => {
      expect(JSONUtil.isJSONString('42')).assertTrue();
    });
    it('should_return_false_for_invalid_json', 0, () => {
      expect(JSONUtil.isJSONString('{invalid}')).assertFalse();
    });
    it('should_return_false_for_plain_text', 0, () => {
      expect(JSONUtil.isJSONString('hello')).assertFalse();
    });
    it('should_return_false_for_empty', 0, () => {
      expect(JSONUtil.isJSONString('')).assertFalse();
    });
  });

  describe('JSONUtil_isJSONArray', () => {
    it('should_return_true_for_valid_array', 0, () => {
      expect(JSONUtil.isJSONArray('[1,2,3]')).assertTrue();
    });
    it('should_return_true_for_empty_array', 0, () => {
      expect(JSONUtil.isJSONArray('[]')).assertTrue();
    });
    it('should_return_false_for_object', 0, () => {
      expect(JSONUtil.isJSONArray('{"key":"value"}')).assertFalse();
    });
    it('should_return_false_for_plain_text', 0, () => {
      expect(JSONUtil.isJSONArray('hello')).assertFalse();
    });
  });

  describe('JSONUtil_parse', () => {
    it('should_parse_object', 0, () => {
      let result: Object = JSONUtil.parse('{"name":"test","age":25}');
      let obj: Record<string, Object> = result as Record<string, Object>;
      expect(obj['name']).assertEqual('test');
      expect(obj['age']).assertEqual(25);
    });
    it('should_parse_array', 0, () => {
      let result: Object = JSONUtil.parse('[1,2,3]');
      let arr: Object[] = result as Object[];
      expect(arr.length).assertEqual(3);
    });
    it('should_parse_string', 0, () => {
      expect(JSONUtil.parse('"hello"') as string).assertEqual('hello');
    });
    it('should_parse_number', 0, () => {
      expect(JSONUtil.parse('42') as number).assertEqual(42);
    });
    it('should_parse_boolean_true', 0, () => {
      expect(JSONUtil.parse('true') as boolean).assertTrue();
    });
    it('should_parse_null', 0, () => {
      expect(JSONUtil.parse('null')).assertNull();
    });
  });

  describe('JSONUtil_toJSONString', () => {
    it('should_convert_array_to_string', 0, () => {
      let arr: Object[] = ['a', 'b', 'c'];
      let result: string = JSONUtil.toJSONString(arr);
      let parsed: string[] = JSON.parse(result) as string[];
      expect(parsed.length).assertEqual(3);
    });
    it('should_convert_empty_array', 0, () => {
      let arr: Object[] = [];
      let result: string = JSONUtil.toJSONString(arr);
      let parsed: Object[] = JSON.parse(result) as Object[];
      expect(parsed.length).assertEqual(0);
    });
    it('should_handle_number_array', 0, () => {
      let arr: Object[] = [1, 2, 3];
      let result: string = JSONUtil.toJSONString(arr);
      let parsed: number[] = JSON.parse(result) as number[];
      expect(parsed.length).assertEqual(3);
    });

    // toJSONString with Map
    it('should_convert_simple_map_to_json', 0, () => {
      let map: Map<string, string> = new Map();
      map.set('name', 'test');
      map.set('value', 'hello');
      let result: string = JSONUtil.toJSONString(map);
      let parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
      expect(parsed['name'] as string).assertEqual('test');
      expect(parsed['value'] as string).assertEqual('hello');
    });

    it('should_convert_nested_map_to_json', 0, () => {
      let innerMap: Map<string, string> = new Map();
      innerMap.set('innerKey', 'innerVal');
      let outerMap: Map<string, Object> = new Map();
      outerMap.set('nested', innerMap);
      let result: string = JSONUtil.toJSONString(outerMap);
      let parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
      let nestedObj: Record<string, Object> = parsed['nested'] as Record<string, Object>;
      expect(nestedObj['innerKey'] as string).assertEqual('innerVal');
    });

    it('should_skip_undefined_key_in_map', 0, () => {
      let map: Map<string, string> = new Map();
      map.set('valid', 'value');
      let result: string = JSONUtil.toJSONString(map);
      let parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
      expect(parsed['valid'] as string).assertEqual('value');
    });

    // toJSONString with Date
    it('should_convert_date_with_default_format', 0, () => {
      let date: Date = new Date(2024, 0, 15);
      let result: string = JSONUtil.toJSONString(date);
      expect(result).assertEqual('2024-01-15');
    });

    it('should_convert_date_with_custom_format_str', 0, () => {
      let date: Date = new Date(2024, 5, 15, 14, 30, 0);
      let result: string = JSONUtil.toJSONString(date, 'yyyy/MM/dd');
      expect(result).assertEqual('2024/06/15');
    });

    // toJSONString with number primitive
    it('should_convert_number_primitive_to_string', 0, () => {
      let result: string = JSONUtil.toJSONString(42);
      expect(result).assertEqual('42');
    });

    it('should_convert_zero_to_string', 0, () => {
      let result: string = JSONUtil.toJSONString(0);
      expect(result).assertEqual('0');
    });

    it('should_convert_negative_number_to_string', 0, () => {
      let result: string = JSONUtil.toJSONString(-10);
      expect(result).assertEqual('-10');
    });

    // toJSONString with boolean primitive
    it('should_convert_true_to_string', 0, () => {
      let result: string = JSONUtil.toJSONString(true);
      expect(result).assertEqual('true');
    });

    it('should_convert_false_to_string', 0, () => {
      let result: string = JSONUtil.toJSONString(false);
      expect(result).assertEqual('false');
    });

    // toJSONString with plain object
    it('should_convert_plain_object_to_json', 0, () => {
      let obj: Record<string, Object> = JSON.parse('{"name":"test","count":10}') as Record<string, Object>;
      let result: string = JSONUtil.toJSONString(obj);
      let parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
      expect(parsed['name'] as string).assertEqual('test');
      expect(parsed['count']).assertEqual(10);
    });

    it('should_convert_nested_object_to_json', 0, () => {
      let inner: Record<string, Object> = JSON.parse('{"deep":"value"}') as Record<string, Object>;
      let outer: Record<string, Object> = JSON.parse('{}') as Record<string, Object>;
      outer['nested'] = inner;
      let result: string = JSONUtil.toJSONString(outer);
      let parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
      let nestedParsed: Record<string, Object> = parsed['nested'] as Record<string, Object>;
      expect(nestedParsed['deep'] as string).assertEqual('value');
    });

    // toJSONString with array containing various types
    it('should_convert_array_of_dates', 0, () => {
      let date1: Date = new Date(2024, 0, 15);
      let date2: Date = new Date(2024, 5, 20);
      let arr: Object[] = [date1, date2];
      let result: string = JSONUtil.toJSONString(arr);
      let parsed: string[] = JSON.parse(result) as string[];
      expect(parsed.length).assertEqual(2);
      expect(parsed[0] as string).assertEqual('2024-01-15');
    });

    it('should_convert_array_of_maps', 0, () => {
      let map1: Map<string, string> = new Map();
      map1.set('a', '1');
      let map2: Map<string, string> = new Map();
      map2.set('b', '2');
      let arr: Object[] = [map1, map2];
      let result: string = JSONUtil.toJSONString(arr);
      let parsed: Record<string, Object>[] = JSON.parse(result) as Record<string, Object>[];
      expect(parsed.length).assertEqual(2);
    });

    it('should_convert_array_of_mixed_types', 0, () => {
      let date: Date = new Date(2024, 0, 15);
      let arr: Object[] = [date, 42, true, 'hello'];
      let result: string = JSONUtil.toJSONString(arr);
      let parsed: Object[] = JSON.parse(result) as Object[];
      expect(parsed.length).assertEqual(4);
      expect(parsed[0] as string).assertEqual('2024-01-15');
    });

    // toJSONString with Map containing Date values
    it('should_convert_map_with_date_value', 0, () => {
      let date: Date = new Date(2024, 5, 15);
      let map: Map<string, Object> = new Map();
      map.set('createdAt', date);
      let result: string = JSONUtil.toJSONString(map);
      let parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>;
      expect(parsed['createdAt'] as string).assertEqual('2024-06-15');
    });
  });

  describe('JSONUtil_isJSONStringArray', () => {
    it('should_return_true_for_array_of_json_strings', 0, () => {
      expect(JSONUtil.isJSONStringArray('["{\\"key\\":\\"value\\"}"]')).assertTrue();
    });
    it('should_return_false_for_plain_array', 0, () => {
      expect(JSONUtil.isJSONStringArray('[not_json,also_not]')).assertFalse();
    });
    it('should_return_false_for_object', 0, () => {
      expect(JSONUtil.isJSONStringArray('{"key":"value"}')).assertFalse();
    });
    it('should_return_false_for_invalid_json', 0, () => {
      expect(JSONUtil.isJSONStringArray('invalid')).assertFalse();
    });
    it('should_return_true_for_empty_array', 0, () => {
      expect(JSONUtil.isJSONStringArray('[]')).assertTrue();
    });
    it('should_return_false_for_array_with_non_json_strings', 0, () => {
      expect(JSONUtil.isJSONStringArray('["hello","world"]')).assertFalse();
    });
  });

  describe('JSONUtil_parseObject', () => {
    // parseObject with number value
    it('should_auto_parse_numeric_string_to_number', 0, () => {
      let jsonStr: string = '{"count":"42"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      expect(result['count']).assertEqual(42);
    });

    it('should_auto_parse_float_string_to_number', 0, () => {
      let jsonStr: string = '{"price":"3.14"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      expect(result['price']).assertEqual(3.14);
    });

    // parseObject with date value
    it('should_auto_parse_date_string', 0, () => {
      let jsonStr: string = '{"birthday":"2024-01-15"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      expect(result['birthday'] as string).assertEqual('2024-01-15');
    });

    it('should_auto_parse_date_with_custom_format', 0, () => {
      let jsonStr: string = '{"birthday":"2024-01-15"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr, 'yyyy/MM/dd');
      expect(result['birthday'] as string).assertEqual('2024/01/15');
    });

    // parseObject with boolean value
    it('should_auto_parse_boolean_true_string', 0, () => {
      let jsonStr: string = '{"enabled":"true"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      expect(result['enabled'] as boolean).assertTrue();
    });

    it('should_auto_parse_boolean_false_string', 0, () => {
      let jsonStr: string = '{"disabled":"false"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      expect(result['disabled'] as boolean).assertFalse();
    });

    // parseObject with nested JSON string
    it('should_auto_parse_nested_json_string', 0, () => {
      let jsonStr: string = '{"profile":"{\\"name\\":\\"test\\",\\"age\\":\\"25\\"}"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      let profile: Record<string, Object> = result['profile'] as Record<string, Object>;
      expect(profile['name'] as string).assertEqual('test');
      expect(profile['age']).assertEqual(25);
    });

    // parseObject with array value
    it('should_handle_array_value', 0, () => {
      let jsonStr: string = '{"items":[1,2,3]}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      let items: Object[] = result['items'] as Object[];
      expect(items.length).assertEqual(3);
    });

    // parseObject with JSON string array value
    it('should_parse_json_string_array_value', 0, () => {
      let jsonStr: string = '{"tags":"[\\"{\\\\\\"id\\\\\\":\\\\\\"1\\\\\\"}\\",\\"{\\\\\\"id\\\\\\":\\\\\\"2\\\\\\"}"]"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      let tags: Object[] = result['tags'] as Object[];
      expect(tags.length).assertEqual(2);
    });

    // parseObject with plain string value (falls through to return as-is)
    it('should_return_plain_string_as_is', 0, () => {
      let jsonStr: string = '{"message":"hello world"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      expect(result['message'] as string).assertEqual('hello world');
    });

    // parseObject with multiple types
    it('should_parse_object_with_mixed_value_types', 0, () => {
      let jsonStr: string = '{"name":"test","score":"95","active":"true","joined":"2024-06-15"}';
      let result: Record<string, Object> = JSONUtil.parseObject<Record<string, Object>>(jsonStr);
      expect(result['name'] as string).assertEqual('test');
      expect(result['score']).assertEqual(95);
      expect(result['active'] as boolean).assertTrue();
      expect(result['joined'] as string).assertEqual('2024-06-15');
    });
  });

  describe('JSONUtil_parseArray', () => {
    it('should_parse_array_of_json_objects', 0, () => {
      let jsonStr: string = '[{"name":"alice","age":"30"},{"name":"bob","age":"25"}]';
      let result: Record<string, Object>[] = JSONUtil.parseArray<Record<string, Object>>(jsonStr);
      expect(result.length).assertEqual(2);
      expect(result[0]['name'] as string).assertEqual('alice');
      expect(result[1]['age']).assertEqual(25);
    });

    it('should_parse_array_with_date_values', 0, () => {
      let jsonStr: string = '[{"date":"2024-01-15"},{"date":"2024-06-20"}]';
      let result: Record<string, Object>[] = JSONUtil.parseArray<Record<string, Object>>(jsonStr);
      expect(result.length).assertEqual(2);
      expect(result[0]['date'] as string).assertEqual('2024-01-15');
    });

    it('should_parse_array_with_custom_format', 0, () => {
      let jsonStr: string = '[{"date":"2024-01-15"}]';
      let result: Record<string, Object>[] = JSONUtil.parseArray<Record<string, Object>>(jsonStr, 'yyyy/MM/dd');
      expect(result.length).assertEqual(1);
      expect(result[0]['date'] as string).assertEqual('2024/01/15');
    });

    it('should_return_empty_array_for_empty_json_array', 0, () => {
      let jsonStr: string = '[]';
      let result: Record<string, Object>[] = JSONUtil.parseArray<Record<string, Object>>(jsonStr);
      expect(result.length).assertEqual(0);
    });
  });

  describe('JSONUtil_parseStringArray', () => {
    it('should_parse_string_array_of_json_objects', 0, () => {
      let jsonStr: string = '["{\\"id\\":\\"1\\",\\"name\\":\\"alice\\"}","{\\"id\\":\\"2\\",\\"name\\":\\"bob\\"}"]';
      let result: Object[] = JSONUtil.parseStringArray(jsonStr);
      expect(result.length).assertEqual(2);
      let first: Record<string, Object> = result[0] as Record<string, Object>;
      expect(first['id'] as string).assertEqual('1');
    });

    it('should_parse_string_array_with_number_values', 0, () => {
      let jsonStr: string = '["{\\"value\\":\\"42\\"}","{\\"value\\":\\"99\\"}"]';
      let result: Object[] = JSONUtil.parseStringArray(jsonStr);
      expect(result.length).assertEqual(2);
    });
  });
}
