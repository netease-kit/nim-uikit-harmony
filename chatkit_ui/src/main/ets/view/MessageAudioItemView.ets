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

  build() {
    Row() {
      if (!this.message.isReceiveMessage()) {
        Text(getAudioMessageText(this.message))
          .margin({ right: 8 }).maxLines(1)
          .fontColor('#ff333333')
          .fontSize(14)
        Image(this.receiveSoundImages[this.receiveSoundIndex]).objectFit(ImageFit.Auto).width(28).height(28)
      } else {
        Image(this.sendSoundImages[this.sendSoundIndex]).objectFit(ImageFit.Auto).width(28).height(28)
        Text(getAudioMessageText(this.message))
          .margin({ left: 8 }).maxLines(1)
          .fontColor('#ff333333')
          .fontSize(14)
      }
    }
    .justifyContent(this.message.isReceiveMessage() ? FlexAlign.Start : FlexAlign.End)
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
    .width(getAudioMessageWidth(this.message))
    .height(ChatConst.audioMessageWidth)
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