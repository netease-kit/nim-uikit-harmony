/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ConversationIdUtilRepo, ConversationRepo, IMKitConfigCenter,
  LocalConversationRepo, NEFriendUserCache } from '@nimkit/chatkit';
import { ChatKitConfig } from '@nimkit/chatkit_ui';
import { ContactPage } from '@nimkit/contactkit_ui';
import {
  conversationOpenRegistry,
  ConversationOpenIntent,
  ConversationOpenSource,
  ConversationPage,
  ConversationRouteKey,
  ConversationRouteKind,
  LocalConversationPage
} from '@nimkit/conversationkit_ui';
import {
  adaptiveWindowManager,
  AdaptiveLayoutDecision,
  AdaptiveLayoutMode,
  AdaptiveRegionRole,
  AdaptiveWindowSnapshot,
  resolveAdaptiveLayout
} from '@nimkit/common';
import { V2NIMConversationType, V2NIMFriendAddApplication, V2NIMTeamJoinActionInfo, V2NIMUser } from '@nimsdk/base';
import { resolveShellPresentation, ShellNavigationMode } from '../manager/AdaptiveShellPolicy';
import {
  ConversationNavigationState,
  ensureAdaptiveDetailPlaceholder,
  executeConversationNavigation,
  NavPathStackConversationAdapter,
  openPrimaryDetail,
  reconcileConversationNavigationState,
  resetAdaptiveDetail,
  resolveSelectedConversationId,
  resolveAdaptiveDetailPlaceholderTarget,
  resolveConversationOpenTabIndex,
  shouldReplacePersonCardForConversationOpen,
  shouldResetAdaptiveDetailForConversationOpen
} from '../manager/ConversationNavigationCoordinator';
import { MinePage } from '../mine/pages/MinePage';
import { resolveMineAvatarPreloadUrl, resolveMineUser } from '../mine/viewmodel/MineProfileUtils';
import { StartupPerfDebugTimer } from '../uitrace/StartupPerfDebugTimer';

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
  private conversationNavigationStack: NavPathStackConversationAdapter =
    new NavPathStackConversationAdapter(this.pathStack)
  @Local windowSnapshot: AdaptiveWindowSnapshot = adaptiveWindowManager.state.getSnapshot()
  @Local conversationNavigationState: ConversationNavigationState = new ConversationNavigationState()
  @Local currentIndex: number = 0;
  @Local hasVisitedContactTab: boolean = false;
  @Local hasVisitedMineTab: boolean = false;
  @Local mineAvatarPreloadUrl: string = '';
  @Local mineAvatarPreloadFinished: boolean = false;
  @Local tabs: Array<TabBarItem> = [
    new TabBarItem($r('app.string.tab_conversation'), 0, $r('app.media.tab_conversation'),
      $r('app.media.tab_conversation_light')),
    new TabBarItem($r('app.string.tab_contact'), 1, $r('app.media.tab_contact'), $r('app.media.tab_contact_light')),
    new TabBarItem($r('app.string.tab_mine'), 2, $r('app.media.tab_mine'), $r('app.media.tab_mine_light'))
  ];
  @Local useLocalConversation: boolean = IMKitConfigCenter.enableLocalConversation;
  private readonly adaptiveWindowListener = (snapshot: AdaptiveWindowSnapshot): void => {
    this.windowSnapshot = snapshot
    ensureAdaptiveDetailPlaceholder(this.conversationNavigationStack, this.isSplitMode(),
      resolveAdaptiveDetailPlaceholderTarget(this.currentIndex))
  }
  private readonly navigationInterception: NavigationInterception = {
    didShow: (): void => {
      this.conversationNavigationState = reconcileConversationNavigationState(
        this.conversationNavigationStack,
        this.conversationNavigationState
      )
    }
  }
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
  onConversationFirstReady = (count: number) => {
    this.logPerf('tab.conversation.first_ready_callback', `count=${count}`)
    StartupPerfDebugTimer.finish('conversation.first_ready', count)
  }
  onConversationFirstStable = (count: number) => {
    this.logPerf('tab.conversation.first_stable_callback', `count=${count}`)
  }
  onMineUserProfileChanged = (users: V2NIMUser[]) => {
    const loginUserId = ChatKitClient.getLoginUserId()
    const mineUser = users.find((user: V2NIMUser) => user.accountId === loginUserId)
    if (mineUser) {
      this.updateMineAvatarPreloadUrl(mineUser)
    }
  }
  //获取会话列表未读数
  loadUnreadMessageCount = async () => {
    this.logPerf('tab.unread_message_count.start', `local=${this.useLocalConversation}`)
    let unreadCount = 0
    try {
      if (this.useLocalConversation) {
        unreadCount = await LocalConversationRepo.getUnreadCountByFilter({ ignoreMuted: true }) ?? 0
      } else {
        unreadCount = await ConversationRepo.getUnreadCountByFilter({ ignoreMuted: true }) ?? 0
      }
    } catch (err) {
      this.logPerf('tab.unread_message_count.failed', `${err}`)
      console.log(err)
    }
    this.tabs[0].showRedPoint = unreadCount > 0
    this.logPerf('tab.unread_message_count.end', `unread=${unreadCount}`)
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

      const routeKind = conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM ?
        ConversationRouteKind.TEAM :
        conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_SUPER_TEAM ?
          ConversationRouteKind.SUPER_TEAM : ConversationRouteKind.P2P
      this.openConversation(new ConversationOpenIntent(
        new ConversationRouteKey(routeKind, conversationId),
        ConversationOpenSource.NOTIFICATION
      ))

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
        this.openConversation(new ConversationOpenIntent(
          new ConversationRouteKey(ConversationRouteKind.P2P, p2pConversationId),
          ConversationOpenSource.NOTIFICATION
        ))
        console.info(`TabIndex: Navigated to P2P chat page for sessionId: ${sessionId}`);
      } else if (sessionType === 'team') {
        // 群会话：sessionId 是群 ID
        const teamConversationId = ConversationIdUtilRepo.teamConversationId(sessionId);
        this.openConversation(new ConversationOpenIntent(
          new ConversationRouteKey(ConversationRouteKind.TEAM, teamConversationId),
          ConversationOpenSource.NOTIFICATION
        ))
        console.info(`TabIndex: Navigated to Team chat page for sessionId: ${sessionId}`);
      }
    }
  }

  async aboutToAppear(): Promise<void> {
    this.pathStack.setInterception(this.navigationInterception)
    this.getUIContext().getHostContext()?.eventHub.on('teamExitResetDetail', this.onTeamExitResetDetail)
    adaptiveWindowManager.state.subscribe(this.adaptiveWindowListener)
    conversationOpenRegistry.setHandler(this.openConversation)
    ensureAdaptiveDetailPlaceholder(this.conversationNavigationStack, this.isSplitMode(),
      resolveAdaptiveDetailPlaceholderTarget(this.currentIndex))
    StartupPerfDebugTimer.mark('tab_index.appear')
    this.logPerf('tab.appear.start', `local=${this.useLocalConversation}`)
    this.refreshMineAvatarPreloadUrl()
    this.preloadMineTab()
    ChatKitClient.nim.userService?.off('onUserProfileChanged', this.onMineUserProfileChanged)
    ChatKitClient.nim.userService?.on('onUserProfileChanged', this.onMineUserProfileChanged)
    this.registerConversationDeletedListener()
    // 监听好友申请
    ChatKitClient.nim.friendService?.on('onFriendAddApplication', async (application: V2NIMFriendAddApplication) => {
      await this.loadUnreadApplication()
    })
    // 监听群验证消息（用例 247：通讯录验证消息未读数为群聊和好友的总和）
    ChatKitClient.nim.teamService?.on('onReceiveTeamJoinActionInfo', async (actionInfo: V2NIMTeamJoinActionInfo) => {
      await this.loadUnreadApplication()
    })
    try {
      this.logPerf('tab.load_unread_application.start')
      await this.loadUnreadApplication()
      this.logPerf('tab.load_unread_application.end')
    } catch (err) {
      this.logPerf('tab.load_unread_application.failed', `${err}`)
      console.log(err)
    }
    this.loadConfig()
    await this.loadUnreadMessageCount()

    // 检查是否有通知点击跳转
    this.checkPendingNotification()
    this.logPerf('tab.appear.end')
  }

  /**
   * 页面显示时检查是否有新的通知跳转（应用已在前台时点击通知）
   */
  onPageShow(): void {
    this.checkPendingNotification()
  }

  aboutToDisappear(): void {
    this.getUIContext().getHostContext()?.eventHub.off('teamExitResetDetail', this.onTeamExitResetDetail)
    adaptiveWindowManager.state.unsubscribe(this.adaptiveWindowListener)
    conversationOpenRegistry.clearHandler(this.openConversation)
    ChatKitClient.nim.userService?.off('onUserProfileChanged', this.onMineUserProfileChanged)
    this.unregisterConversationDeletedListener()
  }

  /** 某个 Tab 的页面内容：Tabs 的 TabContent 与分栏自搭布局共用同一份 */
  @Builder
  tabPageByIndex(index: number) {
            if (!this.shouldBuildTab(index)) {
              Column()
                .width('100%')
                .height('100%')
                .backgroundColor('#F6F8FA')
            } else if (index == 0) {
              if (this.useLocalConversation) {
                LocalConversationPage({
                  pathStack: this.pathStack,
                  onUreadMessageChange: this.onUreadMessageChange,
                  onConversationFirstReady: this.onConversationFirstReady,
                  onConversationFirstStable: this.onConversationFirstStable,
                  onOpenConversation: this.openConversation,
                  onOpenDetail: this.openPrimaryDetailPage,
                  selectedConversationId: this.resolveSelectedConversationId()
                })
              } else {
                ConversationPage({
                  pathStack: this.pathStack,
                  onUreadMessageChange: this.onUreadMessageChange,
                  onConversationFirstReady: this.onConversationFirstReady,
                  onConversationFirstStable: this.onConversationFirstStable,
                  onOpenConversation: this.openConversation,
                  onOpenDetail: this.openPrimaryDetailPage,
                  selectedConversationId: this.resolveSelectedConversationId()
                })
              }

            } else if (index == 1) {
              ContactPage({
                pathStack: this.pathStack,
                onUnreadApplicationChange: this.onUnreadApplicationChange,
                onOpenDetail: this.openPrimaryDetailPage
              })
            } else if (index == 2) {
              MinePage({
                pathStack: this.pathStack,
                onOpenDetail: this.openPrimaryDetailPage
              })
            }
  }

  /** 切换 Tab：单屏走 Tabs.onChange，分栏走自搭竖栏，两者共用这段逻辑 */
  private selectTab(index: number): void {
    if (index !== this.currentIndex) {
      resetAdaptiveDetail(this.conversationNavigationStack, this.isSplitMode(),
        resolveAdaptiveDetailPlaceholderTarget(index))
      this.conversationNavigationState = new ConversationNavigationState()
    }
    this.currentIndex = index
    this.markTabVisited(index)
    this.logPerf('tab.change', `index=${index}`)
  }

  /** 分栏左侧 72vp 竖栏：自搭，避免 Tabs 的 TabContent 按底部安全区收缩 */
  @Builder
  verticalSideBar() {
    Column() {
      ForEach(this.tabs, (item: TabBarItem) => {
        Column() {
          this.TabBarBuilder(item)
        }
        .width('100%')
        .onClick(() => {
          this.selectTab(item.targetIndex)
        })
      }, (item: TabBarItem) => `side_${item.targetIndex}`)
    }
    .width(72)
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    // 与原 Tabs 竖栏一致：图标整体垂直居中
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.White)
    // 竖栏本身没有内容，只需把白色绘制区域向下展开到屏幕底
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  TabBarBuilder(item: TabBarItem) {
    Stack() {
      Column() {
        if (this.isVerticalTabs()) {
          // 红点跟随图标边界，避免被侧栏导航项的尺寸拉远。
          Stack({ alignContent: Alignment.TopEnd }) {
            Image(this.currentIndex === item.targetIndex ? item.selectedIcon : item.normalIcon)
              .size({ width: 28, height: 28 })

            if (item.showRedPoint) {
              Column()
                .width(6)
                .height(6)
                .borderRadius(3)
                .backgroundColor('#F24957')
                .offset({ x: 3, y: -1 })
            }
          }
            .size({ width: 28, height: 28 })
            .margin({ top: 8 })
        } else {
          Image(this.currentIndex === item.targetIndex ? item.selectedIcon : item.normalIcon)
            .size({ width: 28, height: 28 })
            .margin({ top: 8 })
        }

        Text(item.title)
          .fontColor(this.currentIndex === item.targetIndex ? '#337EFF' : '#999999')
          .margin({ top: 4 })
      }
      .justifyContent(FlexAlign.Center)

      if (!this.isVerticalTabs() && item.showRedPoint) {
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
    .alignContent(this.isVerticalTabs() ? Alignment.Center : Alignment.TopEnd)
    .width(this.isVerticalTabs() ? '100%' : 'auto')
    .height(this.isVerticalTabs() ? this.resolvePrimaryNavigationItemHeight() : 'auto')
  }

  build() {
    Navigation(this.pathStack) {
      Stack() {
        if (this.isVerticalTabs()) {
          // 分栏用自搭布局：72vp 竖栏 + 内容区，内容能真正铺到屏幕最底（OMIM-73559）
          Row() {
            this.verticalSideBar()
            Column() {
              // 三个页面都保持挂载，只切换可见性：
              // 与 Tabs 的行为一致（切走再回来不重建页面），否则会话页 ViewModel 会重建、
              // 会话同步状态丢失，表现为底部一直"加载中"且无法翻页（OMIM-73559）
              Stack() {
                ForEach(this.tabs, (item: TabBarItem) => {
                  Column() {
                    this.tabPageByIndex(item.targetIndex)
                  }
                  .width('100%')
                  .height('100%')
                  // 切换动画：与原来纵向 Tabs 一致——上下滑动（当前页归位，其它页滑到上/下一屏）
                  .translate({
                    y: item.targetIndex === this.currentIndex ? 0 :
                      (item.targetIndex > this.currentIndex ? '100%' : '-100%')
                  })
                  .zIndex(item.targetIndex === this.currentIndex ? 1 : 0)
                  // 非当前页不参与点击，避免挡住当前页
                  .hitTestBehavior(item.targetIndex === this.currentIndex ?
                    HitTestMode.Default : HitTestMode.None)
                  .animation({ duration: 250, curve: Curve.EaseInOut })
                }, (item: TabBarItem) => `pane_${item.targetIndex}`)
              }
              .width('100%')
              .height('100%')
              .clip(true)
            }
            .layoutWeight(1)
            .height('100%')
          }
          .width('100%')
          .height('100%')
        } else {
        Tabs({ barPosition: this.isVerticalTabs() ? BarPosition.Start : BarPosition.End, index: this.currentIndex }) {
          ForEach(this.tabs, (item: TabBarItem) => {
            TabContent() {
              this.tabPageByIndex(item.targetIndex)
            }
            .tabBar(this.TabBarBuilder(item))
          })
        }
        .barHeight(this.isVerticalTabs() ? '100%' : 60)
        .barWidth(this.isVerticalTabs() ? 72 : '100%')
        .vertical(this.isVerticalTabs())
        .backgroundColor(this.isVerticalTabs() ? Color.White : '#F6F8FA')
        .barBackgroundColor('#F6F8FA')
        .barPosition(this.isVerticalTabs() ? BarPosition.Start : BarPosition.End)
        .barMode(this.isVerticalTabs() ? BarMode.Scrollable : BarMode.Fixed)
        .onChange((index: number) => {
          this.selectTab(index)
        })
        .scrollable(false)
        }

        this.MineAvatarPreloadBuilder()
      }
      .width('100%')
      // 导航栏内容区会被框架额外收进约 28vp（avoidBottom 报 0，不是安全区），
      // 导致会话列表视口到不了屏幕最底（OMIM-73559）。这里按窗口高度显式给高度。
      // 仅纵向（分栏）时按窗口高度显式给高；横向（底部 Tab）必须保持 100%，
      // 否则内容区会撑高、把底部 Tab 栏压矮
      .height(this.isVerticalTabs() ? this.resolvePrimaryPaneHeightVp() : '100%')
    }
    .backgroundColor(Color.Transparent)
    .mode(this.resolveNavigationMode())
    .navBarWidth(this.resolveNavBarWidth())
    .hideTitleBar(true)
    // 页面根默认避让底部安全区，最底部会露出约 40vp 的窗口白底（OMIM-73559）。
    // 在最外层向底部安全区展开，内容才能真正铺到屏幕最底。
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  MineAvatarPreloadBuilder() {
    if (this.mineAvatarPreloadUrl.length > 0 && !this.mineAvatarPreloadFinished) {
      Image(this.mineAvatarPreloadUrl)
        .width(1)
        .height(1)
        .objectFit(ImageFit.Cover)
        .syncLoad(false)
        .opacity(0)
        .onComplete(() => {
          this.mineAvatarPreloadFinished = true
        })
        .onError(() => {
          this.mineAvatarPreloadFinished = true
        })
        .hitTestBehavior(HitTestMode.None)
    }
  }

  private logPerf(_stage: string, _detail: string = ''): void {
  }

  private markTabVisited(index: number): void {
    if (index === 1) {
      this.hasVisitedContactTab = true
    } else if (index === 2) {
      this.hasVisitedMineTab = true
    }
  }

  private shouldBuildTab(index: number): boolean {
    if (index === 0 || index === this.currentIndex) {
      return true
    }
    if (index === 1) {
      return this.hasVisitedContactTab
    }
    if (index === 2) {
      return this.hasVisitedMineTab
    }
    return false
  }

  private refreshMineAvatarPreloadUrl(): void {
    const loginUserId = ChatKitClient.getLoginUserId()
    this.updateMineAvatarPreloadUrl(resolveMineUser(NEFriendUserCache.mineUserCache?.user, loginUserId))
  }

  private updateMineAvatarPreloadUrl(user: V2NIMUser | undefined): void {
    const loginUserId = ChatKitClient.getLoginUserId()
    const avatarUrl = resolveMineAvatarPreloadUrl(user, loginUserId)
    if (avatarUrl !== this.mineAvatarPreloadUrl) {
      this.mineAvatarPreloadUrl = avatarUrl
      this.mineAvatarPreloadFinished = false
    }
  }

  private preloadMineTab(): void {
    this.hasVisitedMineTab = true
  }

  private openConversation = (intent: ConversationOpenIntent): void => {
    const isSplitMode = this.isSplitMode()
    // 名片页进入聊天：替换名片页，返回时直接回到名单页，避免多退一层
    if (shouldReplacePersonCardForConversationOpen(this.pathStack.getAllPathName())) {
      this.pathStack.pop(false)
    }
    this.currentIndex = resolveConversationOpenTabIndex(this.currentIndex, intent.source)
    if (shouldResetAdaptiveDetailForConversationOpen(isSplitMode, this.conversationNavigationState,
      intent.source)) {
      resetAdaptiveDetail(this.conversationNavigationStack, isSplitMode)
      this.conversationNavigationState = new ConversationNavigationState()
    }
    this.conversationNavigationState = executeConversationNavigation(
      this.conversationNavigationStack,
      this.conversationNavigationState,
      intent,
      !isSplitMode,
      this.onChatRootPop
    )
  }

  /**
   * 会话被删除（如从会话列表左滑删除）时，如果删的正是右栏正在展示的会话，
   * 需要把详情区还原成空态占位页，否则右侧会停在已删除会话的聊天页。
   */
  private registerConversationDeletedListener(): void {
    this.unregisterConversationDeletedListener()
    ChatKitClient.nim.conversationService?.on('onConversationDeleted', this.onConversationDeleted)
    ChatKitClient.nim.localConversationService?.on('onConversationDeleted', this.onConversationDeleted)
  }

  private unregisterConversationDeletedListener(): void {
    ChatKitClient.nim.conversationService?.off('onConversationDeleted', this.onConversationDeleted)
    ChatKitClient.nim.localConversationService?.off('onConversationDeleted', this.onConversationDeleted)
  }

  private onConversationDeleted = (conversationIds: string[]): void => {
    if (!this.isSplitMode() || conversationIds.length === 0) {
      return
    }
    const selectedConversationId = this.resolveSelectedConversationId()
    if (selectedConversationId.length === 0 || !conversationIds.includes(selectedConversationId)) {
      return
    }
    resetAdaptiveDetail(this.conversationNavigationStack, true,
      resolveAdaptiveDetailPlaceholderTarget(this.currentIndex))
    this.conversationNavigationState = new ConversationNavigationState()
  }

  /**
   * 退群/解散/群失效后，kit 层会清空详情栈；清栈不会触发聊天根页的 onPop，
   * 这里由事件驱动恢复右栏占位页，避免右侧空白。
   */
  private onTeamExitResetDetail = (): void => {
    resetAdaptiveDetail(this.conversationNavigationStack, this.isSplitMode(),
      resolveAdaptiveDetailPlaceholderTarget(this.currentIndex))
    this.conversationNavigationState = new ConversationNavigationState()
  }

  private onChatRootPop = (): void => {
    this.conversationNavigationState = new ConversationNavigationState()
    ensureAdaptiveDetailPlaceholder(this.conversationNavigationStack, this.isSplitMode(),
      resolveAdaptiveDetailPlaceholderTarget(this.currentIndex))
  }

  private openPrimaryDetailPage = (info: NavPathInfo): void => {
    const isSplitMode = this.isSplitMode()
    openPrimaryDetail(this.conversationNavigationStack, info, isSplitMode,
      resolveAdaptiveDetailPlaceholderTarget(this.currentIndex))
    this.conversationNavigationState = new ConversationNavigationState()
  }

  private resolveSelectedConversationId(): string {
    return resolveSelectedConversationId(
      this.conversationNavigationState,
      this.isSplitMode(),
      this.pathStack.getAllPathName()
    )
  }

  private isSplitMode(): boolean {
    return this.resolveNavigationMode() === NavigationMode.Split
  }

  private resolveLayoutDecision(): AdaptiveLayoutDecision {
    const activeRole = this.conversationNavigationState.activeKey.length > 0 ?
      AdaptiveRegionRole.DETAIL : AdaptiveRegionRole.MASTER
    return resolveAdaptiveLayout(this.windowSnapshot.widthVp, this.windowSnapshot.heightVp, activeRole)
  }

  /** 主导航栏内容应有的高度（vp）：窗口高度 - 顶部安全区（状态栏），铺到屏幕最底 */
  private resolvePrimaryPaneHeightVp(): number {
    const snapshot = adaptiveWindowManager.state.getSnapshot()
    const height = snapshot.heightVp - snapshot.avoidAreas.topVp
    return height > 0 ? height : 0
  }

  private isVerticalTabs(): boolean {
    return this.resolveLayoutDecision().mode === AdaptiveLayoutMode.EXPANDED
  }

  private resolvePrimaryNavigationItemHeight(): number {
    const decision = this.resolveLayoutDecision()
    return resolveShellPresentation(
      decision.mode,
      this.windowSnapshot.widthVp,
      decision.widthFor(AdaptiveRegionRole.MASTER),
      decision.widthFor(AdaptiveRegionRole.DETAIL)
    ).primaryNavigationItemHeightVp
  }

  private resolveNavigationMode(): NavigationMode {
    const decision = this.resolveLayoutDecision()
    const presentation = resolveShellPresentation(
      decision.mode,
      this.windowSnapshot.widthVp,
      decision.widthFor(AdaptiveRegionRole.MASTER),
      decision.widthFor(AdaptiveRegionRole.DETAIL)
    )
    return presentation.navigationMode === ShellNavigationMode.SPLIT ? NavigationMode.Split : NavigationMode.Stack
  }

  private resolveNavBarWidth(): number {
    const decision = this.resolveLayoutDecision()
    return resolveShellPresentation(
      decision.mode,
      this.windowSnapshot.widthVp,
      decision.widthFor(AdaptiveRegionRole.MASTER),
      decision.widthFor(AdaptiveRegionRole.DETAIL)
    ).navBarWidthVp
  }
}
