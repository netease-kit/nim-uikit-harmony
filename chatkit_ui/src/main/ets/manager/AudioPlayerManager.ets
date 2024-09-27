/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class AudioPlayerManager {
  static instance: AudioPlayerManager = new AudioPlayerManager()
  onStart?: () => void
  onFinish?: () => void
  avPlayer?: media.AVPlayer
  //正在播放的URL
  playingUrl?: string

  private constructor() {
  }

  // 注册avplayer回调函数
  setAVPlayerCallback(avPlayer: media.AVPlayer) {
    // error回调监听函数,当avPlayer在操作过程中出现错误时调用 reset接口触发重置流程
    avPlayer.on('error', (err: BusinessError) => {
      console.error(`Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
      avPlayer.reset(); // 调用reset重置资源，触发idle状态
    })
    // 状态机变化回调函数
    avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报
          console.info('AVPlayer state idle called.');
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          console.info('AVPlayer state initialized called.');
          avPlayer.prepare();
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          console.info('AVPlayer state prepared called.');
          avPlayer.play(); // 调用播放接口开始播放
          break;
        case 'playing': // play成功调用后触发该状态机上报
          console.info('AVPlayer state playing called.');
          if (this.onStart) {
            this.onStart()
          }
          break;
        case 'paused': // pause成功调用后触发该状态机上报
          console.info('AVPlayer state paused called.');
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.info('AVPlayer state completed called.');
          avPlayer.stop(); //调用播放结束接口
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报
          console.info('AVPlayer state stopped called.');
          avPlayer.reset(); // 调用reset接口初始化avplayer状态
          if (this.onFinish) {
            this.onFinish()
          }
          break;
        case 'released':
          console.info('AVPlayer state released called.');
          break;
        default:
          console.info('AVPlayer state unknown called.');
          break;
      }
    })
  }


  // 以下demo为通过url设置网络地址来实现播放直播码流的demo
  async avPlayerLive(url: string, onStart?: () => void,
    onFinish?: () => void) {
    // 创建avPlayer实例对象
    if (!this.avPlayer) {
      this.avPlayer = await media.createAVPlayer();
    } else {
      await this.avPlayer.reset()
    }

    if (this.onFinish) {
      this.onFinish()
    }

    if (this.playingUrl === url) {
      this.playingUrl = undefined
      return
    }
    this.playingUrl = url

    this.onStart = onStart

    this.onFinish = onFinish

    // 创建状态机变化回调函数
    this.setAVPlayerCallback(this.avPlayer);
    this.avPlayer.url = url
  }

  async stopPlayAll() {
    await this.avPlayer?.stop()
  }
}