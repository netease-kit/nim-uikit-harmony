/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ChatRepo, getMultiLineBody, getMultiLineTitle, IMKitConfigCenter } from '@nimkit/chatkit'
import { NIMMessageInfo } from '../../model/NIMMessageInfo'
import { getAitNodes } from '../../common/MessageHelper'
import { V2NIMMessageType, V2NIMTextTranslationResult } from '@nimsdk/base'
import { NIMEStrAnyObj } from '@nimsdk/base'

interface PersistedTranslationPayload {
  translatedText: string
  translatedTitle?: string
  translatedBody?: string
  targetLanguage: string
  sourceLanguage?: string
  updatedTime: number
}

const TRANSLATION_LOCAL_KEY: string = 'message_translation'
const TRANSLATION_MAX_TEXT_LENGTH: number = 5000
type TranslationFinishedListener = (messageClientId: string) => void

function isUrlLike(text: string): boolean {
  const trimmed = text.trim()
  return trimmed.startsWith('http://') || trimmed.startsWith('https://')
}

function safeParseLocalExtension(localExtension?: string): NIMEStrAnyObj {
  if (!localExtension) {
    return {}
  }
  try {
    const parsed = JSON.parse(localExtension) as NIMEStrAnyObj | null
    return parsed ?? {}
  } catch (_error) {
    return {}
  }
}

export class MessageTranslationService {
  private static _instance: MessageTranslationService | undefined = undefined
  private translationFinishedListeners: TranslationFinishedListener[] = []

  static get instance(): MessageTranslationService {
    return this._instance ?? (this._instance = new MessageTranslationService())
  }

  private constructor() {
  }

  addTranslationFinishedListener(listener: TranslationFinishedListener): void {
    if (!this.translationFinishedListeners.includes(listener)) {
      this.translationFinishedListeners.push(listener)
    }
  }

  removeTranslationFinishedListener(listener: TranslationFinishedListener): void {
    this.translationFinishedListeners = this.translationFinishedListeners.filter((item: TranslationFinishedListener) => {
      return item !== listener
    })
  }

  private notifyTranslationFinished(message: NIMMessageInfo): void {
    const messageClientId = message.message.messageClientId
    this.translationFinishedListeners.forEach((listener: TranslationFinishedListener) => {
      listener(messageClientId)
    })
  }

  private isSupportedMessage(message: NIMMessageInfo): boolean {
    return message.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT || message.isMultiLineMsg
  }

  private getOriginalText(message: NIMMessageInfo): string {
    if (message.isMultiLineMsg) {
      const title = getMultiLineTitle(message.message)
      const body = getMultiLineBody(message.message)
      return title && body ? `${title}\n${body}` : (title || body)
    }
    return message.message.text ?? ''
  }

  private applySuccessResult(message: NIMMessageInfo, _sourceLanguage: string,
    translatedText: string, translatedTitle?: string, translatedBody?: string) {
    message.translationLoading = false
    message.translationFailed = false
    message.translationLanguageMismatch = false
    message.translatedText = translatedText
    message.translatedTitle = translatedTitle
    message.translatedBody = translatedBody
    message.showTranslatedText = true
    message.showOriginalText = true
  }

  private clearRuntimeResult(message: NIMMessageInfo) {
    message.translationLoading = false
    message.translationFailed = false
    message.translatedText = undefined
    message.translatedTitle = undefined
    message.translatedBody = undefined
    message.translationLanguageMismatch = false
    message.showTranslatedText = false
    message.showOriginalText = true
  }

  private getPersistedPayload(message: NIMMessageInfo): PersistedTranslationPayload | undefined {
    const localExtension = safeParseLocalExtension(message.message.localExtension)
    const payload = localExtension[TRANSLATION_LOCAL_KEY] as PersistedTranslationPayload | undefined
    if (!payload || !payload.translatedText) {
      return undefined
    }
    return payload
  }

  private async persistResult(message: NIMMessageInfo, payload: PersistedTranslationPayload): Promise<void> {
    const localExtension = safeParseLocalExtension(message.message.localExtension)
    localExtension[TRANSLATION_LOCAL_KEY] = payload
    const updatedMessage = await ChatRepo.updateMessageLocalExtension(message.message, JSON.stringify(localExtension))
    if (updatedMessage) {
      message.updateMessageStatus(updatedMessage)
    }
  }

  private async persistVisibility(message: NIMMessageInfo): Promise<void> {
    const payload = this.getPersistedPayload(message)
    if (!payload) {
      return
    }
    await this.persistResult(message, payload)
  }

  private async translateChunk(text: string, targetLanguageCode: string): Promise<V2NIMTextTranslationResult | undefined> {
    if (text.trim().length === 0 || isUrlLike(text)) {
      return {
        translatedText: text,
        sourceLanguage: '',
        targetLanguage: targetLanguageCode
      }
    }
    return ChatRepo.translateText({
      text: text,
      targetLanguage: targetLanguageCode
    })
  }

  private async translatePlainText(text: string, targetLanguageCode: string): Promise<V2NIMTextTranslationResult> {
    if (text.length <= TRANSLATION_MAX_TEXT_LENGTH) {
      const result = await this.translateChunk(text, targetLanguageCode)
      if (!result) {
        throw new Error('translate result empty')
      }
      return result
    }

    let translatedText = ''
    let sourceLanguage = ''
    for (let index = 0; index < text.length; index += TRANSLATION_MAX_TEXT_LENGTH) {
      const part = text.substring(index, index + TRANSLATION_MAX_TEXT_LENGTH)
      const result = await this.translateChunk(part, targetLanguageCode)
      if (!result) {
        throw new Error('translate result empty')
      }
      translatedText += result.translatedText
      if (!sourceLanguage && result.sourceLanguage) {
        sourceLanguage = result.sourceLanguage
      }
    }
    return {
      translatedText,
      sourceLanguage,
      targetLanguage: targetLanguageCode
    }
  }

  private async translateTextWithAit(content: string, extension: string | undefined,
    targetLanguageCode: string): Promise<V2NIMTextTranslationResult> {
    const aitNodes = getAitNodes(0, content, extension)
    const translatedSegments: string[] = []
    let sourceLanguage = ''

    for (const node of aitNodes) {
      if (node.segment || node.text.trim().length === 0 || isUrlLike(node.text)) {
        translatedSegments.push(node.text)
        continue
      }
      const result = await this.translatePlainText(node.text, targetLanguageCode)
      translatedSegments.push(result.translatedText)
      if (!sourceLanguage && result.sourceLanguage) {
        sourceLanguage = result.sourceLanguage
      }
    }

    return {
      translatedText: translatedSegments.join(''),
      sourceLanguage,
      targetLanguage: targetLanguageCode
    }
  }

  async hydrate(message: NIMMessageInfo): Promise<void> {
    if (message.translationHydrated || !this.isSupportedMessage(message)) {
      return
    }
    if (!message.isReceiveMessage()) {
      this.clearRuntimeResult(message)
      message.translationHydrated = true
      return
    }

    const payload = this.getPersistedPayload(message)
    if (payload) {
      if (payload.targetLanguage === IMKitConfigCenter.translationTargetLanguage) {
        this.applySuccessResult(
          message,
          payload.sourceLanguage ?? '',
          payload.translatedText,
          payload.translatedTitle,
          payload.translatedBody
        )
      } else {
        this.clearRuntimeResult(message)
        message.translationLanguageMismatch = true
      }
    }
    message.translationHydrated = true
  }

  async prepareMessage(message: NIMMessageInfo): Promise<void> {
    if (!this.isSupportedMessage(message)) {
      return
    }
    await this.hydrate(message)
    const autoTranslationEnableTime = IMKitConfigCenter.autoTranslationEnableTime
    if (autoTranslationEnableTime <= 0 || !message.isReceiveMessage()) {
      return
    }
    if (message.message.createTime < autoTranslationEnableTime) {
      return
    }
    if (message.translationLoading || message.translatedText || message.translationLanguageMismatch) {
      return
    }
    await this.translate(message)
  }

  async translate(message: NIMMessageInfo): Promise<void> {
    if (!this.isSupportedMessage(message) || !message.isReceiveMessage() || message.translationLoading) {
      return
    }
    const targetLanguage = IMKitConfigCenter.translationTargetLanguage
    const targetLanguageCode = targetLanguage
    const originalText = this.getOriginalText(message)
    if (originalText.trim().length === 0) {
      return
    }

    message.translationLoading = true
    message.translationFailed = false

    try {
      let translatedText = ''
      let translatedTitle = ''
      let translatedBody = ''
      let sourceLanguage = ''

      if (message.isMultiLineMsg) {
        const title = getMultiLineTitle(message.message)
        const body = getMultiLineBody(message.message)
        if (title.length > 0) {
          const titleResult = await this.translateTextWithAit(title, message.message.serverExtension, targetLanguageCode)
          translatedTitle = titleResult.translatedText
          sourceLanguage = titleResult.sourceLanguage
        }
        if (body.length > 0) {
          const bodyResult = await this.translateTextWithAit(body, message.message.serverExtension, targetLanguageCode)
          translatedBody = bodyResult.translatedText
          if (!sourceLanguage) {
            sourceLanguage = bodyResult.sourceLanguage
          }
        }
        translatedText = translatedTitle && translatedBody ? `${translatedTitle}\n${translatedBody}` : (translatedTitle || translatedBody)
      } else {
        const result = await this.translateTextWithAit(originalText, message.message.serverExtension, targetLanguageCode)
        translatedText = result.translatedText
        sourceLanguage = result.sourceLanguage
      }

      this.applySuccessResult(message, sourceLanguage, translatedText, translatedTitle, translatedBody)
      await this.persistResult(message, {
        translatedText,
        translatedTitle,
        translatedBody,
        targetLanguage: targetLanguageCode,
        sourceLanguage,
        updatedTime: Date.now()
      })
      this.notifyTranslationFinished(message)
    } catch (_error) {
      message.translationLoading = false
      message.translationFailed = true
      message.showTranslatedText = false
      message.showOriginalText = true
      this.notifyTranslationFinished(message)
    }
  }

  async retry(message: NIMMessageInfo): Promise<void> {
    await this.translate(message)
  }

  hideTranslation(message: NIMMessageInfo): void {
    message.showTranslatedText = false
    message.showOriginalText = true
    this.persistVisibility(message)
  }

  getTranslatedDisplayText(message: NIMMessageInfo): string {
    if (message.isMultiLineMsg) {
      const translatedTitle = message.translatedTitle ?? ''
      const translatedBody = message.translatedBody ?? ''
      if (translatedTitle.length > 0 && translatedBody.length > 0) {
        return `${translatedTitle}\n${translatedBody}`
      }
      return translatedTitle || translatedBody
    }
    return message.translatedText ?? ''
  }
}
