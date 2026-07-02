/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { AIRepo, ChatKitClient } from '@nimkit/chatkit'
import { V2NIMAIModelCallContent, V2NIMAIModelCallResult, V2NIMAIModelConfigParams, V2NIMProxyAIModelCallParams } from '@nimsdk/base'
import { NECommonUtils } from '@nimkit/common'
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import dataPreferences from '@ohos.data.preferences'

interface LanguageModel {
  language: string
  languageTag: string
  isSelected: boolean
}

const DEFAULT_TRANSLATE_LANGUAGES: string[] = ['英语', '日语', '韩语', '俄语', '法语', '德语']
const AI_TRANSLATE_LANGUAGE_PREFERENCE_NAME = 'NEAITranslate'
const AI_TRANSLATE_LANGUAGE_KEY_PREFIX = 'ai_translate_select_language_'

/**
 * AI 翻译面板组件
 * 对齐 Android AiTranslateView + AiTranslateViewModel
 */
@ComponentV2
export struct AITranslateView {
  @Param onResultClick: (text: string) => void = (_: string) => {}
  @Param onCloseClick: () => void = () => {}
  @Param onTranslateClick: () => string = () => ''
  @Param translateAccountId: string = ''
  @Param loginAccountId: string = ''
  @Param inputText: string = ''
  @Param languages: string[] = []
  @Param resetKey: number = 0
  @Param initialTranslateResult: string = ''
  @Param initialIsLoading: boolean = false
  @Param initialIsResultMode: boolean = false
  @Param onHeightChange: (height: number) => void = (_: number) => {}
  @Param onStateChange: (translateResult: string, isResultMode: boolean, isLoading: boolean) => void =
    (_translateResult: string, _isResultMode: boolean, _isLoading: boolean) => {}
  @Local translateResult: string = ''
  @Local isLoading: boolean = false
  @Local isResultMode: boolean = false
  @Local translateTextHeight: number = 0
  @Local languageList: LanguageModel[] = [
    { language: '英语', languageTag: '英语', isSelected: true },
    { language: '日语', languageTag: '日语', isSelected: false },
    { language: '韩语', languageTag: '韩语', isSelected: false },
    { language: '俄语', languageTag: '俄语', isSelected: false },
    { language: '法语', languageTag: '法语', isSelected: false },
    { language: '德语', languageTag: '德语', isSelected: false }
  ]
  @Local selectIdx: number = 0
  private currentRequestId: string = ''
  private latestInputText: string = ''
  private readonly topLayoutHeight: number = 35
  private readonly dividerHeight: number = 1
  private readonly contentMinHeight: number = 64
  private readonly textLineHeight: number = 20
  private readonly translateTextViewportHeight: number = 40

  @Monitor('inputText')
  onInputTextChange() {
    if (this.inputText === this.latestInputText) {
      return
    }
    this.latestInputText = this.inputText
    if (!this.isLoading) {
      this.toInputStatus(false)
    }
  }

  @Monitor('resetKey')
  onResetKeyChange() {
    this.resetView()
  }

  private proxyCallback = (result: V2NIMAIModelCallResult) => {
    if (result.accountId !== this.translateAccountId || result.requestId !== this.currentRequestId) {
      return
    }
    if (result.code === 200 && result.content) {
      this.translateTextHeight = 0
      this.translateResult = result.content.msg ?? ''
      this.isResultMode = true
      this.notifyHeightChange()
    } else {
      NECommonUtils.showToast($r('app.string.chat_ai_search_error'))
    }
    this.isLoading = false
    this.notifyStateChange()
  }

  aboutToAppear(): void {
    this.reloadLanguages()
    this.translateResult = this.initialTranslateResult
    this.isLoading = this.initialIsLoading
    this.isResultMode = this.initialIsResultMode
    this.latestInputText = this.inputText
    this.notifyHeightChange()
    AIRepo.onProxyAIModelCall(this.proxyCallback)
  }

  aboutToDisappear(): void {
    AIRepo.offProxyAIModelCall(this.proxyCallback)
  }

  onTranslate() {
    const sourceText = this.onTranslateClick()
    this.latestInputText = sourceText
    const text = sourceText.trim()
    if (text.length === 0 || this.translateAccountId.length === 0 || this.isLoading) {
      this.toInputStatus(true)
      return
    }
    if (ChatKitClient.connectBroken()) {
      NECommonUtils.showToast($r('app.string.chat_network_error_tips'))
      return
    }
    this.isLoading = true
    this.notifyStateChange()
    this.currentRequestId = 'translate_' + Date.now()
    const params: V2NIMProxyAIModelCallParams = {
      accountId: this.translateAccountId,
      requestId: this.currentRequestId,
      content: { msg: text, type: 0 } as V2NIMAIModelCallContent,
      modelConfigParams: { temperature: 0.2 } as V2NIMAIModelConfigParams,
      promptVariables: JSON.stringify({ Language: this.getSelectedLanguage() })
    }
    AIRepo.proxyAIModelCall(params).catch(() => {
      this.isLoading = false
      this.notifyStateChange()
      NECommonUtils.showToast($r('app.string.chat_ai_search_error'))
    })
  }

  showLanguageList() {
    if (this.languageList.length <= 0) {
      return
    }
    promptAction.showActionMenu({
      title: $r('app.string.chat_ai_translate_language_title'),
      buttons: this.buildLanguageButtons()
    })
      .then((data: promptAction.ActionMenuSuccessResponse) => {
        if (data.index >= 0 && data.index < this.languageList.length) {
          this.selectLanguage(data.index)
        }
      })
      .catch(() => {
      })
  }

  private selectLanguage(index: number) {
    if (index < 0 || index >= this.languageList.length) {
      return
    }
    for (let i = 0; i < this.languageList.length; i++) {
      this.languageList[i].isSelected = i === index
    }
    this.selectIdx = index
    this.saveSelectedLanguage(this.languageList[index].language)
    this.toInputStatus(true)
  }

  private getLanguageButton(index: number): promptAction.Button {
    const item = this.languageList[index]
    return {
      text: item.languageTag,
      color: item.isSelected ? '#337EFF' : '#000000'
    }
  }

  private buildLanguageButtons(): [promptAction.Button, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?] {
    if (this.languageList.length <= 1) {
      return [this.getLanguageButton(0)]
    }
    if (this.languageList.length === 2) {
      return [this.getLanguageButton(0), this.getLanguageButton(1)]
    }
    if (this.languageList.length === 3) {
      return [this.getLanguageButton(0), this.getLanguageButton(1), this.getLanguageButton(2)]
    }
    if (this.languageList.length === 4) {
      return [this.getLanguageButton(0), this.getLanguageButton(1), this.getLanguageButton(2), this.getLanguageButton(3)]
    }
    if (this.languageList.length === 5) {
      return [this.getLanguageButton(0), this.getLanguageButton(1), this.getLanguageButton(2), this.getLanguageButton(3),
        this.getLanguageButton(4)]
    }
    return [this.getLanguageButton(0), this.getLanguageButton(1), this.getLanguageButton(2), this.getLanguageButton(3),
      this.getLanguageButton(4), this.getLanguageButton(5)]
  }

  onUseResult() {
    if (this.translateResult.length > 0) {
      this.onResultClick(this.translateResult)
    }
    this.translateResult = ''
    this.translateTextHeight = 0
    this.isResultMode = false
    this.notifyStateChange()
    this.notifyHeightChange()
  }

  resetView() {
    this.translateResult = ''
    this.translateTextHeight = 0
    this.isLoading = false
    this.isResultMode = false
    this.currentRequestId = ''
    this.notifyStateChange()
    this.notifyHeightChange()
  }

  private toInputStatus(clear: boolean) {
    if (clear) {
      this.translateResult = ''
      this.translateTextHeight = 0
    }
    this.isResultMode = false
    this.notifyStateChange()
    this.notifyHeightChange()
  }

  private getPanelHeight(): number {
    return this.topLayoutHeight + this.dividerHeight + this.getContentHeight()
  }

  private getContentHeight(): number {
    return this.contentMinHeight
  }

  private getTranslateTextJustifyContent(): FlexAlign {
    if (this.translateTextHeight <= this.textLineHeight + 1) {
      return FlexAlign.Center
    }
    return FlexAlign.Start
  }

  private notifyHeightChange() {
    this.onHeightChange(this.getPanelHeight())
  }

  private notifyStateChange() {
    this.onStateChange(this.translateResult, this.isResultMode, this.isLoading)
  }

  private reloadLanguages() {
    const translateLanguages = this.languages.length > 0 ? this.languages : DEFAULT_TRANSLATE_LANGUAGES
    const savedLanguage = this.getSavedLanguage()
    let selectedIndex = 0
    this.languageList = translateLanguages.map((language: string, index: number): LanguageModel => {
      if (savedLanguage === language) {
        selectedIndex = index
      }
      return {
        language: language,
        languageTag: language,
        isSelected: false
      }
    })
    this.selectIdx = selectedIndex
    this.languageList = this.languageList.map((item: LanguageModel, index: number): LanguageModel => {
      return {
        language: item.language,
        languageTag: item.languageTag,
        isSelected: index === selectedIndex
      }
    })
  }

  private getSelectedLanguage(): string {
    if (this.selectIdx >= 0 && this.selectIdx < this.languageList.length) {
      return this.languageList[this.selectIdx].language
    }
    return DEFAULT_TRANSLATE_LANGUAGES[0]
  }

  private getLanguagePreferenceKey(): string {
    return AI_TRANSLATE_LANGUAGE_KEY_PREFIX + this.loginAccountId
  }

  private getSavedLanguage(): string {
    if (this.loginAccountId.length <= 0) {
      return ''
    }
    try {
      const context = getContext(this) as common.Context
      const preference = dataPreferences.getPreferencesSync(context, { name: AI_TRANSLATE_LANGUAGE_PREFERENCE_NAME })
      const language = preference.getSync(this.getLanguagePreferenceKey(), '')
      return typeof language === 'string' ? language : ''
    } catch (err) {
      return ''
    }
  }

  private saveSelectedLanguage(language: string) {
    if (this.loginAccountId.length <= 0 || language.length <= 0) {
      return
    }
    try {
      const context = getContext(this) as common.Context
      const preference = dataPreferences.getPreferencesSync(context, { name: AI_TRANSLATE_LANGUAGE_PREFERENCE_NAME })
      preference.putSync(this.getLanguagePreferenceKey(), language)
      preference.flush()
    } catch (err) {
    }
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text(this.languageList[this.selectIdx].languageTag)
            .fontSize(12)
            .fontColor('#333333')
            .textAlign(TextAlign.Center)

          Image($r('app.media.ic_down_arr'))
            .width(16)
            .height(16)
            .margin({ left: 1 })
        }
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .border({ width: 1, color: '#D6DAE0', radius: 4 })
        .margin({ left: 12 })
        .onClick(() => { this.showLanguageList() })

        Blank()

        Row() {
          Image($r('app.media.ic_chat_close'))
            .width(16)
            .height(16)
            .fillColor('#999999')
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .margin({ right: 8 })
        .onClick(() => { this.onCloseClick() })
      }
      .width('100%')
      .height(35)

      Divider().width('100%').height(1).color('#EDEDED')

      Row() {
        if (this.translateResult.length <= 0) {
          Text($r('app.string.chat_ai_translate_tips'))
            .fontSize(14)
            .lineHeight(this.textLineHeight)
            .fontColor('#AAAAAA')
            .height(this.textLineHeight)
            .layoutWeight(1)
        } else {
          Scroll() {
            Column() {
              Text(this.translateResult)
                .fontSize(14)
                .lineHeight(this.textLineHeight)
                .fontColor('#333333')
                .width('100%')
                .onAreaChange((_oldValue: Area, newValue: Area) => {
                  this.translateTextHeight = Number(newValue.height) || 0
                })
            }
              .width('100%')
              .constraintSize({ minHeight: this.translateTextViewportHeight })
              .justifyContent(this.getTranslateTextJustifyContent())
          }
          .height(this.translateTextViewportHeight)
          .layoutWeight(1)
        }

        if (this.isLoading) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color('#337EFF')
            .margin({ left: 8, right: 10 })
        }

        if (!this.isResultMode) {
          Text($r('app.string.chat_ai_translate'))
            .fontSize(14)
            .lineHeight(this.textLineHeight)
            .fontColor('#337EFF')
            .height(this.textLineHeight)
            .margin({ left: 8 })
            .onClick(() => { this.onTranslate() })
        } else {
          Row() {
            Text($r('app.string.chat_use_ai_translate'))
              .fontSize(14)
              .lineHeight(this.textLineHeight)
              .fontColor('#337EFF')

            Image($r('app.media.ic_arrow_down_blue'))
              .width(9)
              .height(13)
              .margin({ left: 4 })
          }
            .height(this.textLineHeight)
            .alignItems(VerticalAlign.Center)
            .margin({ left: 8 })
            .onClick(() => { this.onUseResult() })
        }
      }
      .width('100%')
      .height(this.getContentHeight())
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.getPanelHeight())
    .backgroundColor('#F5F5F5')
  }
}
