/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { BreakpointConstants, Logger } from '@nimkit/common';
import { BusinessError } from '@kit.BasicServicesKit';
import { hiAppEvent, hilog } from '@kit.PerformanceAnalysisKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { IMBackgroundTask } from '../constants/IMBackgroundTask';
import { UIObserver } from '../uitrace/UIObserver';
import UITraceLogger from '../uitrace/UITraceLogger';
import { NotificationHelper } from '@nimkit/chatkit';
import { V2NIMConversationType } from '@nimsdk/base';

/**
 * 通知点击跳转参数
 */
interface NotificationParams {
  conversationId?: string;
  conversationType?: number;
}

/**
 * 推送跳转数据结构（从 clickAction.data 解析）
 */
interface PushJumpData {
  sessionType?: string;
  sessionId?: string;
}

export default class IMKitAbility extends UIAbility {
  private windowObj?: window.Window;
  // 待处理的通知跳转参数
  private pendingNotificationParams: NotificationParams | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('Ability onCreate');
    // 处理从通知点击启动的情况
    this.handleNotificationWant(want);
  }

  /**
   * 处理从通知点击进入时的 want 参数
   * 支持两种参数格式：
   * 1. 旧格式：conversationId + conversationType（本地通知）
   * 2. 新格式：sessionType + sessionId（华为推送 clickAction.data）
   */
  private handleNotificationWant(want: Want): void {
    if (!want.parameters) {
      return
    }

    let conversationId: string | undefined
    let conversationType: number | undefined

    // 优先检查旧格式参数（本地通知使用）
    const directConversationId = want.parameters['conversationId'] as string
    const directConversationType = want.parameters['conversationType'] as number

    if (directConversationId) {
      conversationId = directConversationId
      conversationType = directConversationType
      Logger.info(`Notification click (direct): conversationId=${conversationId}, conversationType=${conversationType}`)
    } else {
      // 尝试解析新格式参数（华为推送 clickAction.data）
      // 华为推送的 data 字段会直接作为 want.parameters 的一部分传递
      const sessionType = want.parameters['sessionType'] as string
      const sessionId = want.parameters['sessionId'] as string

      if (sessionType && sessionId) {
        Logger.info(`Notification click (push): sessionType=${sessionType}, sessionId=${sessionId}`)

        // 根据 sessionType 和 sessionId 构建 conversationId
        if (sessionType === 'p2p') {
          conversationType = V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P
          // P2P 会话：sessionId 是发送者的账号，需要用它构建 conversationId
          // 由于此时可能还没登录，我们存储 sessionId，让后续页面处理
          AppStorage.setOrCreate('pendingSessionType', sessionType)
          AppStorage.setOrCreate('pendingSessionId', sessionId)
        } else if (sessionType === 'team') {
          conversationType = V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM
          // 群会话：sessionId 是群 ID
          AppStorage.setOrCreate('pendingSessionType', sessionType)
          AppStorage.setOrCreate('pendingSessionId', sessionId)
        }

        // 同时设置 conversationType 供兼容处理
        if (conversationType !== undefined) {
          AppStorage.setOrCreate('pendingConversationType', conversationType)
        }
        return
      }

      // 尝试从 data 字段解析 JSON（某些情况下 data 是 JSON 字符串）
      const dataStr = want.parameters['data'] as string
      if (dataStr) {
        try {
          const jumpData = JSON.parse(dataStr) as PushJumpData
          if (jumpData.sessionType && jumpData.sessionId) {
            Logger.info(`Notification click (data JSON): sessionType=${jumpData.sessionType}, sessionId=${jumpData.sessionId}`)

            if (jumpData.sessionType === 'p2p') {
              conversationType = V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P
            } else if (jumpData.sessionType === 'team') {
              conversationType = V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM
            }

            AppStorage.setOrCreate('pendingSessionType', jumpData.sessionType)
            AppStorage.setOrCreate('pendingSessionId', jumpData.sessionId)
            if (conversationType !== undefined) {
              AppStorage.setOrCreate('pendingConversationType', conversationType)
            }
            return
          }
        } catch (e) {
          Logger.warn(`Failed to parse push data: ${dataStr}`)
        }
      }
    }

    if (conversationId) {
      // 保存待处理的跳转参数，等页面加载完成后处理
      this.pendingNotificationParams = {
        conversationId: conversationId,
        conversationType: conversationType
      }
      // 通过 AppStorage 传递跳转参数
      AppStorage.setOrCreate('pendingConversationId', conversationId)
      if (conversationType !== undefined) {
        AppStorage.setOrCreate('pendingConversationType', conversationType)
      }
    }
  }

  /**
   * 应用已在前台运行时，点击通知进入
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('Ability onNewWant');
    this.handleNotificationWant(want);
  }

  onDestroy(): void {
    Logger.info('Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability.
    Logger.info('Ability onWindowStageCreate');
    //windowStage.getMainWindow((err: BusinessError<void>, data) => {
    //  this.windowObj = data;
    //  this.updateBreakpoint(this.windowObj.getWindowProperties().windowRect.width);
    //  this.windowObj.on('windowSizeChange', (windowSize: window.Size) => {
    //    this.updateBreakpoint(windowSize.width);
    //  })
    //  if (err.code) {
    //    hilog.info(0x0000, 'testTag', '%{public}s', 'getMainWindow failed');
    //    return;
    //  }
    //  if (deviceInfo.deviceType !== '2in1') {
    //    data.setWindowLayoutFullScreen(true);
    //  }
    //})

    let context = this.context;
    let pathDir = context.filesDir;
    Logger.info('netease Ability onWindowStageCreate', pathDir);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.error('Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      const uiContext: UIContext = windowStage.getMainWindowSync().getUIContext();
      UIObserver.getInstance().onWillClick(uiContext);
      UIObserver.getInstance().onScrollEvent(uiContext);
      UIObserver.getInstance().onNavDestinationSwitch(uiContext);
      UIObserver.getInstance().onRouterPageUpdate(uiContext);
      Logger.info('Succeeded in loading the content.');
    });

    const onTrigger = (curRow: number, curSize: number, holder: hiAppEvent.AppEventPackageHolder) => {
      if (holder == null) {
        UITraceLogger.write('nimkit', 'ApplicationTrack', {'event':'hiAppEvent, holder is null'});
        return;
      }
      let eventPkg: hiAppEvent.AppEventPackage | null = null;
      while ((eventPkg = holder.takeNext()) != null) {
        for (const eventInfo of eventPkg.data) {
          UITraceLogger.write('nimkit', 'ApplicationTrack', {
            'curtRow': curRow,
            'curSize': curSize,
            'event': eventInfo
          });
        }
      }
    };

    hiAppEvent.addWatcher({
      name: 'nim_watcher',
      appEventFilters: [
        {
          domain: 'nimkit',
          eventTypes: [hiAppEvent.EventType.FAULT, hiAppEvent.EventType.BEHAVIOR]
        }
      ],
      triggerCondition: {
        row: 10,
        size: 1000,
        timeOut: 1
      },
      onTrigger: onTrigger
    })
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources.
    Logger.info('Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground.
    Logger.info('Ability onForeground');
    IMBackgroundTask.getInstance().cancelSuspendDelay()
    // 进入前台时清除所有通知和角标
    NotificationHelper.clearAllNotifications()
  }

  onBackground(): void {
    // Ability has back to background.
    Logger.info('Ability onBackground');
    IMBackgroundTask.getInstance().requestSuspendDelay()
  }

  private updateBreakpoint(windowWidth: number): void {
    let windowWidthVp = windowWidth / display.getDefaultDisplaySync().densityPixels;
    let curBp: string = '';
    if (windowWidthVp < BreakpointConstants.BREAKPOINT_SCOPE[2]) {
      curBp = BreakpointConstants.BREAKPOINT_SM;
    } else if (windowWidthVp < BreakpointConstants.BREAKPOINT_SCOPE[3]) {
      curBp = BreakpointConstants.BREAKPOINT_MD;
    } else {
      curBp = BreakpointConstants.BREAKPOINT_LG;
    }
    AppStorage.setOrCreate('currentBreakpoint', curBp);
  }
}