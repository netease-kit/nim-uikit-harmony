/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  CommonConstants,
  NavigationBackBuilder,
  NECommonUtils
} from '@nimkit/common';
import { PushConfigManager } from '@nimkit/chatkit';

// 跳转页面入口函数
@Builder
function PushConfigPageBuilder() {
  PushConfigPage()
}

@ComponentV2
export struct PushConfigPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local pushConfigEnabled: boolean = AppStorage.get(CommonConstants.KEY_SETTING_PUSH_CONFIG_ENABLED) ?? false
  @Local configContent: string = AppStorage.get(CommonConstants.KEY_SETTING_PUSH_CONFIG_CONTENT) ||
  PushConfigManager.getInstance().getDefaultConfig()
  private pushConfigManager: PushConfigManager = PushConfigManager.getInstance()

  saveConfig(): void {
    // 验证配置格式
    if (this.configContent.length > 0) {
      const parsedConfig = this.pushConfigManager.parseConfig(this.configContent)
      if (!parsedConfig) {
        NECommonUtils.showToast($r('app.string.push_config_invalid'))
        return
      }
    }

    // 保存到 AppStorage（持久化）
    AppStorage.set(CommonConstants.KEY_SETTING_PUSH_CONFIG_ENABLED, this.pushConfigEnabled)
    AppStorage.set(CommonConstants.KEY_SETTING_PUSH_CONFIG_CONTENT, this.configContent)

    // 立即同步到 PushConfigManager 和 IMKitConfigCenter
    this.pushConfigManager.setEnabled(this.pushConfigEnabled, this.configContent)

    NECommonUtils.showToast($r('app.string.push_config_save_success'))
    this.pathStack.pop()
  }

  clearConfig(): void {
    this.configContent = ''
  }

  onSwitchChange(isOn: boolean): void {
    this.pushConfigEnabled = isOn
    // 开关变化立即保存并生效
    AppStorage.set(CommonConstants.KEY_SETTING_PUSH_CONFIG_ENABLED, isOn)
    this.pushConfigManager.setEnabled(isOn, this.configContent)
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.push_config_title'),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Scroll() {
          Column({ space: 12 }) {
            // 推送配置生效开关
            Row() {
              Text($r('app.string.push_config_switch_content'))
                .fontSize(16)
                .fontColor('#333333')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.pushConfigEnabled })
                .selectedColor('#337EFF')
                .onChange((isOn: boolean) => {
                  this.onSwitchChange(isOn)
                })
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .borderRadius(8)
            .backgroundColor(Color.White)
            .margin({ left: 20, right: 20 })
            .onClick(() => {
              this.onSwitchChange(!this.pushConfigEnabled)
            })

            // 推送配置参数区域
            Column() {
              Row() {
                Text($r('app.string.push_config_param_title'))
                  .fontSize(16)
                  .fontColor('#333333')
                  .layoutWeight(1)
                Image($r('app.media.ic_clear'))
                  .width(16)
                  .height(16)
                  .onClick(() => {
                    this.clearConfig()
                  })
              }
              .width('100%')
              .height(46)
              .padding({ left: 16, right: 16 })

              TextArea({ text: this.configContent })
                .height(300)
                .fontSize(14)
                .fontColor('#333333')
                .backgroundColor('#F5F5F5')
                .borderRadius(8)
                .padding(12)
                .margin({ left: 16, right: 16, bottom: 16 })
                .onChange((value: string) => {
                  this.configContent = value
                })
            }
            .width('100%')
            .borderRadius(8)
            .backgroundColor(Color.White)
            .margin({ left: 20, right: 20, top: 0 })

            // 保存按钮
            Button($r('app.string.push_config_save'))
              .width('100%')
              .height(44)
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor('#337EFF')
              .borderRadius(8)
              .margin({ left: 20, right: 20, top: 20 })
              .onClick(() => {
                this.saveConfig()
              })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}
