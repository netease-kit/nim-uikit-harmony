/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

export class NEStickerItem {
  id: string
  image: Resource
  fileName: string

  constructor(id: string, image: Resource, fileName: string) {
    this.id = id
    this.image = image
    this.fileName = fileName
  }
}
export class NEStickerPackage {
  id: string
  tabIcon: Resource
  selectedTabIcon: Resource
  stickers: NEStickerItem[]

  constructor(id: string, tabIcon: Resource, selectedTabIcon: Resource, stickers: NEStickerItem[]) {
    this.id = id
    this.tabIcon = tabIcon
    this.selectedTabIcon = selectedTabIcon
    this.stickers = stickers
  }
}
