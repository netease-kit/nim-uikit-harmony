/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

@ComponentV2
export struct CommonAvatar {
  /**
   * 头像数据
   */
  @Param item: AvatarItem | null = null
  /**
   * 头像圆角
   */
  @Param roundRadius: Length = 20
  /**
   * 名称文字大小
   */
  @Param textSize: Length = 14
  /**
   * 文字颜色
   */
  @Param textColor: ResourceColor = '#ffFFFFFF'

  build() {
    if (this.item != null) {

      if (this.item.avatarUrl == null || this.item.avatarUrl.toString().length <= 0) {
        Stack() {
          Column() {
          }.width('100%').height('100%').backgroundColor(this.item.color)
          .borderRadius(this.roundRadius)

          Text(this.item.name)
            .fontSize(this.textSize)
            .fontColor(this.textColor)
            .ellipsisMode(EllipsisMode.END)
            .textAlign(TextAlign.Center)
            .margin({
              left: 6, right: 6
            })
            .width('100%')
            .maxLines(1)
        }
      } else {
        Image(this.item.avatarUrl).borderRadius(this.roundRadius)
      }

    }
  }
}

@Builder
export function buildAvatar(item: AvatarItem, width: Length, height: Length,
  borderRadius?: Length | null) {
  Stack() {
    if (item.avatarUrl == null || item.avatarUrl.toString().length <= 0) {
      Column() {
      }.width('100%').height('100%').backgroundColor(item.color)

      Text(item.name) {
      }
    } else {
      Image(item.avatarUrl)
    }
  }.width(width)
  .height(height)
  .borderRadius(borderRadius)
}

/**
 * 头像显示的数据类型
 */
@ObservedV2
export class AvatarItem {
  /**
   * 头像URL
   */
  @Trace avatarUrl?: ResourceStr | null = null
  /**
   * 头像显示的昵称
   */
  @Trace name?: string
  /**
   * 头像背景色
   */
  color?: number

  constructor(avatarUrl?: ResourceStr, name?: string, color?: number) {
    this.name = name
    this.color = color
    this.avatarUrl = avatarUrl
  }
}

/**
 * 获取头像背景色的工具类
 */
export class AvatarColorUntil {
  /**
   * 默认背景色合集
   */
  static colorList: number[] = [
    0xff60cfa7, 0xff53c3f3, 0xff537ff4, 0xff854fe2, 0xffbe65d9, 0xffe9749d, 0xfff9b751
  ]

  /**
   * 使用ID生成头像背景色
   * @param id
   * @returns
   */
  public static getBackgroundColorById(id: string): number {
    const numberValue = AvatarColorUntil.hashCode(id)
    let temp = Math.abs(numberValue % 7)
    return AvatarColorUntil.colorList[temp]
  }

  /**
   * 获取Hashcode 值
   * @param str
   * @returns
   */
  static hashCode(str: string): number {
    let hash = 0;
    if (str.length == 0) {
      return hash;
    }
    for (let i = 0; i < str.length; i++) {
      let char = str.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash;
  }
}