/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { NEEmojiManager, NEStickerItem, NEStickerPackage } from '@nimkit/chatkit_ui'

const AJMD_RESOURCES: Resource[] = [
  $r('app.media.ajmd001'), $r('app.media.ajmd002'), $r('app.media.ajmd003'), $r('app.media.ajmd004'),
  $r('app.media.ajmd005'), $r('app.media.ajmd006'), $r('app.media.ajmd007'), $r('app.media.ajmd008'),
  $r('app.media.ajmd009'), $r('app.media.ajmd010'), $r('app.media.ajmd011'), $r('app.media.ajmd012'),
  $r('app.media.ajmd013'), $r('app.media.ajmd014'), $r('app.media.ajmd015'), $r('app.media.ajmd016'),
  $r('app.media.ajmd017'), $r('app.media.ajmd018'), $r('app.media.ajmd019'), $r('app.media.ajmd020'),
  $r('app.media.ajmd021'), $r('app.media.ajmd022'), $r('app.media.ajmd023'), $r('app.media.ajmd024'),
  $r('app.media.ajmd025'), $r('app.media.ajmd026'), $r('app.media.ajmd027'), $r('app.media.ajmd028'),
  $r('app.media.ajmd029'), $r('app.media.ajmd030'), $r('app.media.ajmd031'), $r('app.media.ajmd032'),
  $r('app.media.ajmd033'), $r('app.media.ajmd034'), $r('app.media.ajmd035'), $r('app.media.ajmd036'),
  $r('app.media.ajmd037'), $r('app.media.ajmd038'), $r('app.media.ajmd039'), $r('app.media.ajmd040'),
  $r('app.media.ajmd041'), $r('app.media.ajmd042'), $r('app.media.ajmd043'), $r('app.media.ajmd044'),
  $r('app.media.ajmd045'), $r('app.media.ajmd046'), $r('app.media.ajmd047'), $r('app.media.ajmd048')
]

const XXY_RESOURCES: Resource[] = [
  $r('app.media.xxy001'), $r('app.media.xxy002'), $r('app.media.xxy003'), $r('app.media.xxy004'),
  $r('app.media.xxy005'), $r('app.media.xxy006'), $r('app.media.xxy007'), $r('app.media.xxy008'),
  $r('app.media.xxy009'), $r('app.media.xxy010'), $r('app.media.xxy011'), $r('app.media.xxy012'),
  $r('app.media.xxy013'), $r('app.media.xxy014'), $r('app.media.xxy015'), $r('app.media.xxy016'),
  $r('app.media.xxy017'), $r('app.media.xxy018'), $r('app.media.xxy019'), $r('app.media.xxy020'),
  $r('app.media.xxy021'), $r('app.media.xxy022'), $r('app.media.xxy023'), $r('app.media.xxy024'),
  $r('app.media.xxy025'), $r('app.media.xxy026'), $r('app.media.xxy027'), $r('app.media.xxy028'),
  $r('app.media.xxy029'), $r('app.media.xxy030'), $r('app.media.xxy031'), $r('app.media.xxy032'),
  $r('app.media.xxy033'), $r('app.media.xxy034'), $r('app.media.xxy035'), $r('app.media.xxy036'),
  $r('app.media.xxy037'), $r('app.media.xxy038'), $r('app.media.xxy039'), $r('app.media.xxy040')
]

const LT_RESOURCES: Resource[] = [
  $r('app.media.lt001'), $r('app.media.lt002'), $r('app.media.lt003'), $r('app.media.lt004'),
  $r('app.media.lt005'), $r('app.media.lt006'), $r('app.media.lt007'), $r('app.media.lt008'),
  $r('app.media.lt009'), $r('app.media.lt010'), $r('app.media.lt011'), $r('app.media.lt012'),
  $r('app.media.lt013'), $r('app.media.lt014'), $r('app.media.lt015'), $r('app.media.lt016'),
  $r('app.media.lt017'), $r('app.media.lt018'), $r('app.media.lt019'), $r('app.media.lt020')
]

function formatStickerIndex(index: number): string {
  const value = index + 1
  if (value < 10) {
    return `00${value}`
  }
  if (value < 100) {
    return `0${value}`
  }
  return `${value}`
}
function buildStickerItems(packageId: string, resources: Resource[]): NEStickerItem[] {
  const stickers: NEStickerItem[] = []
  for (let index = 0; index < resources.length; index++) {
    const stickerId = packageId + formatStickerIndex(index)
    stickers.push(new NEStickerItem(stickerId, resources[index], `${stickerId}.png`))
  }
  return stickers
}

export function registerSampleStickerPackages(): void {
  NEEmojiManager.instance.setStickerPackages([
    new NEStickerPackage('ajmd', $r('app.media.ajmd_s_normal'), $r('app.media.ajmd_s_pressed'),
      buildStickerItems('ajmd', AJMD_RESOURCES)),
    new NEStickerPackage('xxy', $r('app.media.xxy_s_normal'), $r('app.media.xxy_s_pressed'),
      buildStickerItems('xxy', XXY_RESOURCES)),
    new NEStickerPackage('lt', $r('app.media.lt_s_normal'), $r('app.media.lt_s_pressed'),
      buildStickerItems('lt', LT_RESOURCES))
  ])
}
