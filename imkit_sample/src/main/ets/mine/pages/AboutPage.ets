/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NavigationBackBuilder, ViewItemArrow } from '@nimkit/common'
import { IM_SDK_VERSION } from '@nimsdk/base'


// 跳转页面入口函数
@Builder
function AboutPageBuilder() {
  AboutPage()
}

@ComponentV2
export struct AboutPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local nimVersion: string = ""
  @Local aboutItems: ViewItemArrow[] = [
    {
      title: $r('app.string.mine_about_uikit_version'),
      subTitle: "10.3.0",
      itemHeight: 48
    },
    {
      title: $r('app.string.mine_about_nim_version'),
      subTitle: IM_SDK_VERSION,
      itemHeight: 48
    },
    {
      title: $r('app.string.mine_about_introduce'),
      itemHeight: 48,
      routerUrl: "IntroducePage",
      rightIcon: $r('app.media.arrow_right')
    },
  ]

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Image($r("app.media.mine_about_logo"))
          .width(72)
          .height(72)
          .objectFit(ImageFit.Contain)

        Text($r('app.string.mine_about_logo'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 10 })

        List() {
          ForEach(this.aboutItems, (item: ViewItemArrow) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.title)
                    .fontSize(14)
                    .fontColor('#333333')
                    .height(20)
                    .margin({ left: 16 })
                    .layoutWeight(1)

                  if (item.subTitle) {
                    Text(item.subTitle)
                      .fontSize(14)
                      .fontColor('#333333')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ right: 20 })
                      .textAlign(TextAlign.End)
                      .layoutWeight(2)
                      .height(38)
                  }

                  if (item.rightIcon) {
                    Image(item.rightIcon)
                      .width(4.92)
                      .height(9.54)
                      .margin({ right: 20 })
                  }
                }
                .height((item.itemHeight ?? 1) - 1)
                .alignSelf(ItemAlign.Center)

                Row()
                  .height(1)
                  .width('100%')
                  .backgroundColor('#F5F8FC')
                  .margin({ left: 32 })
              }
              .height(item.itemHeight)
              .onClick(() => {
                if (item.routerUrl) {
                  this.pathStack.pushPath({
                    name: item.routerUrl
                  })
                }
              })
            }
            .height(item.itemHeight)
          })
        }
        .width('100%')
        .height('100%')
        .margin({ left: 10, right: 0 })
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}