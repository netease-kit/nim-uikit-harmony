/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { common, Want } from '@kit.AbilityKit'
import {
  AppLanguageCode,
  CommonConstants,
  NavigationBackBuilder,
  NECommonUtils,
  resolveEffectiveAppLanguage
} from '@nimkit/common'
import i18n from '@ohos.i18n'

class AppLanguageOption {
  label: ResourceStr
  code: AppLanguageCode

  constructor(label: ResourceStr, code: AppLanguageCode) {
    this.label = label
    this.code = code
  }
}

@Builder
function AppLanguagePageBuilder() {
  AppLanguagePage()
}

@ComponentV2
export struct AppLanguagePage {
  pathStack: NavPathStack = new NavPathStack()
  @Local selectedLanguage: AppLanguageCode = AppLanguageCode.ZhCN
  private context = getContext(this) as common.UIAbilityContext
  private readonly languages: AppLanguageOption[] = [
    new AppLanguageOption($r('app.string.translation_app_language_zh_cn'), AppLanguageCode.ZhCN),
    new AppLanguageOption($r('app.string.translation_app_language_en_us'), AppLanguageCode.EnUS)
  ]

  aboutToAppear(): void {
    const appLanguage = AppStorage.get<string>(CommonConstants.KEY_SETTING_APP_LANGUAGE)
    if (appLanguage === AppLanguageCode.ZhCN || appLanguage === AppLanguageCode.EnUS) {
      this.selectedLanguage = appLanguage
      return
    }
    try {
      this.selectedLanguage = resolveEffectiveAppLanguage(undefined, i18n.System.getSystemLanguage())
    } catch (e) {
      console.warn(`getSystemLanguage failed: ${e}`)
      this.selectedLanguage = AppLanguageCode.ZhCN
    }
  }

  private saveLanguage(): void {
    AppStorage.set(CommonConstants.KEY_SETTING_APP_LANGUAGE, this.selectedLanguage)
    try {
      i18n.System.setAppPreferredLanguage(this.selectedLanguage)
    } catch (e) {
      console.warn(`setAppPreferredLanguage failed: ${e}`)
    }
    NECommonUtils.showToast($r('app.string.translation_language_switch_success'))
    let applicationContext = this.context.getApplicationContext()
    let want: Want = {
      abilityName: 'IMAbility'
    }
    try {
      applicationContext.restartApp(want)
    } catch (error) {
      console.error(`restartApp fail, error: ${JSON.stringify(error)}`)
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.translation_app_language_title'),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          },
          rightButtonTitle: $r('app.string.translation_save'),
          rightButtonColor: '#337EFF',
          rightButtonAction: () => {
            this.saveLanguage()
          },
          buttonTextWidth: 44
        })

        Column({ space: 12 }) {
          List({ space: 0 }) {
            ForEach(this.languages, (item: AppLanguageOption) => {
              ListItem() {
                Row() {
                  Text(item.label)
                    .fontSize(14)
                    .fontColor('#1B1F27')
                    .layoutWeight(1)
                    .maxLines(1)
                  if (this.selectedLanguage === item.code) {
                    Text('✓')
                      .fontSize(18)
                      .fontColor('#337EFF')
                  }
                }
                .width('100%')
                .height(48)
                .padding({ left: 16, right: 16 })
              }
              .backgroundColor(Color.White)
              .onClick(() => {
                this.selectedLanguage = item.code
              })
            })
          }
          .divider({ strokeWidth: 1, color: '#F5F8FC' })
          .borderRadius(8)
          .backgroundColor(Color.White)
          .margin({ left: 20, right: 20 })
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#EFF1F4')
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}
