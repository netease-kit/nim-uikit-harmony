/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ConversationIdUtilRepo, ConversationRepo, IMKitConfigCenter,
  LocalConversationRepo } from '@nimkit/chatkit';
import { ChatKitConfig } from '@nimkit/chatkit_ui/src/main/ets/ChatKitConfig';
import { ContactPage } from '@nimkit/contactkit_ui';
import { ConversationPage, LocalConversationPage } from '@nimkit/conversationkit_ui';
import { V2NIMConversationType, V2NIMFriendAddApplication, V2NIMTeamJoinActionInfo } from '@nimsdk/base';
import { MinePage } from '../mine/pages/MinePage';

@ObservedV2
class TabBarItem {
  title: ResourceStr = '';
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
  /**
   * 加载通讯录验证消息未读数（好友申请 + 群验证）
   * 用例 247：通讯录验证消息未读数为群聊和好友的总和
   */
  loadUnreadApplication = async () => {
    try {
      const friendUnread = await ContactRepo.getAddApplicationUnreadCount()
      const teamUnread = await ChatKitClient.nim.teamService?.getTeamJoinActionInfoUnreadCount() ?? 0
      this.tabs[1].showRedPoint = (friendUnread + teamUnread) > 0
    } catch (err) {
      console.log(err)
    }
  }
  /**
   * 好友申请未读数变化回调
   * 需要重新计算总未读数（好友 + 群验证）
   */
  onUnreadApplicationChange = async (unreadCountString?: string) => {
    await this.loadUnreadApplication()
  }
  //未读消息回调
  onUreadMessageChange = (unreadCount?: number) => {
    this.tabs[0].showRedPoint = (unreadCount ?? 0) > 0
  }
  //获取会话列表未读数
  loadUnreadMessageCount = () => {
     let unreadCount = 0
    if (this.useLocalConversation) {
       unreadCount = LocalConversationRepo.getTotalUnreadCount() ?? 0
    }else {
       unreadCount = ConversationRepo.getTotalUnreadCount() ?? 0
    }

    if (unreadCount) {
      this.tabs[0].showRedPoint = unreadCount > 0
    }
  }
  // 加载配置信息
  loadConfig = () => {
    ChatKitConfig.messageReadState = IMKitConfigCenter.enableReadMessage
  }

  /**
   * 检查并处理通知点击跳转
   * 支持两种参数格式：
   * 1. conversationId + conversationType（本地通知）
   * 2. sessionType + sessionId（华为推送）
   */
  private checkPendingNotification(): void {
    // 首先检查 conversationId 格式（本地通知）
    const conversationId = AppStorage.get<string>('pendingConversationId');
    const conversationType = AppStorage.get<number>('pendingConversationType');

    if (conversationId) {
      // 清除待处理的跳转参数
      AppStorage.delete('pendingConversationId');
      AppStorage.delete('pendingConversationType');

      // 根据会话类型跳转到对应聊天页面
      if (conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        this.pathStack.pushPath({ name: 'ChatP2PPage', param: conversationId });
      } else if (conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM ||
        conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_SUPER_TEAM) {
        this.pathStack.pushPath({ name: 'ChatTeamPage', param: conversationId });
      } else {
        // 默认当作 P2P 处理
        this.pathStack.pushPath({ name: 'ChatP2PPage', param: conversationId });
      }

      console.info(`TabIndex: Navigated to chat page for conversation: ${conversationId}`);
      return;
    }

    // 然后检查 sessionType + sessionId 格式（华为推送）
    const sessionType = AppStorage.get<string>('pendingSessionType');
    const sessionId = AppStorage.get<string>('pendingSessionId');

    if (sessionType && sessionId) {
      // 清除待处理的跳转参数
      AppStorage.delete('pendingSessionType');
      AppStorage.delete('pendingSessionId');
      AppStorage.delete('pendingConversationType');

      // 根据 sessionType 和 sessionId 构建 conversationId 并跳转
      if (sessionType === 'p2p') {
        // P2P 会话：sessionId 是发送者的账号
        const p2pConversationId = ConversationIdUtilRepo.p2pConversationId(sessionId);
        this.pathStack.pushPath({ name: 'ChatP2PPage', param: p2pConversationId });
        console.info(`TabIndex: Navigated to P2P chat page for sessionId: ${sessionId}`);
      } else if (sessionType === 'team') {
        // 群会话：sessionId 是群 ID
        const teamConversationId = ConversationIdUtilRepo.teamConversationId(sessionId);
        this.pathStack.pushPath({ name: 'ChatTeamPage', param: teamConversationId });
        console.info(`TabIndex: Navigated to Team chat page for sessionId: ${sessionId}`);
      }
    }
  }

  async aboutToAppear(): Promise<void> {
    // 监听好友申请
    ChatKitClient.nim.friendService?.on('onFriendAddApplication', async (application: V2NIMFriendAddApplication) => {
      await this.loadUnreadApplication()
    })
    // 监听群验证消息（用例 247：通讯录验证消息未读数为群聊和好友的总和）
    ChatKitClient.nim.teamService?.on('onReceiveTeamJoinActionInfo', async (actionInfo: V2NIMTeamJoinActionInfo) => {
      await this.loadUnreadApplication()
    })
    try {
      await this.loadUnreadApplication()
    } catch (err) {
      console.log(err)
    }
    this.loadConfig()
    this.loadUnreadMessageCount()

    // 检查是否有通知点击跳转
    this.checkPendingNotification()
  }

  /**
   * 页面显示时检查是否有新的通知跳转（应用已在前台时点击通知）
   */
  onPageShow(): void {
    this.checkPendingNotification()
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
      .backgroundColor('#F6F8FA')
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