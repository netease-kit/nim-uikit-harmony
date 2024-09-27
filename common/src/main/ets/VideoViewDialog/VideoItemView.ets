/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';
import window from '@ohos.window';
import { getTimeString } from '../utils/TimeUtils';
import fileIo from '@ohos.file.fs';

// 倍速对象
interface speedObj {
  text: string,
  value: number
};

const WINDOW_SYSTEM_BAR: Array<'status' | 'navigation'> = ['navigation', 'status'];
const LAYOUT_WEIGHT: number = 1; // 自动分配剩余空间
const VIDEO_Z_INDEX: number = 100; // 组件zIndex
const ANIMATE_DURATION: number = 400; // 动画持续时间
const SPEED_POPUP_LIST_SPACE: number = 20;


class AVPlayerConstants {
  // 倍速
  static readonly SPEED_ARRAY: speedObj[] = [
    {
      text: '0.75x', value: 0
    },
    {
      text: '1.0x', value: 1
    },
    {
      text: '1.25x', value: 2
    },
    {
      text: '1.75x', value: 3
    },
    {
      text: '2.0x', value: 4
    }];
}

@Component
export struct VideoItemView {
  @State currentTime: number = 0; // 视频当前时间
  @State totalDuration: number = 0; // 视频总时长
  @State videoRatio: number = 0; // 元素宽高比
  @State @Watch('onChangePlay') isPlaying: boolean = false; // 是否播放状态
  @State @Watch('changeOrientation') isLandscape: boolean = false; // 是否横屏状态
  @State isSpeedShow: boolean = false; // 是否倍速状态
  @State showFullScreen: boolean = false; // 是否展示全屏按钮
  @State showSpeed: boolean = false; // 是否展示倍速按钮
  @State speed: string = '1.0x'; // 倍速大小
  @State @Watch('createOrFinish') videoUrl: string = ''; // 视频url
  @State topRectHeight: number = 0; // 系统状态栏高度
  @State bottomRectHeight: number = 0; // 系统状态栏高度
  private avPlayer: media.AVPlayer = {} as media.AVPlayer; // 视频播放器对象
  private surfaceID: string | undefined = undefined; // 视频播放器ID
  private isCreate: boolean = false; // 视频播放器是否被创建
  private xComponentController: XComponentController = new XComponentController();

  aboutToAppear() {
    // 获取系统状态栏高度
    window.getLastWindow(getContext(this)).then((lastWindow) => {
      const areas = lastWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topRectHeight = px2vp(areas.topRect.height);
      this.bottomRectHeight = px2vp(areas.bottomRect.height);
    });
    // 设置播放状态
    this.setCompleteCallback(() => {
      console.log('completed state called')
      this.isPlaying = !this.isPlaying
    });
    // 时间上报函数
    this.setTimeUpdateCallback((time) => {
      this.currentTime = time
    });
    this.init()
  }

  aboutToDisappear() {
    this.release();
    this.isLandscape = false;
  }

  // 初始化AVPlayer
  async init(): Promise<void> {
    await this.release();
    const context = getContext(this);
    // 获取fdSrc用于注册AVPlayer
    // context.resourceManager.getRawFd(this.fileName).then(async (value: resourceManager.RawFileDescriptor) => {
    //   this.avPlayer = await media.createAVPlayer();
    //   this.isCreate = true;
    //   await this.setSourceInfo(); // 视频信息上报函数
    //   await this.setStateChangeCallback(); // 状态机上报回调函数
    //   this.avPlayer.fdSrc = {
    //     fd: value.fd,
    //     offset: value.offset,
    //     length: value.length
    //   };
    // });

    // 创建avPlayer实例对象
    this.avPlayer = await media.createAVPlayer();
    this.isCreate = true
    // 创建状态机变化回调函数
    await this.setSourceInfo(); // 视频信息上报函数
    await this.setStateChangeCallback(); // 状态机上报回调函数
    let fd: number = fileIo.openSync(this.videoUrl, 0o0).fd;
    this.avPlayer.fdSrc = {
      fd: fd
    }
  }

  // 创建或注销AVPlayer
  createOrFinish(): void {
    if (this.videoUrl !== '') {
      this.init();
    } else {
      this.getStop();
      this.release();
    }
  }

  // 释放AVPlayer资源
  async release() {
    if (this.isCreate) {
      await this.avPlayer.release();
      this.isCreate = false;
      this.isPlaying = false;
    }
  }

  getPlay() {
    if (this.isCreate) {
      this.avPlayer.play();
    }
  }

  getPause() {
    if (this.isCreate) {
      this.avPlayer.pause();
    }
  }

  getStop() {
    if (this.isCreate) {
      this.avPlayer.stop();
    }
  }

  // XComponent和AVPlayer通过surfaceId绑定
  setSurfaceID(): void {
    console.log('play video: surfaceID is:' + this.surfaceID);
    this.avPlayer.surfaceId = this.surfaceID;
  }

  setCompleteCallback(func: () => void) {
    this.callbackComplete = func;
  }

  setTimeUpdateCallback(func: (nol: number) => void) {
    this.callbackTimeUpdate = func;
  }

  setBitrateUpdateCallback(func: (bitrateList: number[]) => void) {
    this.callbackBitrateUpdate = func;
  }

  setErrorCallback(func: (error: string) => void) {
    this.callbackErrorUpdate = func;
  }

  // 视频信息上报函数
  async setSourceInfo(): Promise<void> {
    // 时间上报函数
    this.avPlayer.on('timeUpdate', (time: number) => {
      console.log('timeUpdate called: time is :' + time);
      console.log('timeUpdate called: currentTime is :' + this.avPlayer.currentTime);
      this.callbackTimeUpdate(time);
    });
    // 音量变化回调函数
    this.avPlayer.on('volumeChange', (vol: number) => {
      console.log('volumeChange success,and new volume is :' + vol);
    });
    // 视频播放结束触发回调
    this.avPlayer.on('endOfStream', () => {
      console.log('endOfStream success');
    });
    // seek操作回调函数
    this.avPlayer.on('seekDone', (seekDoneTime: number) => {
      console.log('seekDone success,and seek time is:' + seekDoneTime);
    });
    // 视频总时长上报函数
    this.avPlayer.on('durationUpdate', (duration: number) => {
      console.log('durationUpdate success,and durationUpdate is:' + duration);
    });
    // 设置倍速播放回调函数
    this.avPlayer.on('speedDone', (speed: number) => {
      console.log('speedDone success,and speed value is:' + speed);
    });
    // bitrate设置成功回调函数
    this.avPlayer.on('bitrateDone', (bitrate: number) => {
      console.log('bitrateDone success,and bitrate value is:' + bitrate);
    });
    // 缓冲上报回调函数
    this.avPlayer.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      console.log('bufferingUpdate success,and infoType value is:' + infoType + ', value is :' + value);
    });
    // 首帧上报回调函数
    this.avPlayer.on('startRenderFrame', () => {
      console.log('startRenderFrame success 1');
    });
    // 视频宽高上报回调函数
    this.avPlayer.on('videoSizeChange', (width: number, height: number) => {
      this.videoRatio = width / height
      console.log('videoSizeChange success,and width is:' + width + ', height is :' + height);
    });
    // 焦点上报回调函数
    this.avPlayer.on('audioInterrupt', (info: audio.InterruptEvent) => {
      // 触发焦点上报后调用暂停接口暂停播放
      console.log('audioInterrupt success,and InterruptEvent info is:' + JSON.stringify(info));
    });
    // HLS上报所有支持的比特率
    this.avPlayer.on('availableBitrates', (bitrates: number[]) => {
      console.log('availableBitrates success,and availableBitrates length is:' + bitrates.length);
      this.callbackBitrateUpdate(bitrates);
    });
    // 设置错误监听
    this.avPlayer.on('error', (error) => {
      console.log('error happened,message is :' + error.message);
      this.callbackErrorUpdate('Error ' + error.code + ' - ' + error.message);
    });
  }

  // 状态机上报回调函数
  async setStateChangeCallback(): Promise<void> {
    this.avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      console.log('stateChange callback function is triggered,state is:' + state + ',reason is :' + reason);
      switch (state) {
        case 'idle':
          this.release();
          console.log('state idle called');
          break;
        case 'initialized':
          console.log('state initialized called');
          this.setSurfaceID();
          this.avPlayer.prepare();
          break;
        case 'prepared':
          console.log('state prepared called');
          this.isPlaying = true;
          this.totalDuration = this.avPlayer.duration;
          this.getPlay();
          // 设置全屏播放展开动画
          animateTo({
            duration: ANIMATE_DURATION,
            onFinish: () => {
              this.isLandscape = false; // 设置横屏
            }
          }, () => {
          });
          break;
        case 'playing':
          console.log('state playing called');
          break;
        case 'paused':
          console.log('state paused called');
          break;
        case 'completed':
          console.log('state completed called');
          this.callbackComplete();
          break;
        case 'stopped':
          console.log('state stopped called');
          break;
        case 'released':
          console.log('state released called');
          break;
        case 'error':
          console.log('state error called');
          break;
        default:
          console.log('unknown state :' + state);
          break;
      }
    })
  }

  // isPlaying状态变化时调用
  onChangePlay() {
    this.isPlaying ? this.getPlay() : this.getPause();
  }

  changeOrientation() {
    // 获取UIAbility实例的上下文信息
    let context = getContext(this);
    // 调用该接口手动改变设备横竖屏状态（设置全屏模式，先强制横屏，再加上传感器模式）
    window.getLastWindow(context).then((lastWindow) => {
      if (this.isLandscape) {
        // 设置窗口的布局是否为沉浸式布局
        lastWindow.setWindowLayoutFullScreen(true, () => {
          // 设置窗口全屏模式时导航栏、状态栏的可见模式
          lastWindow.setWindowSystemBarEnable([]);
          // 设置窗口的显示方向属性，AUTO_ROTATION_LANDSCAPE表示传感器自动横向旋转模式
          lastWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
        });
      } else {
        // 设置窗口的显示方向属性，UNSPECIFIED表示未定义方向模式，由系统判定
        lastWindow.setPreferredOrientation(window.Orientation.UNSPECIFIED, () => {
          // 设置窗口全屏模式时导航栏、状态栏的可见模式
          lastWindow.setWindowSystemBarEnable(WINDOW_SYSTEM_BAR, () => {
            // 设置窗口的布局是否为沉浸式布局
            lastWindow.setWindowLayoutFullScreen(false, () => {

            });
          });
        });
      }
    });
  }

  // 倍速弹框
  @Builder
  speedPopup() {
    List({ space: SPEED_POPUP_LIST_SPACE }) {
      ForEach(AVPlayerConstants.SPEED_ARRAY, (item: speedObj) => {
        ListItem() {
          Row() {
            Text(item.text)
              .fontColor('rgba(255,255,255,0.90)')
              .fontSize(15)
              .onClick(() => {
                if (this.isCreate) {
                  this.avPlayer.setSpeed(item.value);
                }
                this.speed = item.text;
                this.isSpeedShow = false;
              })
          }
          .padding({ left: 10 })
          .width('100%')
          .height(20)
        }
      }, (item: speedObj) => {
        return JSON.stringify(item);
      })
    }
    .width(80)
    .padding(10)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        XComponent({
          type: XComponentType.SURFACE,
          controller: this.xComponentController
        })
          .width('100%')
          .aspectRatio(this.videoRatio)
          .onLoad(() => {
            this.surfaceID = this.xComponentController.getXComponentSurfaceId();
          })
      }
      .borderRadius(0)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height('100%')
      .aspectRatio(-1)
      .layoutWeight(LAYOUT_WEIGHT)
      .backgroundColor(Color.Black)
      .zIndex(0)

      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceBetween }) {
        Blank().layoutWeight(1)
        Row() {
          // 播放icon
          Image(this.isPlaying ? $r("app.media.media_full_screen_icon_play") :
          $r("app.media.media_full_screen_icon_pause"))
            .width(24)
            .height(24)
            .margin({
              top: 0,
              bottom: 0,
              left: 10,
              right: 10
            })
            .onClick(() => {
              this.isPlaying = !this.isPlaying
            })
          // 时间轴
          Row() {
            Text(getTimeString(this.currentTime))
              .fontSize(16)
              .fontColor(Color.White)
              .fontWeight(500)
              .opacity(0.6)
            Slider({
              value: Math.round(this.currentTime / this.totalDuration * 100)
            })
              .selectedColor(Color.White)
              .layoutWeight(1)
              .trackColor(Color.Gray)
              .onChange((value: number) => {
                if (this.isCreate) {
                  this.currentTime = this.totalDuration * value / 100;
                  this.avPlayer.seek(this.currentTime);
                }
              })
            Text(getTimeString(this.totalDuration))
              .fontSize(16)
              .fontColor(Color.White)
              .fontWeight(500)
              .opacity(0.6)
          }
          .layoutWeight(1)
          .height(25)
          .margin({
            right: 10
          })

          // 全屏icon
          if (this.showFullScreen) {
            Image($r("app.media.media_full_screen_icon_large"))
              .width(24)
              .height(24)
              .margin({
                top: 0,
                bottom: 0,
                left: 10,
                right: 10
              })
              .opacity(0.6)
              .onClick(() => {
                this.isLandscape = !this.isLandscape;
                this.videoRatio = this.videoRatio > 0 ? 1 / this.videoRatio : 0
              })
          }

          // 倍速icon
          if (this.showSpeed) {
            Text(this.speed)
              .fontColor('rgba(255,255,255,0.90)')
              .fontSize(18)
              .margin(15)
              .onClick(() => {
                this.isSpeedShow = !this.isSpeedShow;
              })
              .bindPopup(this.isSpeedShow, {
                builder: this.speedPopup,
                placement: Placement.Top,
                popupColor: 'rgba(0,0,0,0.6)'
              })
          }
        }
        .margin({
          bottom: this.bottomRectHeight > 0 ? this.bottomRectHeight : 20
        })
      }
      .visibility(Visibility.Visible)
      .width('100%')
      .height('100%')
      .zIndex(1)
    }
    .visibility(Visibility.Visible)
    .width('100%')
    .height('100%')
    .aspectRatio(-1)
    .position({ x: 0, y: 0 })
    .zIndex(VIDEO_Z_INDEX)
  }

  private callbackComplete: () => void = () => { // 播放至结尾状态回调
  };
  private callbackTimeUpdate: (nol: number) => void = (nol: number) => { // 时间上报函数回调
  };
  private callbackBitrateUpdate: (bitrateList: number[]) => void = (bitrateList: number[]) => { // 比特率更新回调
  };
  private callbackErrorUpdate: (error: string) => void = (error: string) => { // 错误状态回调
  };
}