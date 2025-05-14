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

export default class IMKitAbility extends UIAbility {
  private windowObj?: window.Window;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('Ability onCreate');
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