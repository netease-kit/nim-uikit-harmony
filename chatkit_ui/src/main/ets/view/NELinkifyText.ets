/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { common } from '@kit.AbilityKit'
import { TextLinkifyUtils, LinkInfo, LinkType } from '../utils/TextLinkifyUtils'
import { LinkClickUtils } from '../utils/LinkClickUtils'

/**
 * 文本片段类型
 */
interface TextSegment {
  text: string
  isLink: boolean
  linkInfo?: LinkInfo
}

/**
 * NELinkifyText 组件参数
 */
export interface NELinkifyTextParams {
  /** 文本内容 */
  text: string
  /** 字体大小 (默认 14) */
  fontSize?: number
  /** 普通文本颜色 (默认 #333333) */
  fontColor?: ResourceColor
  /** 链接颜色 (默认 #337EFF) */
  linkColor?: ResourceColor
  /** 最大行数 (可选) */
  maxLines?: number
  /** 文本对齐方式 */
  textAlign?: TextAlign
  /** 自定义链接点击回调（返回 true 表示已处理，不执行默认行为） */
  onLinkClick?: (linkInfo: LinkInfo) => boolean
}

/**
 * 富文本链接组件
 * 自动识别文本中的邮箱、URL 和电话号码，并渲染为可点击链接
 * 对齐 Android chatkit-ui TextLinkifyUtils 功能
 */
@Component
export struct NELinkifyText {
  @Require @Prop params: NELinkifyTextParams
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  /**
   * 将文本分割为普通文本和链接片段
   */
  private getTextSegments(): TextSegment[] {
    const text = this.params.text
    if (!text) {
      return []
    }

    const links = TextLinkifyUtils.extractLinks(text)
    if (links.length === 0) {
      return [{ text: text, isLink: false }]
    }

    const segments: TextSegment[] = []
    let lastIndex = 0

    for (const link of links) {
      // 添加链接前的普通文本
      if (link.start > lastIndex) {
        segments.push({
          text: text.substring(lastIndex, link.start),
          isLink: false
        })
      }
      // 添加链接文本
      segments.push({
        text: link.text,
        isLink: true,
        linkInfo: link
      })
      lastIndex = link.end
    }

    // 添加最后一段普通文本
    if (lastIndex < text.length) {
      segments.push({
        text: text.substring(lastIndex),
        isLink: false
      })
    }

    return segments
  }

  /**
   * 处理链接点击
   */
  private handleLinkClick(linkInfo: LinkInfo): void {
    // 先调用自定义回调
    if (this.params.onLinkClick && this.params.onLinkClick(linkInfo)) {
      return
    }
    // 执行默认行为
    LinkClickUtils.handleLinkClick(this.context, linkInfo)
  }

  build() {
    Text() {
      ForEach(this.getTextSegments(), (segment: TextSegment, index: number) => {
        if (segment.isLink && segment.linkInfo) {
          Span(segment.text)
            .fontColor(this.params.linkColor ?? '#337EFF')
            .fontSize(this.params.fontSize ?? 14)
            .onClick(() => {
              if (segment.linkInfo) {
                this.handleLinkClick(segment.linkInfo)
              }
            })
        } else {
          Span(segment.text)
            .fontColor(this.params.fontColor ?? '#333333')
            .fontSize(this.params.fontSize ?? 14)
        }
      }, (segment: TextSegment, index: number) => `${index}_${segment.text}`)
    }
    .maxLines(this.params.maxLines)
    .textAlign(this.params.textAlign ?? TextAlign.Start)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}
