/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { NIMInputEmoticon } from '../manager/NEEmojiManager'
import { NEStickerItem, NEStickerPackage } from '../model/NEStickerPackage'

export const EMOJI_COUNT_PER_PAGE: number = 23
export const STICKER_COUNT_PER_PAGE: number = 8

export enum NEEmoticonPageType {
  EMOJI = 0,
  STICKER = 1
}

export class NEEmoticonPage {
  key: string
  type: NEEmoticonPageType
  packageIndex: number
  pageIndexInPackage: number
  packagePageCount: number
  emojis: NIMInputEmoticon[]
  stickers: NEStickerItem[]

  constructor(key: string, type: NEEmoticonPageType, packageIndex: number, pageIndexInPackage: number,
    packagePageCount: number, emojis: NIMInputEmoticon[] = [], stickers: NEStickerItem[] = []) {
    this.key = key
    this.type = type
    this.packageIndex = packageIndex
    this.pageIndexInPackage = pageIndexInPackage
    this.packagePageCount = packagePageCount
    this.emojis = emojis
    this.stickers = stickers
  }
}

function buildEmojiPages(emojis: NIMInputEmoticon[], deleteEmoji: NIMInputEmoticon,
  revision: number): NEEmoticonPage[] {
  const pages: NEEmoticonPage[] = []
  const pageCount = Math.max(1, Math.ceil(emojis.length / EMOJI_COUNT_PER_PAGE))
  for (let pageIndex = 0; pageIndex < pageCount; pageIndex++) {
    const start = pageIndex * EMOJI_COUNT_PER_PAGE
    const pageEmojis = emojis.slice(start, start + EMOJI_COUNT_PER_PAGE)
    pageEmojis.push(deleteEmoji)
    pages.push(new NEEmoticonPage(`emoji-${revision}-${emojis.length}-${pageIndex}`,
      NEEmoticonPageType.EMOJI, 0, pageIndex,
      pageCount, pageEmojis))
  }
  return pages
}

function buildStickerPages(stickerPackage: NEStickerPackage, packageIndex: number,
  revision: number): NEEmoticonPage[] {
  const pages: NEEmoticonPage[] = []
  const pageCount = Math.ceil(stickerPackage.stickers.length / STICKER_COUNT_PER_PAGE)
  for (let pageIndex = 0; pageIndex < pageCount; pageIndex++) {
    const start = pageIndex * STICKER_COUNT_PER_PAGE
    const pageStickers = stickerPackage.stickers.slice(start, start + STICKER_COUNT_PER_PAGE)
    pages.push(new NEEmoticonPage(`${stickerPackage.id}-${revision}-${pageIndex}`, NEEmoticonPageType.STICKER,
      packageIndex, pageIndex, pageCount, [], pageStickers))
  }
  return pages
}

export function buildEmoticonPages(emojis: NIMInputEmoticon[], stickerPackages: NEStickerPackage[],
  deleteEmoji: NIMInputEmoticon, revision: number = 0): NEEmoticonPage[] {
  const pages = buildEmojiPages(emojis, deleteEmoji, revision)
  stickerPackages.forEach((stickerPackage: NEStickerPackage, index: number): void => {
    pages.push(...buildStickerPages(stickerPackage, index + 1, revision))
  })
  return pages
}

export function getPackageStartPage(pages: NEEmoticonPage[], packageIndex: number): number {
  for (let index = 0; index < pages.length; index++) {
    if (pages[index].packageIndex === packageIndex) {
      return index
    }
  }
  return -1
}

export function clampEmoticonPageIndex(index: number, pageCount: number): number {
  if (pageCount <= 0 || index < 0) {
    return 0
  }
  return Math.min(index, pageCount - 1)
}
