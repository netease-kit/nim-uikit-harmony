/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { image } from '@kit.ImageKit';
import { matrix4, window } from '@kit.ArkUI';
import { OffsetModel } from './model/OffsetModel';
import { ScaleModel } from './model/ScaleModel';
import { runWithAnimation } from '../utils/FuncUtils';
import { WindowSizeManager } from '../utils/WindowSizeManagers';


/*
  图片查看器 item
 */
@Component
export struct ImageItemView {
  @State isEnableOffset: boolean = false;
  @State imageScaleInfo: ScaleModel = new ScaleModel(1.0, 1.0, 1.5, 0.3);
  @State imageOffsetInfo: OffsetModel = new OffsetModel(0, 0);
  @State matrix: matrix4.Matrix4Transit = matrix4.identity().copy();
  @State imagePixelMap: image.PixelMap | null = null; // 当前图片pixelMap，用于Image组件显示
  @State fitWH: "width" | "height" | undefined = "width"; // 表示当前图片是根据宽度适配还是高度适配
  @State imageDefaultSize: image.Size = { width: 0, height: 0 }; // 图片默认大小，即，与屏幕大小最适配的显示大小
  @State imageUri: string = ""; // 当前图片uri
  imageWHRatio: number = 0; // 图片原始宽高比
  imageW: number = 0; // 图片原始宽
  imageH: number = 0; // 图片原始高
  windowSizeManager: WindowSizeManager = new WindowSizeManager(getContext(this));

  /**
   * 根据图片宽高比及窗口大小计算图片的默认宽高，即，图片最适配屏幕的大小
   * @param imageWHRatio：图片原始宽高比
   * @param size：窗口大小{with:number,height:number}
   * @returns image.Size
   */
  calcImageDefaultSize(imageWHRatio: number, size: window.Size): image.Size {
    let width = 0
    let height = 0;
    if (imageWHRatio > size.width / size.height) {
      // 图片宽高比大于屏幕宽高比，图片默认以屏幕宽度进行显示
      width = size.width;
      height = size.width / imageWHRatio;
    } else {
      height = size.height;
      width = size.height * imageWHRatio;
    }
    return { width: width, height: height };
  }

  /**
   * 根据图片大小（宽高<=屏幕宽高）和屏幕大小计算图片放大适配屏幕进行显示的缩放倍率
   * @param imageSize：图片当前大小
   * @param windowSize：窗口大小
   * @returns：缩放倍率
   */
  calcFitScaleRatio(imageSize: image.Size, windowSize: window.Size): number {
    let ratio: number = 1.0;
    if (windowSize.width > imageSize.width) {
      ratio = windowSize.width / imageSize.width;
    } else {
      ratio = windowSize.height / imageSize.height;
    }
    return ratio;
  }

  /**
   * 在图片消失时，将当前图片的信息设置为默认值
   */
  resetCurrentImageInfo(): void {
    this.imageScaleInfo.reset();
    this.imageOffsetInfo.reset();
    this.matrix = matrix4.identity().copy();
  }

  /**
   * 在偏移时评估是否到达边界，以便进行位移限制与图片的切换
   * @returns：长度为4的boolean数组，表示上下左右是否到达边界
   */
  evaluateBound(): boolean[] {
    return [false, false, false, false];
  }

  build() {
    Stack() {
      Image(this.imageUri)// 宽高只根据其尺寸设置一个，通过保持宽高比来设置另一个属性
        .width(this.fitWH === "width" ? '100%' : undefined)
        .height(this.fitWH === "height" ? '100%' : undefined)
        .aspectRatio(this.imageWHRatio)
        .objectFit(ImageFit.Cover)// 保持宽高比进行缩放，可以超出父组件，以便实现多图切换的增强功能
        .autoResize(false)
        .transform(this.matrix)// 通过matrix控制图片的缩放
        .defaultFocus(true)
        .offset({
          // 通过offset控制图片的偏移
          x: this.imageOffsetInfo.currentX,
          y: this.imageOffsetInfo.currentY
        })
        .onComplete(data => {
          if (data) {
            this.imageW = px2vp(data.componentWidth)
            this.imageH = px2vp(data.componentHeight)
            this.imageWHRatio = data.width / data.height;
            this.imageDefaultSize = this.calcImageDefaultSize(this.imageWHRatio, this.windowSizeManager.size);
            if (this.imageDefaultSize.width === this.windowSizeManager.size.width) {
              this.fitWH = "width";
            } else {
              this.fitWH = "height";
            }
            this.imageScaleInfo.maxScaleValue += this.fitWH === "width" ?
              (this.windowSizeManager.size.height / this.imageDefaultSize.height) :
              (this.windowSizeManager.size.width / this.imageDefaultSize.width);
          }
        })
    }
    .onBlur(() => {
      this.resetCurrentImageInfo();
    })
    .backgroundColor(Color.Black)
    .alignContent(Alignment.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .gesture(
      GestureGroup(
        GestureMode.Exclusive,
        // 双击切换图片大小
        TapGesture({ count: 2 })
          .onAction(() => {
            let fn: Function;
            // 已经是放大状态下，双击缩小
            if (this.imageScaleInfo.scaleValue > this.imageScaleInfo.defaultScaleValue) {
              fn = () => {
                this.imageScaleInfo.reset();
                this.imageOffsetInfo.reset();
                this.matrix = matrix4.identity().copy();
              };
            } else {
              // 已经是缩小状态，双击放大
              fn = () => {
                const ratio: number = this.calcFitScaleRatio(this.imageDefaultSize, this.windowSizeManager.size);
                this.imageScaleInfo.scaleValue = ratio;
                this.imageOffsetInfo.reset();
                this.matrix = matrix4.identity().scale({
                  x: ratio,
                  y: ratio,
                }).copy();
                this.imageScaleInfo.stash();
              }
            }
            runWithAnimation(fn);
          }),
        // 双指捏合缩放图片
        PinchGesture({ fingers: 2, distance: 1 })
          .onActionUpdate((event: GestureEvent) => {
            this.imageScaleInfo.scaleValue = this.imageScaleInfo.lastValue * event.scale;
            // 缩放时不允许大于最大缩放因子+额外缩放因子，不允许小于默认大小-额外缩放因子，额外缩放因子用于提升用户体验
            if (this.imageScaleInfo.scaleValue > this.imageScaleInfo.maxScaleValue *
              (1 + this.imageScaleInfo.extraScaleValue)
            ) {
              this.imageScaleInfo.scaleValue = this.imageScaleInfo.maxScaleValue *
                (1 + this.imageScaleInfo.extraScaleValue);
            }
            if (this.imageScaleInfo.scaleValue < this.imageScaleInfo.defaultScaleValue *
              (1 - this.imageScaleInfo.extraScaleValue)) {
              this.imageScaleInfo.scaleValue = this.imageScaleInfo.defaultScaleValue *
                (1 - this.imageScaleInfo.extraScaleValue);
            }
            // matrix默认缩放中心为组件中心
            this.matrix = matrix4.identity().scale({
              x: this.imageScaleInfo.scaleValue,
              y: this.imageScaleInfo.scaleValue,
            }).copy();
            console.debug(this.imageScaleInfo.toString());
          })
          .onActionEnd((event: GestureEvent) => {
            /**
             * 当小于默认大小时，恢复为默认大小
             */
            if (this.imageScaleInfo.scaleValue < this.imageScaleInfo.defaultScaleValue) {
              runWithAnimation(() => {
                this.imageScaleInfo.reset();
                this.imageOffsetInfo.reset();
                this.matrix = matrix4.identity().copy();
              })
            }
            // 当大于最大缩放因子时，恢复到最大
            if (this.imageScaleInfo.scaleValue > this.imageScaleInfo.maxScaleValue) {
              runWithAnimation(() => {
                this.imageScaleInfo.scaleValue = this.imageScaleInfo.maxScaleValue;
                this.matrix = matrix4.identity()
                  .scale({
                    x: this.imageScaleInfo.maxScaleValue,
                    y: this.imageScaleInfo.maxScaleValue
                  });
              })
            }
            this.imageScaleInfo.stash();
          }),
        // 滑动图片
        PanGesture({ fingers: 1 })// 默认大小下左右滑动应当是切换图片
          .tag('pan_darg')
          .onActionUpdate((event: GestureEvent) => {
            this.imageOffsetInfo.currentX = this.imageOffsetInfo.lastX + event.offsetX;
            this.imageOffsetInfo.currentY = this.imageOffsetInfo.lastY + event.offsetY;
          })
          .onActionEnd((event: GestureEvent) => {
            const maxX = (this.imageScaleInfo.scaleValue * this.imageW - this.windowSizeManager.size.width) / 2.0
            const maxY = (this.imageScaleInfo.scaleValue * this.imageH - this.windowSizeManager.size.height) / 2.0 +
            this.windowSizeManager.topRectHeight + this.windowSizeManager.bottomRectHeight
            if (Math.abs(this.imageOffsetInfo.currentX) > maxX || Math.abs(this.imageOffsetInfo.currentY) > maxY) {
              runWithAnimation(() => {
                if (maxX > 0 && Math.abs(this.imageOffsetInfo.currentX) > maxX) {
                  if (this.imageOffsetInfo.currentX < 0) {
                    this.imageOffsetInfo.currentX = Math.max(this.imageOffsetInfo.currentX, -maxX)
                  } else {
                    this.imageOffsetInfo.currentX = Math.min(this.imageOffsetInfo.currentX, maxX)
                  }
                }

                if (maxY > 0 && Math.abs(this.imageOffsetInfo.currentY) > maxY) {
                  if (this.imageOffsetInfo.currentY < 0) {
                    this.imageOffsetInfo.currentY = Math.max(this.imageOffsetInfo.currentY, -maxY)
                  } else {
                    this.imageOffsetInfo.currentY = Math.min(this.imageOffsetInfo.currentY, maxY)
                  }
                }
              })
            }

            this.imageOffsetInfo.stash();
          })
      ),
    )
    .onGestureJudgeBegin((gestureInfo: GestureInfo, event: BaseGestureEvent) => {
      if (gestureInfo.tag === 'pan_darg') {
        if (this.imageScaleInfo.scaleValue === this.imageScaleInfo.defaultScaleValue) {
          // 默认大小下不允许移动
          return GestureJudgeResult.REJECT
        }
      }
      return GestureJudgeResult.CONTINUE;
    })
  }
}