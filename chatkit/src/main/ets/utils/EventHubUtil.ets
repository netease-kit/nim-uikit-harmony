/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export class EventHubUtil {
  private eventhub = getContext(this).eventHub

  /// 订阅事件
  public on(eventName: string, callback: Function) {
    this.eventhub.on(eventName, callback)
  }

  /// 取消订阅事件
  public off(eventName: string, callback?: Function) {
    this.eventhub.off(eventName, callback)
  }

  /// 触发事件
  public emit(eventName: string, params: Object) {
    this.eventhub.emit(eventName, params)
  }
}
