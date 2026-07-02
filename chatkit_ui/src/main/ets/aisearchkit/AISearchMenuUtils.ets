/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { V2NIMMessageType } from '@nimsdk/base'

export function normalizeSelectionStart(start: number, end: number): number {
  return Math.max(0, Math.min(start, end))
}

export function normalizeSelectionEnd(start: number, end: number, textLength: number): number {
  return Math.min(textLength, Math.max(start, end))
}

export function isSelectAllText(start: number, end: number, textLength: number): boolean {
  return normalizeSelectionStart(start, end) === 0 &&
    Math.max(start, end) >= textLength
}

export function getSelectedText(source: string, start: number, end: number): string {
  const selectionStart = normalizeSelectionStart(start, end)
  const selectionEnd = normalizeSelectionEnd(start, end, source.length)
  if (selectionEnd <= selectionStart) {
    return ''
  }
  return source.substring(selectionStart, selectionEnd)
}

export function getMultiLineAISearchText(body: string | undefined): string {
  return body ?? ''
}

export function canShowAISearchForMessageType(messageType: V2NIMMessageType, isMultiLineMsg: boolean): boolean {
  return messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT || isMultiLineMsg
}

export interface AISearchTextRenderUnit {
  sourceStart: number
  sourceLength: number
  renderLength: number
}

export function getRenderedTextLength(sourceText: string, units: AISearchTextRenderUnit[]): number {
  let renderedLength = sourceText.length
  units.forEach((unit: AISearchTextRenderUnit) => {
    renderedLength += Math.max(0, unit.renderLength) - Math.max(0, unit.sourceLength)
  })
  return Math.max(0, renderedLength)
}

export function normalizeRenderedSelectionRange(sourceText: string, units: AISearchTextRenderUnit[], start: number,
  end: number): number[] {
  const renderStart = Math.max(0, Math.min(start, end))
  const renderEnd = Math.max(start, end)
  const renderTextLength = getRenderedTextLength(sourceText, units)
  if (renderStart === 0 && renderEnd >= renderTextLength) {
    return [0, sourceText.length]
  }
  return [
    renderOffsetToSourceOffset(sourceText, units, renderStart, true),
    renderOffsetToSourceOffset(sourceText, units, renderEnd, false)
  ]
}

function renderOffsetToSourceOffset(sourceText: string, units: AISearchTextRenderUnit[], offset: number,
  isSelectionStart: boolean): number {
  const sortedUnits = units.slice().sort((a: AISearchTextRenderUnit, b: AISearchTextRenderUnit) =>
    a.sourceStart - b.sourceStart)
  let sourceCursor = 0
  let renderCursor = 0
  const safeOffset = Math.max(0, offset)

  for (let index = 0; index < sortedUnits.length; index++) {
    const unit = sortedUnits[index]
    const unitSourceStart = Math.max(sourceCursor, Math.min(unit.sourceStart, sourceText.length))
    const plainSourceLength = unitSourceStart - sourceCursor
    if (safeOffset < renderCursor + plainSourceLength) {
      return Math.min(sourceText.length, sourceCursor + safeOffset - renderCursor)
    }
    renderCursor += plainSourceLength
    sourceCursor = unitSourceStart

    const unitRenderLength = Math.max(0, unit.renderLength)
    const unitSourceLength = Math.max(0, unit.sourceLength)
    if (safeOffset === renderCursor && unitRenderLength === 0) {
      if (isSelectionStart) {
        sourceCursor = Math.min(sourceText.length, sourceCursor + unitSourceLength)
        continue
      }
      return sourceCursor
    }
    if (safeOffset <= renderCursor + unitRenderLength) {
      if (safeOffset <= renderCursor) {
        return sourceCursor
      }
      return Math.min(sourceText.length, sourceCursor + unitSourceLength)
    }
    renderCursor += unitRenderLength
    sourceCursor = Math.min(sourceText.length, sourceCursor + unitSourceLength)
  }

  const remainingSourceLength = sourceText.length - sourceCursor
  if (safeOffset <= renderCursor + remainingSourceLength) {
    return Math.min(sourceText.length, sourceCursor + safeOffset - renderCursor)
  }
  return sourceText.length
}

@ObservedV2
export class AISearchSelectionState {
  @Trace active: boolean = false
  @Trace text: string = ''
  @Trace start: number = 0
  @Trace end: number = 0
  @Trace rectX: number = 0
  @Trace rectY: number = 0
  @Trace rectWidth: number = 0
  @Trace rectHeight: number = 0

  open(text: string, x: number, y: number, width: number, height: number): void {
    this.text = text
    this.start = 0
    this.end = text.length
    this.rectX = x
    this.rectY = y
    this.rectWidth = Math.max(width, 1)
    this.rectHeight = Math.max(height, 1)
    this.active = text.trim().length > 0
  }

  updateRange(start: number, end: number): void {
    this.start = normalizeSelectionStart(start, end)
    this.end = normalizeSelectionEnd(start, end, this.text.length)
  }

  close(): void {
    this.active = false
    this.text = ''
    this.start = 0
    this.end = 0
    this.rectX = 0
    this.rectY = 0
    this.rectWidth = 0
    this.rectHeight = 0
  }

  isAllSelected(): boolean {
    return isSelectAllText(this.start, this.end, this.text.length)
  }

  selectedText(): string {
    return getSelectedText(this.text, this.start, this.end)
  }
}
