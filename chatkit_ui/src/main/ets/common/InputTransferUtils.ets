/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEEmojiManager, NEEmojiParseResult } from '../manager/NEEmojiManager';
import { ChatAitNode } from '../model/ChatAitNode';
import { getAitNodes, parseMessageText } from './MessageHelper';

export enum RichInputTransferNodeType {
  Text = 1,
  Emoji = 2,
  Ait = 3,
}

export interface InputTransferAitSpan {
  spanIndex: number
  accountId: string
  value: string
}

export interface RichInputTransferNode {
  type: RichInputTransferNodeType
  text: string
  emojiFile?: string
  accountId?: string
}

export interface MultilineTransferPayload {
  title: string
  bodyText: string
  bodyNodes: RichInputTransferNode[]
}

export interface RestoredMultiLineContent {
  title: string
  body: string
  bodyNodes: RichInputTransferNode[]
}

interface PendingTransferNode {
  node: RichInputTransferNode
  offset: number
  order: number
}

function cloneTransferNode(node: RichInputTransferNode): RichInputTransferNode {
  return {
    type: node.type,
    text: node.text,
    emojiFile: node.emojiFile,
    accountId: node.accountId
  }
}

export function collectRichInputTransferNodes(
  spans: Array<RichEditorImageSpanResult | RichEditorTextSpanResult> | undefined,
  builderSpans: InputTransferAitSpan[] | undefined
): RichInputTransferNode[] {
  const pendingNodes: PendingTransferNode[] = []
  const usedBuilderSpanIndex: Set<number> = new Set()
  let nextBuilderSpanIndex = 0
  const safeSpans = spans ?? []
  const safeBuilderSpans = builderSpans ?? []
  safeSpans.forEach((span, spanOrder) => {
    const textSpan = span as RichEditorTextSpanResult
    const spanRange = textSpan.spanPosition?.spanRange
    const spanOffset = spanRange ? spanRange[0] : spanOrder
    if (textSpan.value) {
      pendingNodes.push({
        offset: spanOffset,
        order: spanOrder,
        node: {
          type: RichInputTransferNodeType.Text,
          text: textSpan.value
        }
      })
      return
    }

    const imageSpan = span as RichEditorImageSpanResult
    const resourcePath = imageSpan.valueResourceStr?.toString()
    if (resourcePath && resourcePath.length > 0) {
      const segments = resourcePath.split('/')
      const fileName = segments[segments.length - 1]
      const emoji = NEEmojiManager.instance.getEmojiByName(fileName)
      if (emoji?.tag && emoji.file) {
        pendingNodes.push({
          offset: spanOffset,
          order: spanOrder,
          node: {
            type: RichInputTransferNodeType.Emoji,
            text: emoji.tag,
            emojiFile: emoji.file
          }
        })
      }
      return
    }

    const builderSpanIndex = safeBuilderSpans.findIndex((builderSpan, index) =>
      !usedBuilderSpanIndex.has(index) && builderSpan.spanIndex === spanOffset)
    let matchedBuilderSpanIndex = builderSpanIndex
    if (matchedBuilderSpanIndex < 0 && !spanRange) {
      while (nextBuilderSpanIndex < safeBuilderSpans.length && usedBuilderSpanIndex.has(nextBuilderSpanIndex)) {
        nextBuilderSpanIndex += 1
      }
      if (nextBuilderSpanIndex < safeBuilderSpans.length) {
        matchedBuilderSpanIndex = nextBuilderSpanIndex
      }
    }

    if (matchedBuilderSpanIndex >= 0) {
      const builderSpan = safeBuilderSpans[matchedBuilderSpanIndex]
      pendingNodes.push({
        offset: spanOffset,
        order: spanOrder,
        node: {
          type: RichInputTransferNodeType.Ait,
          text: builderSpan.value,
          accountId: builderSpan.accountId
        }
      })
      usedBuilderSpanIndex.add(matchedBuilderSpanIndex)
      if (matchedBuilderSpanIndex === nextBuilderSpanIndex) {
        nextBuilderSpanIndex += 1
      }
    }
  })

  safeBuilderSpans.forEach((builderSpan, index) => {
    if (!usedBuilderSpanIndex.has(index)) {
      pendingNodes.push({
        offset: builderSpan.spanIndex,
        order: safeSpans.length + index,
        node: {
          type: RichInputTransferNodeType.Ait,
          text: builderSpan.value,
          accountId: builderSpan.accountId
        }
      })
    }
  })

  pendingNodes.sort((left, right) => {
    if (left.offset === right.offset) {
      return left.order - right.order
    }
    return left.offset - right.offset
  })

  return pendingNodes.map((item) => cloneTransferNode(item.node))
}

export function getRichInputTransferText(nodes: RichInputTransferNode[]): string {
  let text = ''
  nodes.forEach((node) => {
    text += node.text
  })
  return text
}

export function splitSingleLineTransferNodes(nodes: RichInputTransferNode[]): MultilineTransferPayload {
  const fullText = getRichInputTransferText(nodes)
  if (fullText.indexOf('\n') < 0) {
    return {
      title: '',
      bodyText: fullText,
      bodyNodes: nodes.map((node) => cloneTransferNode(node))
    }
  }

  let title = ''
  let switchedToBody = false
  const bodyNodes: RichInputTransferNode[] = []

  nodes.forEach((node) => {
    if (switchedToBody) {
      bodyNodes.push(cloneTransferNode(node))
      return
    }

    if (node.type !== RichInputTransferNodeType.Text) {
      title += node.text
      return
    }

    const newlineIndex = node.text.indexOf('\n')
    if (newlineIndex < 0) {
      title += node.text
      return
    }

    title += node.text.substring(0, newlineIndex)
    const bodyText = node.text.substring(newlineIndex + 1)
    if (bodyText.length > 0) {
      bodyNodes.push({
        type: RichInputTransferNodeType.Text,
        text: bodyText
      })
    }
    switchedToBody = true
  })

  return {
    title: title,
    bodyText: getRichInputTransferText(bodyNodes),
    bodyNodes: bodyNodes
  }
}

export function restoreAitTransferNodesFromMessageText(text?: string, extension?: string): RichInputTransferNode[] {
  const nodes: RichInputTransferNode[] = []
  parseMessageText(text)?.forEach((item: NEEmojiParseResult) => {
    if (item.text) {
      getAitNodes(item.startIndex, item.text, extension)
        .forEach((node: ChatAitNode) => {
          if (node.segment) {
            nodes.push({
              type: RichInputTransferNodeType.Ait,
              text: node.text,
              accountId: node.account ?? ''
            })
          } else if (node.text.length > 0) {
            nodes.push({
              type: RichInputTransferNodeType.Text,
              text: node.text
            })
          }
        })
      return
    }

    if (item.emoji) {
      nodes.push({
        type: RichInputTransferNodeType.Emoji,
        text: item.emoji.tag ?? '',
        emojiFile: item.emoji.file
      })
    }
  })
  return nodes
}

export function restoreMultiLineContent(title: string, body: string, bodyNodes?: RichInputTransferNode[]): RestoredMultiLineContent {
  const restoredNodes = bodyNodes && bodyNodes.length > 0
    ? bodyNodes.map((node) => cloneTransferNode(node))
    : [{
      type: RichInputTransferNodeType.Text,
      text: body
    } as RichInputTransferNode]

  if ((!body || body.length === 0) && (!bodyNodes || bodyNodes.length === 0)) {
    return {
      title: title,
      body: '',
      bodyNodes: []
    }
  }

  return {
    title: title,
    body: body,
    bodyNodes: restoredNodes
  }
}
