/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import audio from '@ohos.multimedia.audio'; // 导入audio模块
import { CommonConstants } from '@nimkit/common';

export class AudioPlayerManager {
  static logTag: string = 'AudioPlayerManager'
  static instance: AudioPlayerManager = new AudioPlayerManager()
  onStart?: () => void
  onFinish?: () => void
  avPlayer?: media.AVPlayer
  //正在播放的URL
  playingUrl?: string
  //audioRender
  audioRenderer?: audio.AudioRenderer

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
          console.debug(`${AudioPlayerManager.logTag}`, 'AVPlayer state idle called.');
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          console.debug(`${AudioPlayerManager.logTag}`, 'AVPlayer state initialized called.');
          avPlayer.prepare();
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          console.debug(`${AudioPlayerManager.logTag}`, 'AVPlayer state prepared called.');
          // avPlayer.audioInterruptMode = audio.InterruptMode.INDEPENDENT_MODE
          avPlayer.play(); // 调用播放接口开始播放
          break;
        case 'playing': // play成功调用后触发该状态机上报
          console.debug(`${AudioPlayerManager.logTag}`, 'AVPlayer state playing called.');
          if (this.onStart) {
            this.onStart()
          }
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.debug(`${AudioPlayerManager.logTag}`, 'AVPlayer state completed called.');
          avPlayer.stop(); //调用播放结束接口
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报
          console.debug(`${AudioPlayerManager.logTag}`, 'AVPlayer state stopped called.');
          avPlayer.reset(); // 调用reset接口初始化avplayer状态
          if (this.onFinish) {
            this.onFinish()
          }
          break;
        case 'released':
          console.debug(`${AudioPlayerManager.logTag}`, 'AVPlayer state released called.');
          break;
        default:
          console.info('AVPlayer state unknown called.');
          break;
      }
    })

    // 监听interrupt
    avPlayer.on('audioInterrupt', (interruptEvent) => {
      console.debug(`${AudioPlayerManager.logTag} audioInterrupt ${interruptEvent}`)
      if (this.onFinish) {
        this.onFinish()
      }
    })
  }

  //设置语言播放设备
  async setAudioPlayDevice() {
    let audioStreamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };

    let audioRendererInfo: audio.AudioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_VOICE_MESSAGE,
      rendererFlags: 0
    };

    let audioRendererOptions: audio.AudioRendererOptions = {
      streamInfo: audioStreamInfo,
      rendererInfo: audioRendererInfo
    };


    this.audioRenderer = await audio.createAudioRenderer(audioRendererOptions)
    let earpieceOpen = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_EARPIECE_MODE)
    console.log(`${AudioPlayerManager.logTag} , earpieceOpen = ${earpieceOpen}`)
    await this.audioRenderer.setDefaultOutputDevice((earpieceOpen ?? true) ? audio.DeviceType.EARPIECE :
    audio.DeviceType.SPEAKER)
    if (this.audioRenderer?.state !== audio.AudioState.STATE_RUNNING) {
      await this.audioRenderer.start()
    }

  }


  // 通过url设置网络地址来实现播放直播码流
  async avPlayerLive(url: string, onStart?: () => void,
    onFinish?: () => void) {
    await this.setAudioPlayDevice()
    // 创建avPlayer实例对象
    if (!this.avPlayer) {
      this.avPlayer = await media.createAVPlayer();
    }

    if (this.onFinish) {
      this.onFinish()
    }

    //重复点击，如果已经播放则停止播放，并返回直接返回
    if (this.playingUrl === url
      && (this.avPlayer?.state === 'prepared' ||
        this.avPlayer?.state === 'playing')) {
      this.playingUrl = undefined
      await this.avPlayer?.reset()
      return
    }

    await this.avPlayer?.reset()
    this.playingUrl = url

    this.onStart = onStart

    this.onFinish = onFinish

    // 创建状态机变化回调函数
    this.setAVPlayerCallback(this.avPlayer);
    this.avPlayer.url = url
  }

  async stopPlayAll() {
    console.log(`${AudioPlayerManager.logTag}, stopPlayAll`)
    if (this.onFinish) {
      this.onFinish()
    }
    await this.avPlayer?.reset()
    await this.audioRenderer?.stop()
    this.audioRenderer = undefined
  }
}