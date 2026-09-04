/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { NIMEmoticonType, NIMInputEmoticon } from '../main/ets/manager/NEEmojiManager'
import { NEStickerItem, NEStickerPackage } from '../main/ets/model/NEStickerPackage'
import {
  buildEmoticonPages,
  clampEmoticonPageIndex,
  getPackageStartPage,
  NEEmoticonPageType
} from '../main/ets/utils/EmoticonPaginationUtils'

function makeResource(id: number): Resource {
  const resource = new Object() as Resource
  resource.bundleName = 'test.bundle'
  resource.moduleName = 'test_module'
  resource.id = id
  resource.type = 20000
  return resource
}

function makeEmojis(count: number): NIMInputEmoticon[] {
  const emojis: NIMInputEmoticon[] = []
  for (let index = 0; index < count; index++) {
    const emoji = new NIMInputEmoticon()
    emoji.id = `emoji-${index}`
    emoji.file = `emoji-${index}.png`
    emojis.push(emoji)
  }
  return emojis
}

function makePackage(id: string, count: number, resourceStart: number): NEStickerPackage {
  const stickers: NEStickerItem[] = []
  for (let index = 0; index < count; index++) {
    stickers.push(new NEStickerItem(`${id}-${index}`, makeResource(resourceStart + index), `${id}-${index}.png`))
  }
  return new NEStickerPackage(id, makeResource(resourceStart + 1000), makeResource(resourceStart + 1001), stickers)
}

export default function emoticonPaginationUtilsTest() {
  describe('EmoticonPaginationUtils', () => {
    it('builds three emoji pages with a delete item on every page', 0, () => {
      const deleteEmoji = new NIMInputEmoticon()
      deleteEmoji.type = NIMEmoticonType.delete

      const pages = buildEmoticonPages(makeEmojis(69), [], deleteEmoji)

      expect(pages.length).assertEqual(3)
      expect(pages[0].type).assertEqual(NEEmoticonPageType.EMOJI)
      expect(pages[0].emojis.length).assertEqual(24)
      expect(pages[1].emojis.length).assertEqual(24)
      expect(pages[2].emojis.length).assertEqual(24)
      expect(pages[2].emojis[23].type).assertEqual(NIMEmoticonType.delete)
      expect(pages[2].packagePageCount).assertEqual(3)
    })

    it('keeps an emoji placeholder page while emoji resources load', 0, () => {
      const pages = buildEmoticonPages([], [makePackage('ajmd', 8, 100)], new NIMInputEmoticon())

      expect(pages.length).assertEqual(2)
      expect(pages[0].type).assertEqual(NEEmoticonPageType.EMOJI)
      expect(pages[0].packageIndex).assertEqual(0)
      expect(pages[1].packageIndex).assertEqual(1)

      const loadedPages = buildEmoticonPages(makeEmojis(69), [makePackage('ajmd', 8, 100)],
        new NIMInputEmoticon())
      expect(pages[0].key).not().assertEqual(loadedPages[0].key)
      expect(loadedPages[0].emojis.length).assertEqual(24)
    })

    it('builds 17 flattened pages for emoji chicken bear and rabbit', 0, () => {
      const pages = buildEmoticonPages(makeEmojis(69), [
        makePackage('ajmd', 48, 100),
        makePackage('xxy', 40, 200),
        makePackage('lt', 20, 300)
      ], new NIMInputEmoticon())

      expect(pages.length).assertEqual(17)
      expect(pages[2].packageIndex).assertEqual(0)
      expect(pages[3].packageIndex).assertEqual(1)
      expect(pages[3].pageIndexInPackage).assertEqual(0)
      expect(pages[8].pageIndexInPackage).assertEqual(5)
      expect(pages[9].packageIndex).assertEqual(2)
      expect(pages[13].pageIndexInPackage).assertEqual(4)
      expect(pages[14].packageIndex).assertEqual(3)
      expect(pages[16].pageIndexInPackage).assertEqual(2)
      expect(pages[16].stickers.length).assertEqual(4)
    })

    it('resolves package start pages and clamps stale page indexes', 0, () => {
      const pages = buildEmoticonPages(makeEmojis(69), [
        makePackage('ajmd', 48, 100),
        makePackage('xxy', 40, 200),
        makePackage('lt', 20, 300)
      ], new NIMInputEmoticon())

      expect(getPackageStartPage(pages, 0)).assertEqual(0)
      expect(getPackageStartPage(pages, 1)).assertEqual(3)
      expect(getPackageStartPage(pages, 2)).assertEqual(9)
      expect(getPackageStartPage(pages, 3)).assertEqual(14)
      expect(getPackageStartPage(pages, 4)).assertEqual(-1)
      expect(clampEmoticonPageIndex(-1, pages.length)).assertEqual(0)
      expect(clampEmoticonPageIndex(20, pages.length)).assertEqual(16)
      expect(clampEmoticonPageIndex(2, pages.length)).assertEqual(2)
      expect(clampEmoticonPageIndex(2, 0)).assertEqual(0)
    })

    it('changes page keys when registered packages are refreshed', 0, () => {
      const packages = [makePackage('ajmd', 8, 100)]

      const firstPages = buildEmoticonPages(makeEmojis(23), packages, new NIMInputEmoticon(), 1)
      const refreshedPages = buildEmoticonPages(makeEmojis(23), packages, new NIMInputEmoticon(), 2)

      expect(firstPages[0].key).assertEqual('emoji-1-23-0')
      expect(firstPages[1].key).assertEqual('ajmd-1-0')
      expect(refreshedPages[0].key).assertEqual('emoji-2-23-0')
      expect(refreshedPages[1].key).assertEqual('ajmd-2-0')
    })
  })
}
