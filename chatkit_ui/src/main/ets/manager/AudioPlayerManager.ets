/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import audio from '@ohos.multimedia.audio'; // 导入audio模块
import { sensor } from '@kit.SensorServiceKit';
import { CommonConstants } from '@nimkit/common';
import { IMKitConfigCenter } from '@nimkit/chatkit';

@ObservedV2
export class AudioPlayerManager {
  static logTag: string = 'AudioPlayerManager'
  static instance: AudioPlayerManager = new AudioPlayerManager()
  onStart?: () => void
  onFinish?: () => void
  avPlayer?: media.AVPlayer
  //正在播放的URL
  @Trace playingUrl?: string
  // 正在播放的消息 clientId
  @Trace playingMessageClientId?: string
  //audioRender
  audioRenderer?: audio.AudioRenderer
  // 距离传感器是否已注册
  private isProximitySensorRegistered: boolean = false
  // 当前是否靠近（距离传感器检测）
  private isProximityNear: boolean = false

  private constructor() {
  }

  /**
   * 注册距离传感器监听
   * 当手机靠近耳朵时自动切换到听筒模式，远离时切换回扬声器
   */
  private registerProximitySensor(): void {
    if (this.isProximitySensorRegistered) {
      return
    }

    try {
      sensor.on(sensor.SensorId.PROXIMITY, (data: sensor.ProximityResponse) => {
        // distance: 0 表示靠近，> 0 表示远离
        const isNear = data.distance === 0
        Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag}, proximity sensor: distance=${data.distance}, isNear=${isNear}`)

        if (this.isProximityNear !== isNear) {
          this.isProximityNear = isNear
          this.switchAudioOutputByProximity(isNear)
        }
      }, { interval: 100000000 }) // 100ms 间隔

      this.isProximitySensorRegistered = true
      Logger.info('ChatKitUI', `${AudioPlayerManager.logTag}, proximity sensor registered`)
    } catch (error) {
      const e = error as BusinessError
      Logger.error('ChatKitUI', `${AudioPlayerManager.logTag}, failed to register proximity sensor: ${e.code}, ${e.message}`)
    }
  }

  /**
   * 注销距离传感器监听
   */
  private unregisterProximitySensor(): void {
    if (!this.isProximitySensorRegistered) {
      return
    }

    try {
      sensor.off(sensor.SensorId.PROXIMITY)
      this.isProximitySensorRegistered = false
      this.isProximityNear = false
      Logger.info('ChatKitUI', `${AudioPlayerManager.logTag}, proximity sensor unregistered`)
    } catch (error) {
      const e = error as BusinessError
      Logger.error('ChatKitUI', `${AudioPlayerManager.logTag}, failed to unregister proximity sensor: ${e.code}, ${e.message}`)
    }
  }

  /**
   * 根据距离传感器状态切换音频输出设备
   * @param isNear true: 靠近（切换到听筒），false: 远离（切换到扬声器）
   */
  private async switchAudioOutputByProximity(isNear: boolean): Promise<void> {
    if (!this.audioRenderer) {
      return
    }

    // 听筒模式下，不需要切换（始终保持听筒）
    if (IMKitConfigCenter.enableEarphoneMode) {
      return
    }

    // 扬声器模式下，靠近切听筒，远离切扬声器
    try {
      const deviceType = isNear ? audio.DeviceType.EARPIECE : audio.DeviceType.SPEAKER
      await this.audioRenderer.setDefaultOutputDevice(deviceType)
      Logger.info('ChatKitUI', `${AudioPlayerManager.logTag}, switched audio output to ${isNear ? 'EARPIECE' : 'SPEAKER'} by proximity`)
    } catch (error) {
      const e = error as BusinessError
      Logger.error('ChatKitUI', `${AudioPlayerManager.logTag}, failed to switch audio output: ${e.code}, ${e.message}`)
    }
  }

  // 注册avplayer回调函数
  setAVPlayerCallback(avPlayer: media.AVPlayer) {
    // error回调监听函数,当avPlayer在操作过程中出现错误时调用 reset接口触发重置流程
    avPlayer.on('error', (err: BusinessError) => {
      Logger.error('ChatKitUI', `Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
      avPlayer.reset(); // 调用reset重置资源，触发idle状态
    })
    // 状态机变化回调函数
    avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报
          Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag}`, 'AVPlayer state idle called.');
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag}`, 'AVPlayer state initialized called.');
          avPlayer.prepare();
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag}`, 'AVPlayer state prepared called.');
          // avPlayer.audioInterruptMode = audio.InterruptMode.INDEPENDENT_MODE
          avPlayer.play(); // 调用播放接口开始播放
          break;
        case 'playing': // play成功调用后触发该状态机上报
          Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag}`, 'AVPlayer state playing called.');
          if (this.onStart) {
            this.onStart()
          }
          break;
        case 'completed': // 播放结束后触发该状态机上报
          Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag}`, 'AVPlayer state completed called.');
          avPlayer.stop(); //调用播放结束接口
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报
          Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag}`, 'AVPlayer state stopped called.');
          avPlayer.reset(); // 调用reset接口初始化avplayer状态
          this.clearPlayingTarget()
          if (this.onFinish) {
            this.onFinish()
          }
          break;
        case 'released':
          Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag}`, 'AVPlayer state released called.');
          break;
        default:
          Logger.info('ChatKitUI', 'AVPlayer state unknown called.');
          break;
      }
    })

    // 监听interrupt
    avPlayer.on('audioInterrupt', (interruptEvent) => {
      Logger.debug('ChatKitUI', `${AudioPlayerManager.logTag} audioInterrupt ${interruptEvent}`)
      this.clearPlayingTarget()
      if (this.onFinish) {
        this.onFinish()
      }
    })
  }

  //设置语言播放设备
  async setAudioPlayDevice() {
    let earpieceOpen = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_EARPIECE_MODE)
    if (!this.audioRenderer || this.audioRenderer.state === audio.AudioState.STATE_RELEASED) {
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
    }

    Logger.info('ChatKitUI', `${AudioPlayerManager.logTag} , earpieceOpen = ${earpieceOpen}`)
    await this.audioRenderer.setDefaultOutputDevice((earpieceOpen ?? false) ? audio.DeviceType.EARPIECE :
    audio.DeviceType.SPEAKER)
    if (this.audioRenderer?.state !== audio.AudioState.STATE_RUNNING) {
      await this.audioRenderer.start()
    }

  }

  private clearPlayingTarget() {
    this.playingUrl = undefined
    this.playingMessageClientId = undefined
  }

  isMessagePlaying(messageClientId?: string): boolean {
    return !!messageClientId && this.playingMessageClientId === messageClientId && this.isPlaying()
  }


  // 通过url设置网络地址来实现播放直播码流
  async avPlayerLive(url: string, onStart?: () => void,
    onFinish?: () => void, messageClientId?: string) {
    await this.setAudioPlayDevice()
    // 创建avPlayer实例对象
    if (!this.avPlayer) {
      this.avPlayer = await media.createAVPlayer();
      this.setAVPlayerCallback(this.avPlayer);
    }

    if (this.onFinish) {
      this.onFinish()
    }

    //重复点击，如果已经播放则停止播放，并返回直接返回
    if (this.playingUrl === url
      && (this.avPlayer?.state === 'prepared' ||
        this.avPlayer?.state === 'playing')) {
      this.clearPlayingTarget()
      await this.avPlayer?.reset()
      // 停止播放时注销距离传感器
      this.unregisterProximitySensor()
      return
    }

    await this.avPlayer?.reset()
    this.playingUrl = url
    this.playingMessageClientId = messageClientId

    // 包装 onStart 回调，在播放开始时注册距离传感器
    this.onStart = () => {
      // 注册距离传感器
      this.registerProximitySensor()
      if (onStart) {
        onStart()
      }
    }

    // 包装 onFinish 回调，在播放结束时注销距离传感器
    this.onFinish = () => {
      // 注销距离传感器
      this.unregisterProximitySensor()
      if (onFinish) {
        onFinish()
      }
    }

    this.avPlayer.url = url
  }

  async stopPlayAll() {
    Logger.info('ChatKitUI', `${AudioPlayerManager.logTag}, stopPlayAll`)
    // 注销距离传感器
    this.unregisterProximitySensor()
    if (this.onFinish) {
      this.onFinish()
    }
    this.clearPlayingTarget()
    await this.avPlayer?.reset()
    await this.audioRenderer?.stop()
    this.audioRenderer = undefined
  }

  /**
   * 播放中切换音频输出设备（听筒/扬声器）
   * 用于长按消息切换播放模式时立刻生效
   * @param earphoneMode true: 听筒模式，false: 扬声器模式
   */
  async switchAudioOutputDevice(earphoneMode: boolean): Promise<void> {
    if (!this.audioRenderer || !this.isPlaying()) {
      return
    }

    try {
      // 切换到听筒模式：直接切听筒
      // 切换到扬声器模式：根据当前距离传感器状态决定（靠近则保持听筒，远离则切扬声器）
      let deviceType: audio.DeviceType
      if (earphoneMode) {
        deviceType = audio.DeviceType.EARPIECE
      } else {
        deviceType = this.isProximityNear ? audio.DeviceType.EARPIECE : audio.DeviceType.SPEAKER
      }
      await this.audioRenderer.setDefaultOutputDevice(deviceType)
      Logger.info('ChatKitUI', `${AudioPlayerManager.logTag}, switched audio output to ${deviceType === audio.DeviceType.EARPIECE ? 'EARPIECE' : 'SPEAKER'}`)
    } catch (error) {
      const e = error as BusinessError
      Logger.error('ChatKitUI', `${AudioPlayerManager.logTag}, failed to switch audio output: ${e.code}, ${e.message}`)
    }
  }

  /**
   * 判断是否正在播放
   */
  isPlaying(): boolean {
    return this.avPlayer?.state === 'playing' || this.avPlayer?.state === 'prepared'
  }
}
