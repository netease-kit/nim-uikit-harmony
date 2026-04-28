/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { CommonConstants, NavigationBackBuilder, TranslationLanguageCode } from '@nimkit/common';
import { IMKitConfigCenter } from '@nimkit/chatkit';

class TranslationLanguageOption {
  label: ResourceStr
  code: TranslationLanguageCode

  constructor(label: ResourceStr, code: TranslationLanguageCode) {
    this.label = label
    this.code = code
  }
}

@Builder
function TranslationLanguagePageBuilder() {
  TranslationLanguagePage()
}

@ComponentV2
export struct TranslationLanguagePage {
  pathStack: NavPathStack = new NavPathStack()
  @Local selectedLanguage: string = AppStorage.get(CommonConstants.KEY_SETTING_TRANSLATION_TARGET_LANGUAGE) ??
    TranslationLanguageCode.ZH_CHS
  private readonly languages: TranslationLanguageOption[] = [
    new TranslationLanguageOption($r('app.string.translation_lang_zh_chs'), TranslationLanguageCode.ZH_CHS),
    new TranslationLanguageOption($r('app.string.translation_lang_zh_cht'), TranslationLanguageCode.ZH_CHT),
    new TranslationLanguageOption($r('app.string.translation_lang_en'), TranslationLanguageCode.EN),
    new TranslationLanguageOption($r('app.string.translation_lang_ja'), TranslationLanguageCode.JA),
    new TranslationLanguageOption($r('app.string.translation_lang_ko'), TranslationLanguageCode.KO),
    new TranslationLanguageOption($r('app.string.translation_lang_fr'), TranslationLanguageCode.FR),
    new TranslationLanguageOption($r('app.string.translation_lang_de'), TranslationLanguageCode.DE),
    new TranslationLanguageOption($r('app.string.translation_lang_es'), TranslationLanguageCode.ES),
    new TranslationLanguageOption($r('app.string.translation_lang_ru'), TranslationLanguageCode.RU),
    new TranslationLanguageOption($r('app.string.translation_lang_pt'), TranslationLanguageCode.PT),
    new TranslationLanguageOption($r('app.string.translation_lang_ar'), TranslationLanguageCode.AR),
    new TranslationLanguageOption($r('app.string.translation_lang_hi'), TranslationLanguageCode.HI),
    new TranslationLanguageOption($r('app.string.translation_lang_vi'), TranslationLanguageCode.VI),
    new TranslationLanguageOption($r('app.string.translation_lang_th'), TranslationLanguageCode.TH),
    new TranslationLanguageOption($r('app.string.translation_lang_id'), TranslationLanguageCode.ID)
  ]

  private saveLanguage(): void {
    AppStorage.set(CommonConstants.KEY_SETTING_TRANSLATION_TARGET_LANGUAGE, this.selectedLanguage)
    IMKitConfigCenter.translationTargetLanguage = this.selectedLanguage
    this.pathStack.pop()
    this.pathStack.replacePath({
      name: 'TranslationSettingPage'
    })
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.translation_target_language_title'),
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
            ForEach(this.languages, (item: TranslationLanguageOption) => {
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
