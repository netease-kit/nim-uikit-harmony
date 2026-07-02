/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { Logger } from '@nimkit/common';
import { audio } from '@kit.AudioKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';

const TAG = 'Audio manager';

class Options {
  offset?: number;
  length?: number;
}

let bufferSize: number = 0;
let audioCapture: audio.AudioCapturer | undefined = undefined;
let audioStreamInfo: audio.AudioStreamInfo = {
  samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000, // 采样率
  channels: audio.AudioChannel.CHANNEL_2, // 通道
  sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE, // 采样格式
  encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW // 编码格式
}
let audioCaptureInfo: audio.AudioCapturerInfo = {
  source: audio.SourceType.SOURCE_TYPE_MIC, // 音源类型
  capturerFlags: 0 // 音频采集器标志
}
let audioCaptureOptions: audio.AudioCapturerOptions = {
  streamInfo: audioStreamInfo,
  capturerInfo: audioCaptureInfo
}

export class AudioManager {
  public static instance: AudioManager = new AudioManager()
  file?: fileIo.File

  private constructor() {
    Logger.info('ChatKitUI', 'net ease AudioManager constructor')
    this.setup();
  }

  // 初始化，创建实例，设置监听事件
  setup() {
    // 创建Audio Capture实例
    audio.createAudioCapturer(audioCaptureOptions, (err, capture) => {
      if (err) {
        Logger.error('ChatKitUI', `net ease Invoke createAudioCapture failed, code is ${err.code}, message is ${err.message}`);
        return;
      }
      Logger.info('ChatKitUI', `net ease ${TAG}: create AudioCapture success`);
      audioCapture = capture;
      if (audioCapture !== undefined) {
        // (audioCapture as audio.AudioCapture).on('readData', readDataCallback);
      }
    });
  }

  // 开始一次音频采集
  public start(filePath: string) {
    if (audioCapture !== undefined) {

      // let path = getContext().cacheDir;
      // let filePath = path + '/StarWars10s-2C-48000-4SW.wav';

      let file: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      this.file = file;
      let readDataCallback = (buffer: ArrayBuffer) => {
        let options: Options = {
          offset: bufferSize,
          length: buffer.byteLength
        }
        fileIo.writeSync(file.fd, buffer, options);
        bufferSize += buffer.byteLength;
      }

      audioCapture.on('readData', readDataCallback);

      let stateGroup = [audio.AudioState.STATE_PREPARED, audio.AudioState.STATE_PAUSED, audio.AudioState.STATE_STOPPED];
      if (stateGroup.indexOf((audioCapture as audio.AudioCapturer).state.valueOf()) ===
        -1) { // 当且仅当状态为STATE_PREPARED、STATE_PAUSED和STATE_STOPPED之一时才能启动采集
        Logger.error('ChatKitUI', `net ease  ${TAG}: start failed`);
        return;
      }

      // 启动采集
      (audioCapture as audio.AudioCapturer).start((err: BusinessError) => {
        if (err) {
          Logger.error('ChatKitUI', 'net ease Capture start failed.');
        } else {
          Logger.info('ChatKitUI', 'net ease Capture start success.');
        }
      });
    }
  }

  // 停止采集
  public stop(callback: AsyncCallback<boolean>) {
    if (audioCapture !== undefined && this.file != null) {
      // 只有采集器状态为STATE_RUNNING或STATE_PAUSED的时候才可以停止
      if ((audioCapture as audio.AudioCapturer).state.valueOf() !== audio.AudioState.STATE_RUNNING &&
        (audioCapture as audio.AudioCapturer).state.valueOf() !== audio.AudioState.STATE_PAUSED) {
        Logger.info('ChatKitUI', 'net ease Capture is not running or paused');
        return;
      }

      //停止采集
      (audioCapture as audio.AudioCapturer).stop((err: BusinessError) => {
        if (err) {
          Logger.error('ChatKitUI', 'net ease Capture stop failed.');
          if (callback) {
            callback(err, false);
          }
        } else {
          fileIo.close(this.file);
          Logger.info('ChatKitUI', 'net ease Capture stop success.');
          if (callback) {
            callback(err, true);
          }
        }
      });
    }
  }

  // 销毁实例，释放资源
  release() {
    if (audioCapture !== undefined) {
      // 采集器状态不是STATE_RELEASED或STATE_NEW状态，才能release
      if ((audioCapture as audio.AudioCapturer).state.valueOf() === audio.AudioState.STATE_RELEASED ||
        (audioCapture as audio.AudioCapturer).state.valueOf() === audio.AudioState.STATE_NEW) {
        Logger.info('ChatKitUI', 'net ease Capture already released');
        return;
      }

      //释放资源
      (audioCapture as audio.AudioCapturer).release((err: BusinessError) => {
        if (err) {
          Logger.error('ChatKitUI', 'net ease Capture release failed.');
        } else {
          Logger.info('ChatKitUI', 'net ease Capture release success.');
        }
      });
    }
  }
}




