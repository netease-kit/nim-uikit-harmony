/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils, NEFriendUserCache } from '@nimkit/chatkit';
import { NavigationBackBuilder } from '@nimkit/common';
import { EditInfoViewModel } from '../model/EditInfoViewModel';
import { EditInfoParam } from './EditInfoPage';

// 跳转页面入口函数
@Builder
function EditGenderPageBuilder() {
  EditGenderPage()
}

@ComponentV2
export struct EditGenderPage {
  pathStack: NavPathStack = new NavPathStack()
  viewModel: EditInfoViewModel = new EditInfoViewModel()
  @Local isMale?: number = 0;
  // 返回前保存
  backAction = () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      this.viewModel.saveGender(this.isMale)
      this.pathStack.pop(this.isMale)
    } else {
      this.pathStack.pop()
    }
  }

  requestData() {
    const param = this.pathStack.getParamByName('EditGenderPage')[0] as EditInfoParam
    this.isMale = NEFriendUserCache.mineUserCache?.user?.gender
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r("app.string.person_info_gender"),
          backgroundColor: '#EFF1F4',
          leftButtonAction: this.backAction
        })

        List() {
          ListItem() {
            Column() {
              Row() {
                Text($r("app.string.person_gender_unknown"))
                  .fontSize(16)
                  .fontColor("#333333")
                  .height(18)
                  .margin({ left: 16 })
                  .layoutWeight(2)

                Row()
                  .layoutWeight(1)

                if (this.isMale === 0) {
                  Image($r('app.media.mine_gender_edit_ok'))
                    .width(16)
                    .height(16)
                    .margin({ right: 16 })
                }
              }
              .height(48)
              .alignSelf(ItemAlign.Center)

              Row()
                .width('100%')
                .height(1)
                .backgroundColor("#F5F8FC")
                .margin({ left: 16 })
            }
          }
          .onClick(() => {
            this.isMale = 0
          })

          ListItem() {
            Column() {
              Row() {
                Text($r("app.string.person_gender_male"))
                  .fontSize(16)
                  .fontColor("#333333")
                  .height(18)
                  .margin({ left: 16 })
                  .layoutWeight(2)

                Row()
                  .layoutWeight(1)

                if (this.isMale === 1) {
                  Image($r('app.media.mine_gender_edit_ok'))
                    .width(16)
                    .height(16)
                    .margin({ right: 16 })
                }
              }
              .height(48)
              .alignSelf(ItemAlign.Center)

              Row()
                .width('100%')
                .height(1)
                .backgroundColor("#F5F8FC")
                .margin({ left: 16 })
            }
          }
          .onClick(() => {
            this.isMale = 1
          })

          ListItem() {
            Row() {
              Text($r("app.string.person_gender_female"))
                .fontSize(16)
                .fontColor("#333333")
                .height(18)
                .margin({ left: 16 })
                .layoutWeight(2)

              Row()
                .layoutWeight(1)

              if (this.isMale === 2) {
                Image($r('app.media.mine_gender_edit_ok'))
                  .width(16)
                  .height(16)
                  .margin({ right: 16 })
              }
            }
            .height(48)
            .alignSelf(ItemAlign.Center)
          }
          .onClick(() => {
            this.isMale = 2
          })
        }
        .borderRadius(8)
        .backgroundColor(Color.White)
        .margin({
          left: 20,
          right: 20,
          bottom: 56
        })
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
    .onBackPressed(() => {
      this.backAction()
      return true
    })
  }
}