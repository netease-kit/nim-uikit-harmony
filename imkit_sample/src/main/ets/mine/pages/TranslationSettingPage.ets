/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { CommonConstants, NavigationBackBuilder, TranslationLanguageCode } from '@nimkit/common';
import { IMKitConfigCenter } from '@nimkit/chatkit';

@Builder
function TranslationSettingPageBuilder() {
  TranslationSettingPage()
}

@ComponentV2
export struct TranslationSettingPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local targetLanguage: ResourceStr = $r('app.string.translation_lang_zh_chs')
  @Local autoTranslate: boolean = false

  private resolveLanguageLabel(languageCode?: string): ResourceStr {
    switch (languageCode) {
      case TranslationLanguageCode.ZH_CHS:
        return $r('app.string.translation_lang_zh_chs')
      case TranslationLanguageCode.ZH_CHT:
        return $r('app.string.translation_lang_zh_cht')
      case TranslationLanguageCode.EN:
        return $r('app.string.translation_lang_en')
      case TranslationLanguageCode.JA:
        return $r('app.string.translation_lang_ja')
      case TranslationLanguageCode.KO:
        return $r('app.string.translation_lang_ko')
      case TranslationLanguageCode.FR:
        return $r('app.string.translation_lang_fr')
      case TranslationLanguageCode.DE:
        return $r('app.string.translation_lang_de')
      case TranslationLanguageCode.ES:
        return $r('app.string.translation_lang_es')
      case TranslationLanguageCode.RU:
        return $r('app.string.translation_lang_ru')
      case TranslationLanguageCode.PT:
        return $r('app.string.translation_lang_pt')
      case TranslationLanguageCode.IT:
        return $r('app.string.translation_lang_it')
      case TranslationLanguageCode.VI:
        return $r('app.string.translation_lang_vi')
      case TranslationLanguageCode.TH:
        return $r('app.string.translation_lang_th')
      case TranslationLanguageCode.ID:
        return $r('app.string.translation_lang_id')
      default:
        return $r('app.string.translation_lang_zh_chs')
    }
  }

  private refreshSettings(): void {
    const targetLanguage = AppStorage.get<string>(CommonConstants.KEY_SETTING_TRANSLATION_TARGET_LANGUAGE) ??
      TranslationLanguageCode.ZH_CHS
    const autoTranslationEnableTime =
      AppStorage.get<number>(CommonConstants.KEY_SETTING_AUTO_TRANSLATION_ENABLE_TIME) ?? 0
    this.targetLanguage = this.resolveLanguageLabel(targetLanguage)
    this.autoTranslate = autoTranslationEnableTime > 0
    IMKitConfigCenter.translationTargetLanguage = targetLanguage
    IMKitConfigCenter.autoTranslationEnableTime = autoTranslationEnableTime
  }

  aboutToAppear(): void {
    this.refreshSettings()
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.mine_setting_translation'),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Column({ space: 12 }) {
          List({ space: 0 }) {
            ListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text($r('app.string.translation_target_language'))
                    .fontSize(14)
                    .fontColor('#1B1F27')
                    .maxLines(1)
                  Text($r('app.string.translation_target_language_desc'))
                    .fontSize(12)
                    .fontColor('#98A2B3')
                    .maxLines(1)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Row({ space: 8 }) {
                  Text(this.targetLanguage)
                    .fontSize(14)
                    .fontColor('#98A2B3')
                    .maxLines(1)
                  Image($r('app.media.arrow_right'))
                    .width(4.92)
                    .height(9.54)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(Color.White)
            }
            .backgroundColor(Color.White)
            .onClick(() => {
              this.pathStack.pushPath({ name: 'TranslationLanguagePage' })
            })

            ListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text($r('app.string.translation_auto_title'))
                    .fontSize(14)
                    .fontColor('#1B1F27')
                  Text($r('app.string.translation_auto_desc'))
                    .fontSize(12)
                    .fontColor('#98A2B3')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.autoTranslate })
                  .selectedColor('#337EFF')
                  .width(46)
                  .height(28)
                  .onChange((isOpen: boolean) => {
                    this.autoTranslate = isOpen
                    const autoTranslationEnableTime = isOpen ? Date.now() : 0
                    AppStorage.set(CommonConstants.KEY_SETTING_AUTO_TRANSLATION_ENABLE_TIME, autoTranslationEnableTime)
                    IMKitConfigCenter.autoTranslationEnableTime = autoTranslationEnableTime
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(Color.White)
            }
            .backgroundColor(Color.White)
          }
          .divider({ strokeWidth: 1, color: '#E5E7EB' })
          .borderRadius(8)
          .backgroundColor(Color.White)
          .margin({ left: 20, right: 20, top: 0 })
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#EFF1F4')
      .onAppear(() => {
        this.refreshSettings()
      })
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}
