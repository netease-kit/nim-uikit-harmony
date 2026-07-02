/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  ContactRepo,
  DisposableBag,
  FriendEventRepo,
  IMKitConfigCenter,
  NEUserWithFriend,
  TeamEventRepo
} from '@nimkit/chatkit';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonEmptyResult,
  ListGroupHeader,
  NavigationTitleBuilder,
  NECommonUtils,
  ViewItem,
  ViewItemBuilder
} from '@nimkit/common';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { V2NIMFriendAddApplication, V2NIMTeamJoinActionInfo } from '@nimsdk/base';
import { NEContactItem } from '../model/NEContactItem';
import { NEContactSection } from '../model/NEContactSection';
import { ContactViewModel } from '../viewmodel/ContactViewModel';
import { SubscriptionViewModel } from '../viewmodel/SubscriptionViewModel';

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
        .fontColor('#333333')
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
          .width(18 +
            (params.unreadCount.toString().length - 1) * 4)
          .margin({ right: 10 })
      }

      Image($r('app.media.arrow_right'))
        .width(4.92)
        .height(9.54)
        .margin({ right: 30 })

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
  @Local subscriptViewModel: SubscriptionViewModel = new SubscriptionViewModel()
  @Local isFinishedInit: boolean = false
  @Local headerItems: NEContactItem[] = this.getContactHeaderItems()
  @Local selectedIndex: number = 0; // 用于指定字母导航的选择项
  loadData = async () => {
    try {
      await this.viewModel.getFriendList()
      await this.loadCombinedUnreadCount()
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }
  // List组件的scroller控制器：listScroller，用于控制联系人列表的滑动位置
  private listScroller: Scroller = new Scroller()
  private disposableBag: DisposableBag = new DisposableBag()
  private onFriendAddApplicationChanged = (application: V2NIMFriendAddApplication) => {
    this.loadCombinedUnreadCount()
  }
  private onTeamJoinActionInfoChanged = (actionInfo: V2NIMTeamJoinActionInfo) => {
    this.loadCombinedUnreadCount()
  }
  private onLoadFriendCache = () => {
    this.isFinishedInit = true;
  }

  async aboutToAppear(): Promise<void> {
    this.disposeEventListeners()
    this.disposableBag.addAll([
      FriendEventRepo.onFriendAddApplication(this.onFriendAddApplicationChanged),
      TeamEventRepo.onReceiveTeamJoinActionInfo(this.onTeamJoinActionInfoChanged)
    ])
    ContactRepo.listener.on('loadFriendCache', this.onLoadFriendCache)

    this.loadData()
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
              this.pathStack.pushPath({ name: 'SearchPage' })
            },
            secondButtonAction: () => {
              this.pathStack.pushPath({
                name: 'AddFriendPage'
              })
            }
          })

          List() {
            Repeat<NEContactItem>(this.headerItems).each((obj) => {
              ListItem() {
                ContactItemBuilder(obj.item)
              }
              .width('100%')
              .height(60)
              .backgroundColor(Color.White)
              .onClick(() => {
                this.pathStack.pushPath({
                  name: obj.item.routerUrl,
                  onPop: (popInfo: PopInfo) => {
                    // 返回时刷新合并的未读数
                    this.loadCombinedUnreadCount()
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
                        AvatarColorUntil.getBackgroundColorById(item.user?.accountId ?? '')),
                      title: item.showName(),
                      itemHeight: 60,
                      titleIconSize: 36,
                      titleFontSize: 14,
                      onlineState:
                      (IMKitConfigCenter.enableShownOnlineState ?
                        (this.subscriptViewModel.getOnlineState(item.user?.accountId) ? true : false) : undefined)
                    })
                  }
                  .onAppear(() => {
                    if (IMKitConfigCenter.enableShownOnlineState) {
                      this.subscriptViewModel.subscribeUserStatusBatch([item.user?.accountId ?? ''])
                    }
                  })
                  .onDisAppear(() => {
                    if (IMKitConfigCenter.enableShownOnlineState &&
                      this.subscriptViewModel.hasReachedSubscriptionLimit()) {
                      this.subscriptViewModel.unsubscribeUserStatus([item.user?.accountId ?? ''])
                    }
                  })
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

          if (this.viewModel.friendSection.totalCount() <= 0 && this.isFinishedInit) {
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
          .popupPosition({
            x: 30,
            y:
            (this.viewModel.initalList.length * 16 - 48) / 2
          })
          .margin({ right: 0 })
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
    this.disposeEventListeners()
  }

  private disposeEventListeners(): void {
    this.disposableBag.dispose()
    ContactRepo.listener.off('loadFriendCache', this.onLoadFriendCache)
  }

  private getContactHeaderItems(): NEContactItem[] {
    const items: NEContactItem[] = [
      // 合并的验证消息入口（包含好友验证和群验证）
      new NEContactItem($r('app.media.contact_validation_message'), $r('app.string.contact_validation_message'),
        'ValidationMessagePage', undefined, this.loadCombinedUnreadCount)
    ]
    items.push(
      new NEContactItem($r('app.media.contact_blocklist'), $r('app.string.contact_blocklist'), 'BlockListPage'),
    )
    if (IMKitConfigCenter.enableTeam) {
      items.push(
        new NEContactItem($r('app.media.contact_my_teams'), $r('app.string.contact_my_teams'), 'MyTeamsPage'),
      )
    }
    items.push(
      new NEContactItem($r('app.media.contact_my_bots'), $r('app.string.contact_my_bots'), 'MyBotsPage')
    )
    if (IMKitConfigCenter.enableAI) {
      items.push(
        new NEContactItem($r('app.media.contact_ai_users'), $r('app.string.contact_ai_users'), 'AIUsersPage')
      )
    }
    return items
  }

  /**
   * 加载合并的未读数（好友验证 + 群验证）
   */
  private async loadCombinedUnreadCount() {
    try {
      // 获取好友验证未读数
      const friendUnreadCount = await this.viewModel.getUnreadApplication()
      // 获取群验证未读数
      const teamUnreadCount = await this.viewModel.getUnreadTeamVerify()
      // 合并未读数
      const totalUnreadCount = (Number(friendUnreadCount) || 0) + (Number(teamUnreadCount) || 0)
      const totalUnreadStr = totalUnreadCount > 0 ? String(totalUnreadCount) : undefined
      
      // 更新验证消息入口的未读数
      this.headerItems[0].unreadCount = totalUnreadStr
      
      // 通知 TabIndex 更新底部 Tab 红点
      if (this.onUnreadApplicationChange) {
        this.onUnreadApplicationChange(totalUnreadStr)
      }
    } catch (err) {
      Logger.error('ContactKit', err)
    }
  }
}
