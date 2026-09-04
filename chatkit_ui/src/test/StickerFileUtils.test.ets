/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  buildStickerTempFileName,
  toExactArrayBuffer,
  writeStickerBufferSync
} from '../main/ets/utils/StickerFileUtils'

export default function stickerFileUtilsTest() {
  describe('StickerFileUtils', () => {
    it('normalizes unsafe names and lowercases supported extensions', 0, () => {
      expect(buildStickerTempFileName('../a b.PNG', 100)).assertEqual('100_a_b.png')
      expect(buildStickerTempFileName('bear-01.webp', 101)).assertEqual('101_bear-01.webp')
    })

    it('falls back to a png sticker name for empty or extensionless input', 0, () => {
      expect(buildStickerTempFileName('', 100)).assertEqual('100_sticker.png')
      expect(buildStickerTempFileName('rabbit', 101)).assertEqual('101_rabbit.png')
    })

    it('copies only the visible byte range from media content', 0, () => {
      const source = new Uint8Array([10, 20, 30, 40])
      const visible = new Uint8Array(source.buffer, 1, 2)

      const result = new Uint8Array(toExactArrayBuffer(visible))

      expect(result.length).assertEqual(2)
      expect(result[0]).assertEqual(20)
      expect(result[1]).assertEqual(30)
    })

    it('continues writing after a short synchronous write', 0, () => {
      const chunkSizes: number[] = []
      let invocation = 0
      const source = new Uint8Array([10, 20, 30, 40])

      writeStickerBufferSync(1, toExactArrayBuffer(source),
        (fd: number, buffer: ArrayBuffer): number => {
          chunkSizes.push(buffer.byteLength)
          invocation++
          return invocation === 1 ? 2 : buffer.byteLength
        })

      expect(chunkSizes.length).assertEqual(2)
      expect(chunkSizes[0]).assertEqual(4)
      expect(chunkSizes[1]).assertEqual(2)
    })
  })
}
