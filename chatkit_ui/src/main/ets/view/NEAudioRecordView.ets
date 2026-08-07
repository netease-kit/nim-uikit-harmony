/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { Logger } from '@nimkit/common';
import { Animator as animator, AnimatorOptions, AnimatorResult } from '@kit.ArkUI';
import { AudioManager } from '../manager/AudioManager';
import { contextConstant } from '@kit.AbilityKit';
import { AudioRecordManager } from '../manager/AudioRecordManager';
import { AudioPlayerManager } from '../manager/AudioPlayerManager';
import { NECommonUtils } from '@nimkit/common';

@Entry
@ComponentV2
export struct NEAudioRecordView {
  audioManager: AudioManager = AudioManager.instance;
  @Param press: boolean = false;
  @Param scaleValue: ScaleOptions = { x: 1, y: 1 };
  @Param shouldStop: boolean = false;
  options: AnimatorOptions = {
    duration: 1500,
    easing: "friction",
    delay: 0,
    fill: "forwards",
    direction: "normal",
    iterations: -1,
    begin: 200.0,
    end: 400.0
  };
  @Local wid: number = 104
  @Local hei: number = 104
  @Local radius: number = 52
  @Local isRecording: boolean = false
  @Local isPreparingRecord: boolean = false
  path: string = ""
  @Param @Require onRecordAudio?: (path: string, duration: number) => void;
  @Param @Require onRecordStart?: () => void;
  @Param @Require onRecordEnd?: () => void;
  duration: number = 0;
  intervalID?: number;
  maxRecordTimer: number = 60;
  private TAG: string = 'net ease Audio Record'
  private backAnimator: AnimatorResult | undefined = undefined

  @Monitor('shouldStop')
  onShouldStopChanged() {
    if (this.shouldStop && this.isPreparingRecord) {
      this.isPreparingRecord = false
      return
    }
    if (this.shouldStop && this.isRecording) {
      Logger.info('ChatKitUI', "net ease record view received stop signal from parent")
      this.endRecord()
      this.isRecording = false
    }
  }

  aboutToAppear(): void {
    this.create()
  }

  create() {
    let _this = this
    this.backAnimator = animator.create({
      duration: 1000,
      easing: "ease",
      delay: 0,
      fill: "forwards",
      direction: "normal",
      iterations: -1,
      begin: 104,
      end: 150
    })
    this.backAnimator.onFinish = () => {
      this.wid = 104
      this.hei = 104
      this.radius = 52
    }
    this.backAnimator.onRepeat = () => {
    }
    this.backAnimator.onCancel = () => {
    }
    this.backAnimator.onFrame = (value: number) => {
      // Logger.info('ChatKitUI', _this.TAG, 'backAnimator onFrame ' + value)
      _this.wid = value
      _this.hei = value
      _this.radius = value / 2.0
    }
  }

  aboutToDisappear() {
    // 由于backAnimator在onframe中引用了this, this中保存了backAnimator，
    // 在自定义组件消失时应该将保存在组件中的backAnimator置空，避免内存泄漏
    this.isPreparingRecord = false
    this.backAnimator = undefined;
  }

  private async prepareAndStartRecord() {
    if (this.isRecording || this.isPreparingRecord) {
      return
    }
    this.isPreparingRecord = true
    try {
      await AudioPlayerManager.instance.stopPlayAll()
    } catch (err) {
      Logger.error('ChatKitUI', "net ease stop audio before record error", err.code, err.message)
    }

    if (!this.isPreparingRecord || this.isRecording) {
      return
    }
    this.startRecord()
  }

  private startRecord() {
    this.isPreparingRecord = false
    Logger.info('ChatKitUI', "net ease record start")
    if (this.backAnimator) {
      this.backAnimator.play()
    }
    this.isRecording = true;
    const context = getContext(this).getApplicationContext();
    context.area = contextConstant.AreaMode.EL1;
    const fileName = Date.now() + '.m4a'
    const filePath = context.databaseDir + '/' + fileName
    this.path = filePath
    AudioRecordManager.instance.startRecordingProcess(filePath)
    if (this.onRecordStart) {
      this.onRecordStart()
    }
    this.duration = 0
    this.intervalID = setInterval(() => {
      Logger.info('ChatKitUI', 'net ease do every 1s. duration ' + this.duration);
      this.duration += 1;
      if (this.duration >= this.maxRecordTimer
        && this.isRecording) {
        this.endRecord()
        this.isRecording = false;
      }
    }, 1000);
  }

  endRecord() {
    Logger.info('ChatKitUI', "net ease record stop " + this.path)
    if (this.intervalID !== undefined) {
      clearInterval(this.intervalID)
      this.intervalID = undefined
    }
    if (this.backAnimator) {
      this.backAnimator.finish()
    }
    // 检查是否被取消
    if (AudioRecordManager.instance.isCancelled()) {
      Logger.info('ChatKitUI', "net ease record was cancelled, skip sending")
      AudioRecordManager.instance.setCancelled(false)
      if (this.onRecordEnd) {
        this.onRecordEnd()
      }
      return
    }
    if (this.path.length > 0 && this.duration > 0) {
      AudioRecordManager.instance.stopRecordingProcess().then(() => {
        if (this.onRecordAudio) {
          Logger.info('ChatKitUI', "net ease on record audio finish " + this.path)
          this.onRecordAudio(this.path, this.duration)
        }
      })
    } else {
      NECommonUtils.showToast($r("app.string.chat_speak_too_short"))
    }
    if (this.onRecordEnd) {
      this.onRecordEnd()
    }
  }

  build() {
    RelativeContainer() {

      Stack()
        .width(this.wid)
        .height(this.hei)
        .borderRadius(this.radius)
        .alignRules({
          middle: { anchor: "__container__", align: HorizontalAlign.Center },
          center: { anchor: "__container__", align: VerticalAlign.Center }
        })
        .scale(this.scaleValue)
        .backgroundColor('#4d518EF8')

      Button()
        .type(ButtonType.Normal)
        .width(104)
        .height(104)
        .linearGradient({
          angle: 163,
          colors: [[0x6AA1FF, 0.11], [0x3479EE, 1.21]]
        })
        .borderRadius(52)
        .alignRules({
          middle: { anchor: "__container__", align: HorizontalAlign.Center },
          center: { anchor: "__container__", align: VerticalAlign.Center }
        })
        .onTouch((event) => {
          if (event.type == TouchType.Down) {
            this.prepareAndStartRecord()
          } else if (event.type == TouchType.Up || event.type == TouchType.Cancel) {
            if (this.isPreparingRecord) {
              this.isPreparingRecord = false
              return
            }
            if (this.isRecording) {
              this.endRecord()
              this.isRecording = false;
            }
          }
        })

      Image($r('app.media.ic_public_record_speaker'))
        .width(34)
        .height(34)
        .alignRules({
          middle: { anchor: "__container__", align: HorizontalAlign.Center },
          center: { anchor: "__container__", align: VerticalAlign.Center }
        })
        .alt($r('app.media.ic_public_record_speaker_press'))
        .hitTestBehavior(HitTestMode.None)

      if (!this.isRecording) {
        Text($r('app.string.chat_audio_tips'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .fontColor($r('app.color.color_chat_desc'))
          .alignRules({
            middle: { anchor: "__container__", align: HorizontalAlign.Center },
            center: { anchor: "__container__", align: VerticalAlign.Bottom }
          })
          .margin({ bottom: 20 })
      }
    }

  }
}
