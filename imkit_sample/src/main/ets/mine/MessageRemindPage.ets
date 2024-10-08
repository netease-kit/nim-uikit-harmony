/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NavigationBackBuilder } from '@nimkit/common';
import { SettingRepo } from '@nimkit/chatkit';

// 跳转页面入口函数
@Builder
function MessageRemindPageBuilder() {
  MessageRemindPage()
}

@Component
export struct MessageRemindPage {
  pathStack: NavPathStack = new NavPathStack()
  @State showRemind?: boolean = undefined
  @State showRemindDetail?: boolean = undefined

  showRemindSwitchChange(isOpen: boolean) {
    SettingRepo.setDndConfig({
      dndOn: isOpen
    })
  }

  showRemindDetailSwitchChange(isOpen: boolean) {
    SettingRepo.setDndConfig({
      showDetail: isOpen
    })
  }

  async requestData() {
    try {
      const config = await SettingRepo.getDndConfig()
      if (config) {
        this.showRemind = config.dndOn
        this.showRemindDetail = config.showDetail
      }
    } catch (err) {
      console.log(err)
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r("app.string.person_setting_remind"),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        List({ space: 12 }) {
          ListItem() {
            Row() {
              Text($r("app.string.mine_setting_show_remind"))
                .fontSize(14)
                .fontColor("#333333")
                .height(18)
                .margin({ left: 16, right: 12 })
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Toggle({ type: ToggleType.Switch, isOn: this.showRemind })
                .selectedColor("#337EFF")
                .width(46)
                .height(28)
                .margin({ right: 16 })
                .onChange(this.showRemindSwitchChange)
            }
          }
          .width('100%')
          .height(48)
          .backgroundColor(Color.White)
          .borderRadius(8)

          ListItem() {
            Row() {
              Text($r("app.string.mine_setting_show_remind_detail"))
                .fontSize(14)
                .fontColor("#333333")
                .height(18)
                .margin({ left: 16, right: 12 })
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Toggle({ type: ToggleType.Switch, isOn: this.showRemindDetail })
                .selectedColor("#337EFF")
                .width(46)
                .height(28)
                .margin({ right: 16 })
                .onChange(this.showRemindDetailSwitchChange)
            }
          }
          .width('100%')
          .height(48)
          .backgroundColor(Color.White)
          .borderRadius(8)
        }
        .backgroundColor(Color.Transparent)
        .margin({ left: 20, right: 20, top: 0 })
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }
}