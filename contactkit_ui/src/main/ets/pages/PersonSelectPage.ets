/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  ListGroupHeader,
  NavigationBackBuilder,
  NECommonUtils,
  ViewItemBuilder
} from '@nimkit/common';
import { ContactViewModel } from '../viewmodel/ContactViewModel';
import { NEContactSection, SelectUserWithFriend } from '../model/NEContactSection';
import { NEUserWithFriend, PersonSelectParam } from '@nimkit/chatkit';

// 跳转页面入口函数
@Builder
export function PersonSelectPageBuilder() {
  PersonSelectPage()
}

@ComponentV2
export struct PersonSelectPage {
  pathStack: NavPathStack = new NavPathStack()
  filterList?: string[] = []
  selectLimit: number = 200
  onClickSureButton?: (selectedList: NEUserWithFriend[]) => void = undefined
  @Local selectStatusMap: Map<string, boolean> = new Map<string, boolean>()
  @Local selectedList: NEUserWithFriend[] = []
  @Local selectedIndex: number = 0; // 用于指定字母导航的选择项
  private viewModel: ContactViewModel = new ContactViewModel()
  // List组件的scroller控制器：listScroller，用于控制联系人列表的滑动位置
  private listScroller: Scroller = new Scroller()

  async requestData(): Promise<void> {
    const param = this.pathStack.getParamByName('PersonSelectPage')[0] as PersonSelectParam
    this.filterList = param.filterList
    this.selectLimit = param.selectLimit
    this.onClickSureButton = param.onClickSureButton

    try {
      await this.viewModel.getFriendList(this.filterList)
      this.viewModel.friendList.forEach((friend) => {
        if (friend.user?.accountId) {
          this.selectStatusMap.set(friend.user?.accountId, false)
        }
      })
    } catch (err) {
      console.error(err)
    }
  }

  sureButtonClickAction = () => {
    if (this.selectedList.length === 0) {
      NECommonUtils.showToast($r('app.string.select_none_tip'))
      return
    }

    if (this.onClickSureButton) {
      this.onClickSureButton(this.selectedList)
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.End }) {
        Stack() {
          Column() {
            NavigationBackBuilder({
              title: $r('app.string.person_select'),
              showDivideLine: true,
              leftButtonTitle: $r('app.string.common_close'),
              leftButtonColor: '#666666',
              leftButtonAction: () => {
                this.pathStack.pop()
              },
              rightButtonTitle: this.selectedList.length > 0 ?
              $r('app.string.common_sure_count', this.selectedList.length) : $r('app.string.common_sure'),
              rightButtonColor: '#337EFF',
              rightButtonAction: this.sureButtonClickAction,
              buttonTextWidth: 80
            })

            if (this.selectedList.length > 0) {
              List() {
                ForEach(this.selectedList, (item: NEUserWithFriend) => {
                  ListItem() {
                    CommonAvatar({
                      item: new AvatarItem(item.user?.avatar, item.shortName(),
                        AvatarColorUntil.getBackgroundColorById(item.user?.accountId ?? "")),
                      roundRadius: 18
                    })
                      .height(36)
                      .width(36)
                      .margin({
                        top: 8
                      })
                  }
                  .width(52)
                  .height(52)
                  .onClick(() => {
                    if (item.user?.accountId) {
                      this.selectStatusMap.set(item.user.accountId, false)
                      for (let index = 0; index < this.selectedList.length; index++) {
                        if (this.selectedList[index].user?.accountId === item.user.accountId) {
                          this.selectedList.splice(index, 1)
                        }
                      }
                    }
                  })
                })
              }
              .listDirection(Axis.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
              .height(52)
              .backgroundColor('#F2F4F5')
              .padding({
                left: 12,
                right: 12
              })
            }

            List({ scroller: this.listScroller }) {
              LazyForEach(this.viewModel.friendSection, (item: NEContactSection) => {
                ListItemGroup({
                  header: ListGroupHeader(item.initial)
                }) {
                  LazyForEach(item.contacts, (item: SelectUserWithFriend) => {
                    ListItem() {
                      Row() {
                        Image(this.selectStatusMap.get(item.user?.accountId) ? $r('app.media.select_yes') :
                        $r('app.media.select_no'))
                          .height(18)
                          .width(18)
                          .margin({
                            left: 20,
                            right: -10
                          })

                        ViewItemBuilder({
                          avatarItem: new AvatarItem(item.user?.avatar, item.shortName(),
                            AvatarColorUntil.getBackgroundColorById(item.user?.accountId ?? "")),
                          title: item.showName(),
                          itemHeight: 60,
                          titleIconSize: 36,
                          titleFontSize: 14,
                          showDivideLine: false,
                          rightIcon: $r('app.string.validation_empty'), // 仅做占位
                        })
                      }
                    }
                    .width('100%')
                    .height(60)
                    .backgroundColor(Color.White)
                    .onClick(() => {
                      if (item.user?.accountId) {
                        const select = this.selectStatusMap.get(item.user?.accountId)
                        if (select) {
                          for (let index = 0; index < this.selectedList.length; index++) {
                            if (this.selectedList[index].user?.accountId === item.user.accountId) {
                              this.selectedList.splice(index, 1)
                              this.selectStatusMap.set(item.user.accountId, !select)
                            }
                          }
                        } else {
                          if (this.selectedList.length < this.selectLimit) {
                            this.selectedList.push(item)
                            this.selectStatusMap.set(item.user.accountId, !select)
                          } else {
                            NECommonUtils.showToast($r('app.string.select_limit_tip', this.selectLimit))
                          }
                        }
                      }
                    })
                  })
                }
              })
            }
            .width('100%')
            .margin({ top: 6 })
            .backgroundColor('#EFF1F4')
            .sticky(StickyStyle.Header)
            .scrollBar(BarState.Off)
            // 获取联系人列表滑动位置的索引，并将索引通过selectedIndex同步给右侧字母导航
            .onScrollIndex((start: number, end: number, center: number) => {
              this.selectedIndex = start
            })
          }
          .width('100%')
          .margin({ bottom: 56 + (this.selectedList.length > 0 ? 52 : 0) })
          .backgroundColor('#EFF1F4')

          if (this.viewModel.friendSection.contactSections.length <= 0) {
            CommonEmptyResult({
              tips: $r('app.string.no_friend')
            })
              .margin({
                top: 56 + 74,
              })
          }
        }
        .alignContent(Alignment.Top)

        // 使用AlphabetIndexer组件实现右侧字母导航
        AlphabetIndexer({ arrayValue: this.viewModel.initalList, selected: 0 })
          .color('#666666')
          .selectedColor(Color.White)
          .selectedBackgroundColor('#337EFF')
          .usingPopup(true)
          .popupPosition({ x: 30, y: (this.viewModel.initalList.length * 16 - 48) / 2 })
          .margin({ right: 10 })
          .itemSize(16)
          .font({ size: 10 })// 指定字母导航的选择项为selectedIndex，完成跟联系人列表的同步
          .selected(this.selectedIndex)// 获取选中字母的索引值，通过listScroller控制列表滑动到对应索引位置
          .onSelect((index: number) => {
            this.listScroller.scrollToIndex(index)
          })
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }
}
