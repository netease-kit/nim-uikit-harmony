/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { NEEmojiManager } from '../main/ets/manager/NEEmojiManager'
import { NEStickerItem, NEStickerPackage } from '../main/ets/model/NEStickerPackage'

function makeResource(id: number): Resource {
  const resource = new Object() as Resource
  resource.bundleName = 'test.bundle'
  resource.moduleName = 'test_module'
  resource.id = id
  resource.type = 20000
  return resource
}

function makeSticker(id: string, resourceId: number = 1): NEStickerItem {
  return new NEStickerItem(id, makeResource(resourceId), `${id}.png`)
}

function makePackage(id: string, stickers: NEStickerItem[] = [makeSticker(`${id}-1`)]): NEStickerPackage {
  return new NEStickerPackage(id, makeResource(100), makeResource(101), stickers)
}

export default function neEmojiManagerTest() {
  describe('NEEmojiManager sticker packages', () => {
    it('sets valid packages and filters invalid packages', 0, () => {
      const manager = NEEmojiManager.instance
      manager.clearStickerPackages()

      manager.setStickerPackages([
        makePackage('chicken'),
        makePackage('', [makeSticker('invalid-empty-id')]),
        makePackage('empty-package', [])
      ])

      expect(manager.stickerPackages.length).assertEqual(1)
      expect(manager.stickerPackages[0].id).assertEqual('chicken')
      manager.clearStickerPackages()
    })

    it('uses the last valid package for duplicate ids', 0, () => {
      const manager = NEEmojiManager.instance
      manager.clearStickerPackages()

      manager.setStickerPackages([
        makePackage('chicken', [makeSticker('first')]),
        makePackage('chicken', [makeSticker('second-1'), makeSticker('second-2')])
      ])

      expect(manager.stickerPackages.length).assertEqual(1)
      expect(manager.stickerPackages[0].stickers.length).assertEqual(2)
      expect(manager.stickerPackages[0].stickers[0].id).assertEqual('second-1')
      manager.clearStickerPackages()
    })

    it('appends and updates a single package in place', 0, () => {
      const manager = NEEmojiManager.instance
      manager.clearStickerPackages()
      const initialRevision = manager.stickerPackageRevision

      expect(manager.addStickerPackage(makePackage('chicken'))).assertTrue()
      expect(manager.addStickerPackage(makePackage('bear'))).assertTrue()
      expect(manager.addStickerPackage(makePackage('chicken', [makeSticker('updated')]))).assertTrue()

      expect(manager.stickerPackages.length).assertEqual(2)
      expect(manager.stickerPackages[0].id).assertEqual('chicken')
      expect(manager.stickerPackages[0].stickers[0].id).assertEqual('updated')
      expect(manager.stickerPackages[1].id).assertEqual('bear')
      expect(manager.stickerPackageRevision).assertEqual(initialRevision + 3)

      const exposedPackages = manager.stickerPackages
      exposedPackages.push(makePackage('outside'))
      expect(manager.stickerPackages.length).assertEqual(2)
      manager.clearStickerPackages()
    })

    it('rejects invalid sticker items and clears all custom packages', 0, () => {
      const manager = NEEmojiManager.instance
      manager.clearStickerPackages()

      expect(manager.addStickerPackage(makePackage('invalid', [makeSticker('')]))).assertFalse()
      expect(manager.stickerPackages.length).assertEqual(0)

      manager.addStickerPackage(makePackage('rabbit'))
      manager.clearStickerPackages()
      expect(manager.stickerPackages.length).assertEqual(0)
    })

    it('rejects packages with non-media or incomplete resources', 0, () => {
      const manager = NEEmojiManager.instance
      manager.clearStickerPackages()
      const textResource = makeResource(201)
      textResource.type = 10003
      const missingTypeResource = makeResource(202)
      missingTypeResource.type = undefined
      const incompleteResource = new Object() as Resource
      incompleteResource.bundleName = ''
      incompleteResource.moduleName = ''
      incompleteResource.id = 203
      incompleteResource.type = 20000

      expect(manager.addStickerPackage(
        new NEStickerPackage('invalid-tab', textResource, makeResource(204), [makeSticker('valid')]))).assertFalse()
      expect(manager.addStickerPackage(
        new NEStickerPackage('missing-type', makeResource(205), missingTypeResource,
          [makeSticker('valid')]))).assertFalse()
      expect(manager.addStickerPackage(
        new NEStickerPackage('invalid-sticker', makeResource(206), makeResource(207), [
          new NEStickerItem('invalid', incompleteResource, 'invalid.png')
        ]))).assertFalse()
      expect(manager.stickerPackages.length).assertEqual(0)
    })
  })
}
