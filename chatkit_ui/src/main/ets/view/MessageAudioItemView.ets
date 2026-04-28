/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { getAudioMessageText, getAudioMessageWidth } from '../common/MessageHelper'
import { V2NIMMessageAudioAttachment } from '@nimsdk/base'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { AudioPlayerManager } from '../manager/AudioPlayerManager'
import { ChatConst } from '../constants/ChatConst'
import { MessageItemClick } from './MessageItemClick'

@ComponentV2
export struct MessageAudioItemView {
  @Param
  @Require
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @BuilderParam
  isReceiveStyle: boolean | undefined
  @Local
  receiveSoundIndex: number = 2
  sendSoundImages = [
    $r('app.media.ic_sound_from_1'),
    $r('app.media.ic_sound_from_2'),
    $r('app.media.ic_sound_from_3')
  ]
  @Local
  sendSoundIndex: number = 2
  receiveSoundImages = [
    $r('app.media.ic_sound_to_1'),
    $r('app.media.ic_sound_to_2'),
    $r('app.media.ic_sound_to_3')
  ]
  //定时器id
  intervalId?: number

  aboutToDisappear(): void {
    AudioPlayerManager.instance.stopPlayAll()
  }

  onPlayStart: () => void = () => {
    this.startPlayAni()
  }
  onPlayFinished: () => void = () => {
    clearInterval(this.intervalId)
    this.receiveSoundIndex = 2
    this.sendSoundIndex = 2
  }

  showReceiveStyle(): boolean {
    return this.message.isReceiveMessage() || (this.isReceiveStyle !== undefined && this.isReceiveStyle)
  }

  build() {
    Column() {
      Row() {
        if (this.showReceiveStyle()) {
          Image(this.sendSoundImages[this.sendSoundIndex]).objectFit(ImageFit.Auto).width(28).height(28)
          Text(getAudioMessageText(this.message))
            .margin({ left: 8 }).maxLines(1)
            .fontColor('#ff333333')
            .fontSize(14)
        } else {
          Text(getAudioMessageText(this.message))
            .margin({ right: 8 }).maxLines(1)
            .fontColor('#ff333333')
            .fontSize(14)
          Image(this.receiveSoundImages[this.receiveSoundIndex]).objectFit(ImageFit.Auto).width(28).height(28)
        }
      }
      .justifyContent(this.showReceiveStyle() ? FlexAlign.Start : FlexAlign.End)
      .width(getAudioMessageWidth(this.message))
      .height(ChatConst.audioMessageWidth)

      // 语音转文字加载中
      if (this.message.voiceToTextLoading) {
        Row() {
          LoadingProgress()
            .width(16)
            .height(16)
            .color('#ff666666')
          Text($r('app.string.chat_message_voice_to_text'))
            .fontSize(14)
            .fontColor('#ff666666')
            .margin({ left: 4 })
        }
        .margin({ top: 12 })
        .justifyContent(FlexAlign.Start)
      } else if (this.message.voiceToText && this.message.voiceToText.length > 0) {
        // 语音转文字结果
        Text(this.message.voiceToText)
          .fontSize(16)
          .fontColor('#ff333333')
          .margin({ top: 12 })
          .width('100%')
          .textAlign(TextAlign.JUSTIFY)
          .lineHeight(24)
      }
    }
    .alignItems(this.showReceiveStyle() ? HorizontalAlign.Start : HorizontalAlign.End)
    .margin({
      left: 12,
      top: 4,
      bottom: 4,
      right: 12
    })
    .onClick(() => {
      clearInterval(this.intervalId)
      this.intervalId = undefined
      let audioManager = AudioPlayerManager.instance
      if (this.message.message.attachment) {
        audioManager.avPlayerLive((this.message.message.attachment as V2NIMMessageAudioAttachment).url ?? '',
          this.onPlayStart,
          this.onPlayFinished
        )
      }
    })
    // .gesture(LongPressGesture({ duration: 300 }).onAction((event: GestureEvent) => {
    //   this.onMessageClick?.onItemLongClick?.(event, this.message)
    // }))
    .width(getAudioMessageWidth(this.message))
  }

  startPlayAni() {
    this.intervalId = setInterval(() => {
      if (this.sendSoundIndex === 2) {
        this.sendSoundIndex = 0
      } else {
        this.sendSoundIndex++
      }
      if (this.receiveSoundIndex === 2) {
        this.receiveSoundIndex = 0
      } else {
        this.receiveSoundIndex++
      }
    }, 600);
  }
}