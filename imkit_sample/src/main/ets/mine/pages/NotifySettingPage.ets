/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ViewItemSwitch } from '@nimkit/common';
import {
  CommonConstants,
  NavigationBackBuilder,
  ViewItemBuilder
} from '@nimkit/common';
import { SettingRepo } from '@nimkit/chatkit';
import { V2NIMDndConfig } from '@nimsdk/base';

// 跳转页面入口函数
@Builder
function NotifySettingPageBuilder() {
  NotifySettingPage()
}

const TAG = '[NotifySettingPage]'

@ComponentV2
export struct NotifySettingPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local notifyEnable: boolean = true
  @Local showDetailEnable: boolean = true
  @Local ringEnabled: boolean = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_NOTIFY_RING) ?? true
  @Local vibrateEnabled: boolean = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_NOTIFY_VIBRATE) ?? true
  @Local isLoading: boolean = true

  aboutToAppear(): void {
    this.loadCurrentSettings()
  }

  /**
   * 从 SDK 加载当前设置状态
   */
  async loadCurrentSettings(): Promise<void> {
    try {
      // 调用 SettingRepo.getDndConfig() 获取当前配置
      const dndConfig = await SettingRepo.getDndConfig()
      if (dndConfig) {
        // 新消息通知：dndOn 为 true 表示开启免打扰（关闭通知），所以需要取反
        if (dndConfig.dndOn !== undefined) {
          this.notifyEnable = !dndConfig.dndOn
        }
        // 通知显示详情
        if (dndConfig.showDetail !== undefined) {
          this.showDetailEnable = dndConfig.showDetail
        }
      }
      // 从 AppStorage 加载本地通知配置
      this.ringEnabled = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_NOTIFY_RING) ?? true
      this.vibrateEnabled = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_NOTIFY_VIBRATE) ?? true
    } catch (error) {
      console.error(TAG, 'loadCurrentSettings failed:', error)
    } finally {
      this.isLoading = false
    }
  }

  /**
   * 上报推送设置到 SDK
   * 每次都同时上报 dndOn 和 showDetail 两个字段
   */
  async savePushSettings(): Promise<void> {
    try {
      const dndOn = !this.notifyEnable
      await SettingRepo.setDndConfig({
        dndOn: dndOn,
        fromH: 0,
        fromM: 0,
        toH: dndOn ? 23 : 0,
        toM: dndOn ? 59 : 0,
        showDetail: this.showDetailEnable
      })
      console.info(TAG, `savePushSettings success: dndOn=${dndOn}, showDetail=${this.showDetailEnable}`)
    } catch (error) {
      console.error(TAG, 'savePushSettings failed:', error)
      // 失败时重新加载配置
      this.refreshDnd()
    }
  }

  /**
   * 切换新消息通知开关
   */
  toggleNotifyEnable(isOpen: boolean): void {
    this.notifyEnable = isOpen
    this.savePushSettings()
  }

  /**
   * 切换通知显示详情开关
   */
  toggleShowDetailEnable(isOpen: boolean): void {
    this.showDetailEnable = isOpen
    this.savePushSettings()
  }

  /**
   * 切换响铃模式开关
   */
  toggleRingEnabled(isOpen: boolean): void {
    this.ringEnabled = isOpen
    AppStorage.set(CommonConstants.KEY_SETTING_NOTIFY_RING, isOpen)
    console.info(TAG, `toggleRingEnabled: ${isOpen}`)
  }

  /**
   * 切换震动模式开关
   */
  toggleVibrateEnabled(isOpen: boolean): void {
    this.vibrateEnabled = isOpen
    AppStorage.set(CommonConstants.KEY_SETTING_NOTIFY_VIBRATE, isOpen)
    console.info(TAG, `toggleVibrateEnabled: ${isOpen}`)
  }

  /**
   * 刷新免打扰配置项
   * 如果 SDK 返回的 dndConfig.dndOn = true,则表示当前用户已经开启了免打扰，所以需要取反。
   */
  private async refreshDnd(): Promise<void> {
    try {
      const dndConfig: V2NIMDndConfig | undefined = await SettingRepo.getDndConfig()
      if (dndConfig) {
        this.notifyEnable = !dndConfig.dndOn
        this.showDetailEnable = !!dndConfig.showDetail
      }
    } catch (error) {
      console.error(TAG, 'refreshDnd failed:', error)
    }
  }

  @Builder
  SectionHeader(title: Resource) {
    Text(title)
      .fontSize(12)
      .fontColor("#999999")
      .margin({ left: 16, bottom: 8, top: 4 })
  }

  @Builder
  SettingToggleItem(item: ViewItemSwitch) {
    ViewItemBuilder(item)
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.mine_setting_notify_title'),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              // 1. 新消息通知
              List() {
                ListItem() {
                  this.SettingToggleItem({
                    title: $r('app.string.mine_setting_notify_enable'),
                    itemHeight: 48,
                    isOpen: this.notifyEnable,
                    switchChange: (isOpen: boolean) => {
                      this.toggleNotifyEnable(isOpen)
                    }
                  })
                }
                .width('100%')
                .height(48)
                .backgroundColor(Color.White)
              }
              .borderRadius(8)
              .backgroundColor(Color.White)
              .margin({ left: 20, right: 20 })

              // 2. 消息提醒方式分组
              Column() {
                this.SectionHeader($r("app.string.mine_setting_notify_mode"))

                List() {
                  // 响铃模式
                  ListItem() {
                    this.SettingToggleItem({
                      title: $r('app.string.mine_setting_notify_ring'),
                      itemHeight: 48,
                      isOpen: this.ringEnabled,
                      switchChange: (isOpen: boolean) => {
                        this.toggleRingEnabled(isOpen)
                      }
                    })
                  }
                  .width('100%')
                  .height(48)
                  .backgroundColor(Color.White)

                  // 震动模式
                  ListItem() {
                    this.SettingToggleItem({
                      title: $r('app.string.mine_setting_notify_vibrate'),
                      itemHeight: 48,
                      isOpen: this.vibrateEnabled,
                      switchChange: (isOn: boolean) => {
                        this.toggleVibrateEnabled(isOn)
                      }
                    })
                  }
                  .width('100%')
                  .height(48)
                  .backgroundColor(Color.White)
                }
                .borderRadius(8)
                .backgroundColor(Color.White)
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 20, right: 20 })

              // 3. 推送设置分组
              Column() {
                this.SectionHeader($r("app.string.mine_setting_push_setting"))

                List() {
                  // 通知栏显示消息详情
                  ListItem() {
                    this.SettingToggleItem({
                      title: $r('app.string.mine_setting_notify_show_detail'),
                      itemHeight: 48,
                      isOpen: this.showDetailEnable,
                      switchChange: (isOpen: boolean) => {
                        this.toggleShowDetailEnable(isOpen)
                      }
                    })
                  }
                  .width('100%')
                  .height(48)
                  .backgroundColor(Color.White)
                }
                .borderRadius(8)
                .backgroundColor(Color.White)
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 20, right: 20 })
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        }
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}
