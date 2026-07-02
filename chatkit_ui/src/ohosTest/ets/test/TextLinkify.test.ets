/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import { TextLinkifyUtils, LinkType, LinkInfo } from '../../../main/ets/utils/TextLinkifyUtils';

/**
 * TextLinkifyUtils 单元测试
 * 覆盖冒烟测试用例中的「文本自动识别」功能模块
 *
 * 验证范围：
 * - 邮箱识别
 * - URL 识别 (http/https/ftp/rtsp/www)
 * - 电话号码识别 (国内/国际格式)
 * - 混合内容识别
 * - 边界情况
 */
export default function textLinkifyTest() {

  // ==================== 邮箱识别测试 ====================
  describe('TextLinkify_Email_Recognition', () => {
    it('should_recognize_simple_email', 0, () => {
      const text = '联系我 test@example.com 谢谢';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.EMAIL);
      expect(links[0].text).assertEqual('test@example.com');
      expect(links[0].url).assertEqual('mailto:test@example.com');
    });

    it('should_recognize_email_with_subdomain', 0, () => {
      const text = 'Email: user@mail.example.com';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('user@mail.example.com');
    });

    it('should_recognize_email_with_plus_sign', 0, () => {
      const text = '邮箱是 test+tag@gmail.com';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('test+tag@gmail.com');
    });

    it('should_recognize_email_with_dots', 0, () => {
      const text = 'first.last@company.co.uk';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('first.last@company.co.uk');
    });

    it('should_verify_isEmail_returns_true_for_valid_email', 0, () => {
      expect(TextLinkifyUtils.isEmail('user@example.com')).assertTrue();
    });

    it('should_verify_isEmail_returns_false_for_invalid_email', 0, () => {
      expect(TextLinkifyUtils.isEmail('not-an-email')).assertFalse();
      expect(TextLinkifyUtils.isEmail('missing@domain')).assertFalse();
    });

    // 补充: isEmail 边界情况 — 带有额外文本
    it('should_verify_isEmail_returns_false_with_extra_text', 0, () => {
      expect(TextLinkifyUtils.isEmail('hello test@example.com world')).assertFalse();
      expect(TextLinkifyUtils.isEmail('prefix test@example.com')).assertFalse();
    });

    // 补充: isEmail 边界情况 — 空字符串
    it('should_verify_isEmail_returns_false_for_empty_string', 0, () => {
      expect(TextLinkifyUtils.isEmail('')).assertFalse();
    });
  });

  // ==================== URL 识别测试 ====================
  describe('TextLinkify_URL_Recognition', () => {
    // P0: 链接蓝色高亮显示的前提 - URL 能被正确识别
    it('should_recognize_http_url', 0, () => {
      const text = '访问 http://example.com 获取更多信息';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.URL);
      expect(links[0].text).assertEqual('http://example.com');
    });

    it('should_recognize_https_url', 0, () => {
      const text = '安全链接 https://secure.example.com/path';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('https://secure.example.com/path');
    });

    // Spec 要求: 支持 ftp 协议
    it('should_recognize_ftp_url', 0, () => {
      const text = '下载地址 ftp://files.example.com/download';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.URL);
      expect(links[0].text).assertEqual('ftp://files.example.com/download');
    });

    // Spec 要求: 支持 rtsp 协议
    it('should_recognize_rtsp_url', 0, () => {
      const text = '流媒体 rtsp://stream.example.com/live';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.URL);
      expect(links[0].text).assertEqual('rtsp://stream.example.com/live');
    });

    // Spec 要求: www 开头的 URL
    it('should_recognize_www_url', 0, () => {
      const text = '网站 www.example.com 很不错';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('www.example.com');
    });

    // Spec 要求: 带端口号的 URL
    it('should_recognize_url_with_port', 0, () => {
      const text = '服务器 http://example.com:8080/api';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('http://example.com:8080/api');
    });

    // Spec 要求: 带查询参数的 URL
    it('should_recognize_url_with_query_params', 0, () => {
      const text = '搜索 https://example.com/search?q=test&page=1';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('https://example.com/search?q=test&page=1');
    });

    // Spec 要求: 带锚点的 URL
    it('should_recognize_url_with_anchor', 0, () => {
      const text = '跳转到 https://example.com/page#section';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('https://example.com/page#section');
    });

    // Spec 要求: IP 地址 URL
    it('should_recognize_ip_address_url', 0, () => {
      const text = '管理页面 http://192.168.1.1/admin';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertEqual('http://192.168.1.1/admin');
    });

    it('should_verify_isUrl_returns_true_for_valid_url', 0, () => {
      expect(TextLinkifyUtils.isUrl('https://example.com')).assertTrue();
      expect(TextLinkifyUtils.isUrl('http://test.org/path')).assertTrue();
      expect(TextLinkifyUtils.isUrl('www.google.com')).assertTrue();
    });

    it('should_verify_isUrl_returns_false_for_invalid_url', 0, () => {
      expect(TextLinkifyUtils.isUrl('not a url')).assertFalse();
      expect(TextLinkifyUtils.isUrl('example.com')).assertFalse(); // 没有协议或 www
    });

    // 补充: isUrl 边界情况 — 空字符串
    it('should_verify_isUrl_returns_false_for_empty_string', 0, () => {
      expect(TextLinkifyUtils.isUrl('')).assertFalse();
    });

    // 补充: isUrl 边界情况 — www 开头无协议
    it('should_verify_isUrl_returns_true_for_www_prefix', 0, () => {
      expect(TextLinkifyUtils.isUrl('www.example.com')).assertTrue();
    });

    // 补充: isUrl 边界情况 — 仅域名无协议无 www
    it('should_verify_isUrl_returns_false_for_bare_domain', 0, () => {
      expect(TextLinkifyUtils.isUrl('example.com')).assertFalse();
    });
  });

  // ==================== 电话号码识别测试 ====================
  describe('TextLinkify_Phone_Recognition', () => {
    // P0: 电话号码蓝色高亮显示的前提
    it('should_recognize_china_mobile_number', 0, () => {
      const text = '电话 13812345678 联系';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.PHONE);
      expect(links[0].text).assertEqual('13812345678');
      expect(links[0].url).assertEqual('tel:13812345678');
    });

    // Spec 要求: 国际格式号码 +86
    it('should_recognize_international_phone_with_plus86', 0, () => {
      const text = '请拨打 +86-138-1234-5678';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.PHONE);
      // 验证 tel: 格式去除了分隔符
      expect(links[0].url).assertContain('tel:');
    });

    // Spec 要求: 国际格式号码 +1
    it('should_recognize_us_phone_number', 0, () => {
      const text = 'Call +1-555-123-4567';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.PHONE);
    });

    // Spec 要求: 固定电话 (区号-号码)
    it('should_recognize_landline_with_area_code', 0, () => {
      const text = '座机 021-12345678';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.PHONE);
      expect(links[0].url).assertEqual('tel:02112345678');
    });

    it('should_recognize_shenzhen_landline', 0, () => {
      const text = '深圳办公室 0755-12345678';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].type).assertEqual(LinkType.PHONE);
    });

    it('should_not_recognize_too_short_number', 0, () => {
      const text = '号码 12345 太短';
      const links = TextLinkifyUtils.extractLinks(text);
      // 应该过滤掉长度小于 7 的数字
      const phoneLinks = links.filter(l => l.type === LinkType.PHONE);
      expect(phoneLinks.length).assertEqual(0);
    });

    it('should_verify_isPhone_returns_true_for_valid_phone', 0, () => {
      expect(TextLinkifyUtils.isPhone('13812345678')).assertTrue();
      expect(TextLinkifyUtils.isPhone('021-12345678')).assertTrue();
    });

    it('should_verify_isPhone_returns_false_for_short_number', 0, () => {
      expect(TextLinkifyUtils.isPhone('12345')).assertFalse();
    });

    // 补充: isPhone 边界情况 — 带空格和短横线的格式化号码
    it('should_verify_isPhone_returns_true_for_formatted_phone_with_spaces', 0, () => {
      expect(TextLinkifyUtils.isPhone('138 1234 5678')).assertTrue();
    });

    // 补充: isPhone 边界情况 — +86 国际格式
    it('should_verify_isPhone_returns_true_for_plus86_format', 0, () => {
      expect(TextLinkifyUtils.isPhone('+86-138-1234-5678')).assertTrue();
    });

    // 补充: isPhone 边界情况 — +1 国际格式
    it('should_verify_isPhone_returns_true_for_plus1_format', 0, () => {
      expect(TextLinkifyUtils.isPhone('+1-555-123-4567')).assertTrue();
    });
  });

  // ==================== 混合内容识别测试 ====================
  describe('TextLinkify_Mixed_Content', () => {
    // Spec 要求: 混合内容识别
    it('should_recognize_multiple_link_types_in_same_text', 0, () => {
      const text = '联系方式: 邮箱 test@example.com, 电话 13812345678, 网站 https://example.com';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(3);

      // 验证按位置排序
      expect(links[0].type).assertEqual(LinkType.EMAIL);
      expect(links[1].type).assertEqual(LinkType.PHONE);
      expect(links[2].type).assertEqual(LinkType.URL);
    });

    it('should_recognize_multiple_urls', 0, () => {
      const text = '参考 https://a.com 和 https://b.com';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(2);
      expect(links[0].text).assertEqual('https://a.com');
      expect(links[1].text).assertEqual('https://b.com');
    });

    it('should_recognize_multiple_phones', 0, () => {
      const text = '客服 13800138000 或 13900139000';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(2);
      expect(links[0].type).assertEqual(LinkType.PHONE);
      expect(links[1].type).assertEqual(LinkType.PHONE);
    });
  });

  // ==================== 无链接文本测试 ====================
  describe('TextLinkify_No_Links', () => {
    // Spec 要求: 无链接文本默认样式
    it('should_return_empty_array_for_plain_text', 0, () => {
      const text = '这是一段普通文本，没有任何链接';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(0);
    });

    it('should_return_empty_array_for_empty_string', 0, () => {
      const links = TextLinkifyUtils.extractLinks('');
      expect(links.length).assertEqual(0);
    });

    it('should_verify_hasLinks_returns_false_for_plain_text', 0, () => {
      expect(TextLinkifyUtils.hasLinks('普通文本')).assertFalse();
    });

    it('should_verify_hasLinks_returns_true_for_text_with_link', 0, () => {
      expect(TextLinkifyUtils.hasLinks('访问 https://example.com')).assertTrue();
      expect(TextLinkifyUtils.hasLinks('邮箱 test@example.com')).assertTrue();
      expect(TextLinkifyUtils.hasLinks('电话 13812345678')).assertTrue();
    });

    // 补充: hasLinks 边界情况 — 仅含电话号码
    it('should_verify_hasLinks_returns_true_for_phone_only', 0, () => {
      expect(TextLinkifyUtils.hasLinks('13812345678')).assertTrue();
    });

    // 补充: hasLinks 边界情况 — 仅含邮箱
    it('should_verify_hasLinks_returns_true_for_email_only', 0, () => {
      expect(TextLinkifyUtils.hasLinks('test@example.com')).assertTrue();
    });
  });

  // ==================== 边界情况测试 ====================
  describe('TextLinkify_Edge_Cases', () => {
    it('should_handle_link_at_start_of_text', 0, () => {
      const text = 'https://example.com 是一个网站';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].start).assertEqual(0);
    });

    it('should_handle_link_at_end_of_text', 0, () => {
      const text = '访问 https://example.com';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].end).assertEqual(text.length);
    });

    it('should_handle_consecutive_links', 0, () => {
      const text = 'https://a.com https://b.com';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(2);
    });

    it('should_record_correct_start_and_end_positions', 0, () => {
      const text = 'Hello test@example.com World';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].start).assertEqual(6); // 'Hello ' 长度为 6
      expect(links[0].end).assertEqual(22); // 6 + 'test@example.com'.length = 22
    });

    it('should_remove_overlapping_links', 0, () => {
      // 如果有重叠的识别结果，应该保留第一个
      const text = 'test@123456789.com'; // 可能同时匹配邮箱和电话
      const links = TextLinkifyUtils.extractLinks(text);
      // 由于邮箱模式先匹配，电话号码应该被过滤掉（因为重叠）
      expect(links.length).assertLargerOrEqual(1);
    });

    // 补充: removeOverlappingLinks — 数字前缀的邮箱导致邮箱与号码重叠
    it('should_remove_overlapping_email_and_phone_from_digit_prefix_email', 0, () => {
      // "13812345678@test.com" 中 "13812345678" 同时匹配电话模式
      // "13812345678@test.com" 匹配邮箱模式
      // 两者起始位置重叠，应只保留一个
      const text = '13812345678@test.com';
      const links = TextLinkifyUtils.extractLinks(text);
      // 重叠链接被去重后应只有 1 个有效链接
      expect(links.length).assertEqual(1);
    });
  });

  // ==================== 特殊字符测试 ====================
  describe('TextLinkify_Special_Characters', () => {
    it('should_handle_url_with_special_chars_in_path', 0, () => {
      const text = '链接 https://example.com/path~file';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
    });

    it('should_handle_url_with_parentheses', 0, () => {
      const text = '维基百科 https://example.com/wiki/(test)';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
      expect(links[0].text).assertContain('(test)');
    });

    it('should_handle_url_with_percent_encoding', 0, () => {
      const text = '搜索 https://example.com/search?q=%E6%B5%8B%E8%AF%95';
      const links = TextLinkifyUtils.extractLinks(text);
      expect(links.length).assertEqual(1);
    });
  });

  // ==================== findLinkAtStart 测试 ====================
  describe('TextLinkify_findLinkAtStart', () => {

    it('should_return_URL_LinkInfo_when_http_url_at_start', 0, () => {
      const result = TextLinkifyUtils.findLinkAtStart('http://example.com 更多文本');
      expect(result).assertNotNull();
      if (result) {
        expect(result.type).assertEqual(LinkType.URL);
        expect(result.text).assertEqual('http://example.com');
        expect(result.url).assertEqual('http://example.com');
        expect(result.start).assertEqual(0);
      }
    });

    it('should_return_URL_LinkInfo_when_https_url_at_start', 0, () => {
      const result = TextLinkifyUtils.findLinkAtStart('https://secure.example.com/path');
      expect(result).assertNotNull();
      if (result) {
        expect(result.type).assertEqual(LinkType.URL);
        expect(result.text).assertEqual('https://secure.example.com/path');
        expect(result.start).assertEqual(0);
      }
    });

    it('should_return_URL_LinkInfo_with_https_prepended_when_www_prefix_at_start', 0, () => {
      const result = TextLinkifyUtils.findLinkAtStart('www.example.com extra');
      expect(result).assertNotNull();
      if (result) {
        expect(result.type).assertEqual(LinkType.URL);
        expect(result.text).assertEqual('www.example.com');
        // www 开头的链接自动补全 https://
        expect(result.url).assertEqual('https://www.example.com');
        expect(result.start).assertEqual(0);
      }
    });

    it('should_return_EMAIL_LinkInfo_when_email_at_start', 0, () => {
      const result = TextLinkifyUtils.findLinkAtStart('test@example.com 附加内容');
      expect(result).assertNotNull();
      if (result) {
        expect(result.type).assertEqual(LinkType.EMAIL);
        expect(result.text).assertEqual('test@example.com');
        expect(result.url).assertEqual('mailto:test@example.com');
        expect(result.start).assertEqual(0);
      }
    });

    it('should_return_PHONE_LinkInfo_when_phone_at_start', 0, () => {
      const result = TextLinkifyUtils.findLinkAtStart('13812345678 附加内容');
      expect(result).assertNotNull();
      if (result) {
        expect(result.type).assertEqual(LinkType.PHONE);
        expect(result.text).assertEqual('13812345678');
        expect(result.url).assertEqual('tel:13812345678');
        expect(result.start).assertEqual(0);
      }
    });

    it('should_return_undefined_when_no_link_present', 0, () => {
      const result = TextLinkifyUtils.findLinkAtStart('这是一段普通文本');
      expect(result).assertUndefined();
    });

    it('should_return_undefined_when_text_before_link', 0, () => {
      // 链接前面有文本，位置不是 0
      const result = TextLinkifyUtils.findLinkAtStart('你好 http://example.com');
      expect(result).assertUndefined();
    });

    it('should_return_undefined_for_empty_string', 0, () => {
      const result = TextLinkifyUtils.findLinkAtStart('');
      expect(result).assertUndefined();
    });

    it('should_return_URL_before_email_priority_when_both_at_start', 0, () => {
      // 源码中先检查 URL，再检查邮箱。如果 URL 模式匹配到位置 0，直接返回 URL 结果
      // www.example@test.com 以 www. 开头，URL 模式会匹配
      const result = TextLinkifyUtils.findLinkAtStart('www.example@test.com');
      expect(result).assertNotNull();
      if (result) {
        // URL 模式优先匹配（以 www. 开头），返回 URL 类型
        expect(result.type).assertEqual(LinkType.URL);
      }
    });
  });

  // ==================== findFirstLinkPosition 测试 ====================
  describe('TextLinkify_findFirstLinkPosition', () => {

    it('should_return_position_of_url_in_text', 0, () => {
      const position = TextLinkifyUtils.findFirstLinkPosition('访问 http://example.com 获取信息');
      // '访问 ' 长度为 3
      expect(position).assertEqual(3);
    });

    it('should_return_position_of_email_in_text', 0, () => {
      const position = TextLinkifyUtils.findFirstLinkPosition('邮箱 test@example.com 联系');
      // '邮箱 ' 长度为 3
      expect(position).assertEqual(3);
    });

    it('should_return_position_of_phone_in_text', 0, () => {
      const position = TextLinkifyUtils.findFirstLinkPosition('电话 13812345678 拨号');
      // '电话 ' 长度为 3
      expect(position).assertEqual(3);
    });

    it('should_return_earliest_position_when_multiple_links', 0, () => {
      // email 在位置 3, phone 在位置 24, url 在位置 7
      // 最早的是 email 在位置 3
      const position = TextLinkifyUtils.findFirstLinkPosition('Hi test@example.com 访问 https://a.com 电话 13812345678');
      // 'Hi ' 长度为 3
      expect(position).assertEqual(3);
    });

    it('should_return_position_0_when_link_is_at_start', 0, () => {
      const position = TextLinkifyUtils.findFirstLinkPosition('https://example.com 后跟文本');
      expect(position).assertEqual(0);
    });

    it('should_return_undefined_when_no_links', 0, () => {
      const position = TextLinkifyUtils.findFirstLinkPosition('这是一段普通文本');
      expect(position).assertUndefined();
    });

    it('should_return_undefined_for_empty_string', 0, () => {
      const position = TextLinkifyUtils.findFirstLinkPosition('');
      expect(position).assertUndefined();
    });

    it('should_skip_phone_too_short_and_return_email_position', 0, () => {
      // "1234567" 有 7 位数字，会被过滤掉（cleaned.length < 8）
      // 邮箱 "test@example.com" 在位置 8
      // findFirstLinkPosition 应返回邮箱位置 8，而非过滤掉的短号码位置 0
      const position = TextLinkifyUtils.findFirstLinkPosition('1234567 test@example.com');
      // 位置 8: '1234567 ' 长度为 8
      expect(position).assertEqual(8);
    });
  });
}
