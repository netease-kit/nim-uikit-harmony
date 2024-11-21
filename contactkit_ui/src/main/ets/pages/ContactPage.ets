/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  AvatarColorUntil,
  AvatarItem,
  CommonEmptyResult,
  ListGroupHeader,
  NavigationTitleBuilder,
  ViewItem,
  ViewItemBuilder
} from '@nimkit/common';
import { ContactViewModel } from '../viewmodel/ContactViewModel';
import { NEContactSection } from '../model/NEContactSection';
import { ChatKitClient, ContactRepo, NEFriendUserCache, NEUserWithFriend } from '@nimkit/chatkit';
import { NEContactItem } from '../model/NEContactItem';
import { V2NIMFriendAddApplication } from '@nimsdk/base';

export class ContactViewHolderSection {
  inital: string
  items: ViewItem[]

  constructor(inital: string,
    items: ViewItem[]) {
    this.inital = inital
    this.items = items
  }
}

@Builder
export function ContactItemBuilder(params: NEContactItem) {
  Column() {
    Row() {
      if (params.avatarIcon) {
        Image(params.avatarIcon)
          .width(36)
          .height(36)
          .borderRadius(18)
          .margin({ left: 20 })
      }

      Text(params.title)
        .fontSize(14)
        .fontColor("#333333")
        .height(18)
        .margin({ left: params.avatarIcon ? 16 : 12, right: 12 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (params.unreadCount) {
        Text(params.unreadCount)
          .fontSize(12)
          .fontColor('#ffFFFFFF')
          .textAlign(TextAlign.Center)
          .backgroundColor('#ffF24957')
          .borderRadius(20)
          .height(18)
          .width(18 + (params.unreadCount.toString().length - 1) * 4)
          .margin({ right: 10 })
      }

      Image($r('app.media.arrow_right'))
        .width(4.92)
        .height(9.54)
        .margin({ right: 20 })

    }
    .alignSelf(ItemAlign.Center)
    .height(59)
  }
  .width('100%')
  .height(60)
}

// 跳转页面入口函数
@Builder
export function ContactPageBuilder() {
  ContactPage()
}

@ComponentV2
export struct ContactPage {
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param onUnreadApplicationChange?: (countString?: string) => void = undefined
  @Local viewModel: ContactViewModel = new ContactViewModel()

  loadUnreadApplication = async () => {
    try {
      const unreadCount = await this.viewModel.getUnreadApplication()
      this.headerItems[0].unreadCount = unreadCount
      if (this.onUnreadApplicationChange) {
        this.onUnreadApplicationChange(unreadCount)
      }
    } catch (err) {
      console.error(err)
    }
  }
  @Local headerItems: NEContactItem[] = [
    new NEContactItem($r('app.media.contact_validation_message'), $r('app.string.contact_validation_message'),
      "ValidationMessagePage", undefined, this.loadUnreadApplication),
    new NEContactItem($r('app.media.contact_blocklist'), $r('app.string.contact_blocklist'), "BlockListPage"),
    new NEContactItem($r('app.media.contact_my_teams'), $r('app.string.contact_my_teams'), "MyTeamsPage")
  ]

  @Local selectedIndex: number = 0; // 用于指定字母导航的选择项
  // List组件的scroller控制器：listScroller，用于控制联系人列表的滑动位置
  private listScroller: Scroller = new Scroller()

  loadData = async () => {
    try {
      await this.viewModel.getFriendList()
      await this.loadUnreadApplication()
    } catch (err) {
      console.error(err)
    }
  }

  async aboutToAppear(): Promise<void> {
    ChatKitClient.nim.friendService?.on("onFriendAddApplication", async (application: V2NIMFriendAddApplication) => {
      await this.loadUnreadApplication()
    })

    if (NEFriendUserCache.getInstance().isEmpty()) {
      ContactRepo.listener.on('initFriendCache', this.loadData)
    } else {
      this.loadData()
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.End }) {
        Column() {
          NavigationTitleBuilder({
            title: $r('app.string.contact_title'),
            firstButtonIcon: $r('app.media.nav_search'),
            secondButtonIcon: $r('app.media.nav_add'),
            firstButtonAction: () => {
              this.pathStack.pushPath({ name: "SearchPage" })
            },
            secondButtonAction: () => {
              this.pathStack.pushPath({
                name: "AddFriendPage"
              })
            }
          })

          List() {
            ForEach(this.headerItems, (item: NEContactItem) => {
              ListItem() {
                ContactItemBuilder(item)
              }
              .width('100%')
              .height(60)
              .backgroundColor(Color.White)
              .onClick(() => {
                this.pathStack.pushPath({
                  name: item.routerUrl,
                  onPop: (popInfo: PopInfo) => {
                    this.loadUnreadApplication()
                  }
                })
              })
            })
          }
          .width('100%')
          .height(this.headerItems.length * 61)
          .backgroundColor(Color.White)
          .divider({
            strokeWidth: 1,
            startMargin: 20,
            color: '#F5F8FC'
          })

          List({ scroller: this.listScroller }) {
            LazyForEach(this.viewModel.friendSection, (item: NEContactSection, index) => {
              ListItemGroup({
                header: ListGroupHeader(item.initial)
              }) {
                LazyForEach(item.contacts, (item: NEUserWithFriend, index) => {
                  ListItem() {
                    ViewItemBuilder({
                      avatarItem: new AvatarItem(item.user?.avatar, item.shortName(),
                        AvatarColorUntil.getBackgroundColorById(item.user?.accountId ?? "")),
                      title: item.showName(),
                      itemHeight: 60,
                      titleIconSize: 36,
                      titleFontSize: 14,
                    })
                  }
                  .width('100%')
                  .height(60)
                  .backgroundColor(Color.White)
                  .onClick(() => {
                    this.pathStack.pushPath({
                      name: 'PersonInfoPage',
                      param: item.user?.accountId
                    })
                  })
                }, (item: NEUserWithFriend, index) => item.user?.accountId)
              }
            }, (item: NEContactSection, index) => item.initial)
          }
          .width('100%')
          .margin({ top: 6 })
          .backgroundColor('#EFF1F4')
          .sticky(StickyStyle.Header)
          .cachedCount(7)
          .scrollBar(BarState.Off)
          // 获取联系人列表滑动位置的索引，并将索引通过selectedIndex同步给右侧字母导航
          .onScrollIndex((start: number, end: number, center: number) => {
            this.selectedIndex = start
          })

          if (this.viewModel.friendSection.totalCount() <= 0) {
            CommonEmptyResult({
              tips: $r('app.string.no_friend')
            })
              .backgroundColor(Color.White)
          }
        }
        .width('100%')
        .margin({ bottom: this.headerItems.length * 60 + 58 })
        .backgroundColor('#EFF1F4')

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
    .onDisAppear(() => {
      this.viewModel.onDestroy()
    })
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
    ContactRepo.listener.off('initFriendCache', this.loadData)
  }
}
