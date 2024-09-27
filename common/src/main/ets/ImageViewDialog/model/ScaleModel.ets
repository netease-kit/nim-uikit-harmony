/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/*
  图片缩放模型
 */
@Observed
export class ScaleModel {
  /**
   * scaleValue: 本次缩放因子，用于控制图片的大小显示
   * lastValue：记录上次缩放完后的缩放因子
   * defaultMaxScaleValue：默认的最大放大值
   * defaultScaleValue：默认缩放值，1
   */
  public scaleValue: number;
  public lastValue: number;
  public maxScaleValue: number;
  public extraScaleValue: number;
  public readonly defaultScaleValue: number = 1;

  constructor(scaleValue: number = 1.0, lastValue: number = 1.0,
    maxScaleValue: number = 1.5, extraScaleValue: number = 0.2) {
    this.scaleValue = scaleValue;
    this.lastValue = lastValue;
    this.maxScaleValue = maxScaleValue;
    this.extraScaleValue = extraScaleValue;
  }

  reset(): void {
    this.scaleValue = this.defaultScaleValue;
    this.lastValue = this.scaleValue;
  }

  stash(): void {
    this.lastValue = this.scaleValue;
  }

  toString(): string {
    return `[scaleValue: ${this.scaleValue} lastValue: ${this.lastValue}]`;
  }
}