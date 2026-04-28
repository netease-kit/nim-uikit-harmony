/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { TextLinkifyUtils, LinkInfo, LinkType } from './TextLinkifyUtils'

/**
 * 文本节点类型
 */
export enum TextNodeType {
  /** 普通文本 */
  PLAIN = 'plain',
  /** 链接（邮箱/URL/电话） */
  LINK = 'link',
  /** @提及 */
  AIT = 'ait'
}

/**
 * 文本节点
 */
export interface TextNode {
  type: TextNodeType
  text: string
  linkInfo?: LinkInfo  // 当 type === LINK 时有值
  isAit?: boolean      // 当 type === AIT 时有值
}

/**
 * 解析文本节点，将普通文本中的链接提取出来
 * 此方法用于在 @提及 处理之后，对剩余的普通文本进行链接识别
 *
 * @param text 要解析的文本
 * @param isAit 是否为 @提及文本
 * @returns 解析后的节点数组
 */
export function parseTextWithLinks(text: string, isAit: boolean = false): TextNode[] {
  // 如果是 @提及文本，不进行链接识别
  if (isAit) {
    return [{
      type: TextNodeType.AIT,
      text: text,
      isAit: true
    }]
  }

  // 提取链接
  const links = TextLinkifyUtils.extractLinks(text)
  if (links.length === 0) {
    return [{
      type: TextNodeType.PLAIN,
      text: text
    }]
  }

  const nodes: TextNode[] = []
  let lastIndex = 0

  for (const link of links) {
    // 添加链接前的普通文本
    if (link.start > lastIndex) {
      nodes.push({
        type: TextNodeType.PLAIN,
        text: text.substring(lastIndex, link.start)
      })
    }
    // 添加链接节点
    nodes.push({
      type: TextNodeType.LINK,
      text: link.text,
      linkInfo: link
    })
    lastIndex = link.end
  }

  // 添加最后一段普通文本
  if (lastIndex < text.length) {
    nodes.push({
      type: TextNodeType.PLAIN,
      text: text.substring(lastIndex)
    })
  }

  return nodes
}

// 重新导出以便使用
export { LinkInfo, LinkType, TextLinkifyUtils }
