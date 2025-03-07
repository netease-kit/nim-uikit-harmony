/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ConversationRepo, IMKitConfigCenter } from '@nimkit/chatkit';
import { ChatKitConfig } from '@nimkit/chatkit_ui/src/main/ets/ChatKitConfig';
import { CommonConstants } from '@nimkit/common';
import { ContactPage } from '@nimkit/contactkit_ui';
import { ConversationPage } from '@nimkit/conversationkit_ui';
import { LocalConversationPage } from '@nimkit/localconversationkit_ui';
import { V2NIMFriendAddApplication } from '@nimsdk/base';
import { MinePage } from '../mine/pages/MinePage';

@ObservedV2
class TabBarItem {
  title: ResourceStr = "";
  targetIndex: number = 0;
  @Trace showRedPoint: boolean = false;
  normalIcon: Resource;
  selectedIcon: Resource;

  constructor(title: ResourceStr, targetIndex: number, normalIcon: Resource, selectedIcon: Resource,
    showRedPoint: boolean = false) {
    this.title = title;
    this.targetIndex = targetIndex;
    this.showRedPoint = showRedPoint;
    this.normalIcon = normalIcon;
    this.selectedIcon = selectedIcon;
  }
}

@Entry
@ComponentV2
struct TabIndex {
  pathStack: NavPathStack = new NavPathStack()
  @Local currentIndex: number = 0;
  @Local tabs: Array<TabBarItem> = [
    new TabBarItem($r('app.string.tab_conversation'), 0, $r('app.media.tab_conversation'),
      $r('app.media.tab_conversation_light')),
    new TabBarItem($r('app.string.tab_contact'), 1, $r('app.media.tab_contact'), $r('app.media.tab_contact_light')),
    new TabBarItem($r('app.string.tab_mine'), 2, $r('app.media.tab_mine'), $r('app.media.tab_mine_light'))
  ];
  @Local useLocalConversation: boolean = IMKitConfigCenter.enableLocalConversation;
  loadUnreadApplication = async () => {
    try {
      const unreadCount = await ContactRepo.getAddApplicationUnreadCount()
      this.tabs[1].showRedPoint = unreadCount > 0
    } catch (err) {
      console.log(err)
    }
  }
  onUnreadApplicationChange = (unreadCountString?: string) => {
    this.tabs[1].showRedPoint = unreadCountString !== undefined
  }
  //未读消息回调
  onUreadMessageChange = (unreadCount?: number) => {
    this.tabs[0].showRedPoint = (unreadCount ?? 0) > 0
  }
  //获取会话列表未读数
  loadUnreadMessageCount = () => {
    const unreadCount = ConversationRepo.getTotalUnreadCount()
    if (unreadCount) {
      this.tabs[0].showRedPoint = unreadCount > 0
    }
  }
  // 加载配置信息
  loadConfig = () => {
    let readOrOpen: boolean = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_MESSAGE_READ_OR) ?? true
    ChatKitConfig.messageReadState = readOrOpen
  }

  async aboutToAppear(): Promise<void> {
    ChatKitClient.nim.friendService?.on("onFriendAddApplication", async (application: V2NIMFriendAddApplication) => {
      await this.loadUnreadApplication()
    })
    try {
      await this.loadUnreadApplication()
    } catch (err) {
      console.log(err)
    }
    this.loadConfig()
    this.loadUnreadMessageCount()
  }

  @Builder
  TabBarBuilder(item: TabBarItem) {
    Stack() {
      Column() {
        Image(this.currentIndex === item.targetIndex ? item.selectedIcon : item.normalIcon)
          .size({ width: 28, height: 28 })
          .margin({ top: 8 })

        Text(item.title)
          .fontColor(this.currentIndex === item.targetIndex ? '#337EFF' : '#999999')
          .margin({ top: 4 })
      }
      .justifyContent(FlexAlign.Center)

      if (item.showRedPoint) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor('#F24957')
          .margin({
            top: 7
          })
      }
    }
    .alignContent(Alignment.TopEnd)
  }

  build() {
    Navigation(this.pathStack) {
      Tabs({ barPosition: BarPosition.End, index: 0 }) {
        ForEach(this.tabs, (item: TabBarItem) => {
          TabContent() {
            if (item.targetIndex == 0) {
              if (this.useLocalConversation) {
                LocalConversationPage({
                  pathStack: this.pathStack,
                  onUreadMessageChange: this.onUreadMessageChange
                })
              } else {
                ConversationPage({
                  pathStack: this.pathStack,
                  onUreadMessageChange: this.onUreadMessageChange
                })
              }

            } else if (item.targetIndex == 1) {
              ContactPage({
                pathStack: this.pathStack,
                onUnreadApplicationChange: this.onUnreadApplicationChange
              })
            } else if (item.targetIndex == 2) {
              MinePage({
                pathStack: this.pathStack
              })
            }
          }
          .tabBar(this.TabBarBuilder(item))
        })
      }
      .barHeight(60)
      .backgroundColor("#F6F8FA")
      .barPosition(BarPosition.End)
      .onChange((index: number) => {
        this.currentIndex = index
      })
      .scrollable(false)
    }
    .backgroundColor(Color.Transparent)
    .mode(NavigationMode.Auto)
    .hideTitleBar(true)
  }
}