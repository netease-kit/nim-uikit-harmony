/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * 文本链接识别工具类
 * 支持识别消息文本中的邮箱、URL 和电话号码
 * 对齐 Android chatkit-ui TextLinkifyUtils.java
 */

// 邮箱正则表达式 (符合 RFC 5322 标准的简化版)
const EMAIL_PATTERN: RegExp = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g

// URL 正则表达式 (参考鸿蒙官方文档，支持 https://, http://, ftp://, rtsp://, www. 开头)
// 支持域名和 IP 地址
const URL_PATTERN: RegExp = /(https?:\/\/|ftp:\/\/|rtsp:\/\/|www\.)([a-zA-Z_0-9\-@]+(\.[a-zA-Z_0-9\-:]+)+|(\d{1,3}\.){3}\d{1,3}(:\d+)?)(\/[\(\)~#&\-=?\+\%/\.\w]*)?/g

// 电话号码正则表达式 (支持国际格式和中国手机号)
// 1. 中国手机号: 1[3-9]\d{9}
// 2. 国际格式: +区号-号码
// 3. 固话: 区号-号码
const PHONE_PATTERN: RegExp = /(\+\d{1,4}[-\s]?)?(\(?\d{2,4}\)?[-\s]?)?(\d{3,4}[-\s]?){1,3}\d{3,4}/g

// 链接类型
export enum LinkType {
  EMAIL = 'email',
  URL = 'url',
  PHONE = 'phone'
}

// 链接信息
export interface LinkInfo {
  type: LinkType
  text: string      // 匹配的原始文本
  url: string       // 完整的 URL（包含 scheme）
  start: number     // 起始位置
  end: number       // 结束位置
}

/**
 * 文本链接识别工具类
 */
export class TextLinkifyUtils {
  /**
   * 从文本中提取所有链接（邮箱、URL、电话）
   * @param text 待识别的文本
   * @returns 链接信息数组
   */
  static extractLinks(text: string): LinkInfo[] {
    const links: LinkInfo[] = []

    // 识别邮箱
    let match: RegExpExecArray | null
    EMAIL_PATTERN.lastIndex = 0
    while ((match = EMAIL_PATTERN.exec(text)) !== null) {
      links.push({
        type: LinkType.EMAIL,
        text: match[0],
        url: `mailto:${match[0]}`,
        start: match.index,
        end: match.index + match[0].length
      })
    }

    // 识别 URL
    URL_PATTERN.lastIndex = 0
    while ((match = URL_PATTERN.exec(text)) !== null) {
      links.push({
        type: LinkType.URL,
        text: match[0],
        url: match[0],
        start: match.index,
        end: match.index + match[0].length
      })
    }

    // 识别电话号码
    PHONE_PATTERN.lastIndex = 0
    while ((match = PHONE_PATTERN.exec(text)) !== null) {
      // 过滤掉太短的匹配（可能是误匹配，如订单号、验证码等）
      const cleaned = match[0].replace(/[\s-]/g, '')
      if (cleaned.length >= 8) {
        links.push({
          type: LinkType.PHONE,
          text: match[0],
          url: `tel:${cleaned}`,
          start: match.index,
          end: match.index + match[0].length
        })
      }
    }

    // 按位置排序，去除重叠
    links.sort((a, b) => a.start - b.start)
    return TextLinkifyUtils.removeOverlappingLinks(links)
  }

  /**
   * 去除重叠的链接（保留第一个）
   */
  private static removeOverlappingLinks(links: LinkInfo[]): LinkInfo[] {
    const result: LinkInfo[] = []
    let lastEnd = -1

    for (const link of links) {
      if (link.start >= lastEnd) {
        result.push(link)
        lastEnd = link.end
      }
    }

    return result
  }

  /**
   * 检查文本是否包含可识别的链接
   * @param text 待检查的文本
   * @returns 是否包含链接
   */
  static hasLinks(text: string): boolean {
    EMAIL_PATTERN.lastIndex = 0
    URL_PATTERN.lastIndex = 0
    PHONE_PATTERN.lastIndex = 0

    return EMAIL_PATTERN.test(text) ||
      URL_PATTERN.test(text) ||
      PHONE_PATTERN.test(text)
  }

  /**
   * 判断字符串是否为邮箱地址
   * @param text 待检查的文本
   * @returns 是否为邮箱
   */
  static isEmail(text: string): boolean {
    EMAIL_PATTERN.lastIndex = 0
    const match = EMAIL_PATTERN.exec(text)
    return match !== null && match[0] === text.trim()
  }

  /**
   * 判断字符串是否为 URL
   * @param text 待检查的文本
   * @returns 是否为 URL
   */
  static isUrl(text: string): boolean {
    URL_PATTERN.lastIndex = 0
    const match = URL_PATTERN.exec(text)
    return match !== null && match[0] === text.trim()
  }

  /**
   * 判断字符串是否为电话号码
   * @param text 待检查的文本
   * @returns 是否为电话
   */
  static isPhone(text: string): boolean {
    const cleaned = text.replace(/[\s-]/g, '')
    if (cleaned.length < 8) {
      return false
    }
    PHONE_PATTERN.lastIndex = 0
    const match = PHONE_PATTERN.exec(text)
    return match !== null && match[0].replace(/[\s-]/g, '') === cleaned
  }

  /**
   * 查找文本开头的第一个链接（用于 Markdown tokenizer 扩展）
   * @param text 待识别的文本
   * @returns 如果文本开头是链接则返回 LinkInfo，否则返回 undefined
   */
  static findLinkAtStart(text: string): LinkInfo | undefined {
    // 检查 URL
    URL_PATTERN.lastIndex = 0
    const urlMatch = URL_PATTERN.exec(text)
    if (urlMatch && urlMatch.index === 0) {
      const matchText = urlMatch[0]
      // 如果以 www. 开头，补全 https://
      const url = matchText.toLowerCase().startsWith('www.') ? `https://${matchText}` : matchText
      return {
        type: LinkType.URL,
        text: matchText,
        url: url,
        start: 0,
        end: matchText.length
      }
    }

    // 检查邮箱
    EMAIL_PATTERN.lastIndex = 0
    const emailMatch = EMAIL_PATTERN.exec(text)
    if (emailMatch && emailMatch.index === 0) {
      const matchText = emailMatch[0]
      return {
        type: LinkType.EMAIL,
        text: matchText,
        url: `mailto:${matchText}`,
        start: 0,
        end: matchText.length
      }
    }

    // 检查电话号码
    PHONE_PATTERN.lastIndex = 0
    const phoneMatch = PHONE_PATTERN.exec(text)
    if (phoneMatch && phoneMatch.index === 0) {
      const matchText = phoneMatch[0]
      const cleaned = matchText.replace(/[\s\-\(\)]/g, '')
      // 验证长度
      if (cleaned.length >= 8) {
        return {
          type: LinkType.PHONE,
          text: matchText,
          url: `tel:${cleaned}`,
          start: 0,
          end: matchText.length
        }
      }
    }

    return undefined
  }

  /**
   * 查找文本中第一个链接的起始位置（用于 Markdown tokenizer 扩展的 start 函数）
   * @param text 待识别的文本
   * @returns 第一个链接的起始位置，如果没有链接则返回 undefined
   */
  static findFirstLinkPosition(text: string): number | undefined {
    const positions: number[] = []

    // 查找 URL
    URL_PATTERN.lastIndex = 0
    const urlMatch = URL_PATTERN.exec(text)
    if (urlMatch?.index !== undefined) {
      positions.push(urlMatch.index)
    }

    // 查找邮箱
    EMAIL_PATTERN.lastIndex = 0
    const emailMatch = EMAIL_PATTERN.exec(text)
    if (emailMatch?.index !== undefined) {
      positions.push(emailMatch.index)
    }

    // 查找电话号码
    PHONE_PATTERN.lastIndex = 0
    const phoneMatch = PHONE_PATTERN.exec(text)
    if (phoneMatch?.index !== undefined) {
      const cleaned = phoneMatch[0].replace(/[\s\-\(\)]/g, '')
      if (cleaned.length >= 8) {
        positions.push(phoneMatch.index)
      }
    }

    if (positions.length > 0) {
      return Math.min(...positions)
    }
    return undefined
  }
}
