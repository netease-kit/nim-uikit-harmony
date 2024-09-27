/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { router } from '@kit.ArkUI'
import { ViewItem } from '../model/ViewItem'
import { ViewItemArrow } from '../model/ViewItemArrow'
import { ViewItemSwitch } from '../model/ViewItemSwitch'
import { CommonAvatar } from '../view/CommonAvatar'

interface ViewHolderItemBuilderParams {
  items: ViewItem[];
}

@Builder
export function ViewItemBuilder(params: ViewItem) {
  Column() {
    Row() {
      if (params.avatarItem) {
        CommonAvatar({ item: params.avatarItem })
          .width(params.titleIconSize ?? 36)
          .height(params.titleIconSize ?? 36)
          .borderRadius((params.titleIconSize ?? 36 / 2))
          .margin({ left: 20 })
      }

      Text(params.title)
        .fontSize(params.titleFontSize ?? 14)
        .fontColor("#333333")
        .height(18)
        .margin({ left: params.avatarItem ? 12 : 16, right: 12 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if ((params as ViewItemArrow).rightIcon) {
        Image((params as ViewItemArrow).rightIcon)
          .width(4.92)
          .height(9.54)
          .margin({ right: 20 })
      }

      if ((params as ViewItemSwitch).isOpen !== undefined) {
        Toggle({ type: ToggleType.Switch, isOn: (params as ViewItemSwitch).isOpen })
          .selectedColor("#337EFF")
          .width(46)
          .height(28)
          .margin({ right: 16 })
          .onChange((params as ViewItemSwitch).switchChange)
      }
    }
    .alignSelf(ItemAlign.Center)
    .height((params.itemHeight ?? 1) - 1)

    if (params.showDivideLine ?? true) {
      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#F5F8FC')
        .margin({ left: 40 })
    }
  }
  .width('100%')
  .height(params.itemHeight)

  // .onClick(() => {

  // if (params.routerUrl) {
  //   if (params.routerUrl?.search('/') !== -1) {
  //     router.pushUrl({
  //       url: params.routerUrl,
  //       params: { "params": params.routerParams }
  //     })
  //   } else {
  //     router.pushNamedRoute({
  //       name: params.routerUrl,
  //       params: { "params": params.routerParams }
  //     })
  //   }
  // }
  // })
}