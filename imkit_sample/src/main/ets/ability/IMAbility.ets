/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger } from '@nimkit/common';
import { LogLevel, NIMInitializeOptions, NIMServiceOptions } from '@nimsdk/base';
import { AppConfig } from '../constants/AppConfig';
import { NimRepository } from './NimRepository';

export default class DefaultAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('Ability onCreate');
    console.warn('------------- 创建NIM实例 --------------')
    // 正式服
    let initializeOptions: NIMInitializeOptions = {
      appkey: AppConfig.appKey,
      logLevel: LogLevel.Debug,
      // ...其他属性
    };

    let serviceOptions: NIMServiceOptions = {
      loginServiceConfig: {
        lbsUrls: ['https://lbs.netease.im/lbs/webconf.jsp'],
        linkUrl: 'weblink.netease.im:443'
      },
      pushServiceConfig: {
        harmonyCertificateName: "DEMO_HMOS_PUSH"
      }
    }
    NimRepository.getInstance(this.context).initNim(initializeOptions, serviceOptions);
  }

  onDestroy(): void {
    Logger.info('Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability.
    Logger.info('Ability onWindowStageCreate');
    let context = this.context;
    let pathDir = context.filesDir;
    Logger.info('netease Ability onWindowStageCreate', pathDir);
    this.context
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.error('Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      Logger.info('Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources.
    Logger.info('Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground.
    Logger.info('Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background.
    Logger.info('Ability onBackground');

  }
}
