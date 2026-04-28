/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { TokenizerExtension, Tokens, Token } from '@nimkit/markdown'
import { TextLinkifyUtils } from './TextLinkifyUtils'

/**
 * Markdown Linkify 扩展
 *
 * 将 chatkit_ui 的 linkify 解析能力集成到 Markdown 解析器中。
 * 在 Markdown 解析阶段识别 URL、电话号码、邮箱，并转换为 link token。
 *
 * 使用方法：
 * 1. 导入此模块：import { linkifyExtension } from './utils/MarkdownLinkifyExtension'
 * 2. 注册到 marked：markConfig.addPlugin([linkifyExtension])
 *
 * 原理：
 * - 使用 marked 的 tokenizer 扩展机制
 * - 在 inline 级别添加一个 tokenizer，复用 TextLinkifyUtils 识别 URL/电话/邮箱
 * - 识别到的内容会被转换为 link token，由 Markdown 组件渲染为可点击链接
 */

/**
 * 创建 Text Token
 */
function createTextToken(text: string): Tokens.Text {
  const token: Tokens.Text = {
    type: 'text',
    raw: text,
    text: text
  }
  return token
}

/**
 * 创建 Link Token
 */
function createLinkToken(raw: string, href: string, text: string): Tokens.Link {
  const textToken = createTextToken(text)
  const tokens: Token[] = [textToken]
  const token: Tokens.Link = {
    type: 'link',
    raw: raw,
    href: href,
    title: '',
    text: text,
    tokens: tokens
  }
  return token
}

/**
 * Linkify Tokenizer 扩展
 * 识别文本中的 URL、邮箱、电话号码，转换为 link token
 */
export const linkifyExtension: TokenizerExtension = {
  name: 'linkify',
  level: 'inline',

  // start 函数：返回第一个可能匹配的位置
  start(src: string): number | void {
    return TextLinkifyUtils.findFirstLinkPosition(src)
  },

  // tokenizer 函数：解析并返回 token
  tokenizer(src: string): Tokens.Link | undefined {
    const linkInfo = TextLinkifyUtils.findLinkAtStart(src)
    if (linkInfo) {
      return createLinkToken(linkInfo.text, linkInfo.url, linkInfo.text)
    }
    return undefined
  }
}
