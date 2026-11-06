/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { window } from '@kit.ArkUI'
import {
  AdaptiveAvoidAreaSnapshot,
  AdaptiveWindowSnapshot
} from '../model/AdaptiveLayoutModel'
import { resolveHeightBreakpoint, resolveWidthBreakpoint } from './AdaptiveLayoutPolicy'

export type AdaptiveWindowListener = (snapshot: AdaptiveWindowSnapshot) => void

export class AdaptiveWindowStateStore {
  private snapshot: AdaptiveWindowSnapshot = this.createSnapshot(0, 0, new AdaptiveAvoidAreaSnapshot())
  private listeners: AdaptiveWindowListener[] = []

  getSnapshot(): AdaptiveWindowSnapshot {
    return this.snapshot
  }

  getSubscriberCount(): number {
    return this.listeners.length
  }

  subscribe(listener: AdaptiveWindowListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener)
    }
    listener(this.snapshot)
  }

  unsubscribe(listener: AdaptiveWindowListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  updateSize(widthVp: number, heightVp: number): void {
    this.publish(this.createSnapshot(widthVp, heightVp, this.snapshot.avoidAreas))
  }

  updateAvoidAreas(avoidAreas: AdaptiveAvoidAreaSnapshot): void {
    this.publish(this.createSnapshot(this.snapshot.widthVp, this.snapshot.heightVp, avoidAreas))
  }

  private createSnapshot(widthVp: number, heightVp: number,
    avoidAreas: AdaptiveAvoidAreaSnapshot): AdaptiveWindowSnapshot {
    const safeWidth = Math.max(0, widthVp)
    const safeHeight = Math.max(0, heightVp)
    return new AdaptiveWindowSnapshot(
      safeWidth,
      safeHeight,
      resolveWidthBreakpoint(safeWidth),
      resolveHeightBreakpoint(safeWidth, safeHeight),
      avoidAreas
    )
  }

  private publish(next: AdaptiveWindowSnapshot): void {
    if (this.equals(this.snapshot, next)) {
      return
    }
    this.snapshot = next
    for (const listener of this.listeners) {
      listener(next)
    }
  }

  private equals(left: AdaptiveWindowSnapshot, right: AdaptiveWindowSnapshot): boolean {
    return left.widthVp === right.widthVp && left.heightVp === right.heightVp &&
      left.avoidAreas.topVp === right.avoidAreas.topVp &&
      left.avoidAreas.bottomVp === right.avoidAreas.bottomVp &&
      left.avoidAreas.leftVp === right.avoidAreas.leftVp &&
      left.avoidAreas.rightVp === right.avoidAreas.rightVp &&
      left.avoidAreas.keyboardVp === right.avoidAreas.keyboardVp
  }
}

export class AdaptiveWindowManager {
  readonly state: AdaptiveWindowStateStore = new AdaptiveWindowStateStore()
  private windowObject?: window.Window = undefined
  private readonly sizeListener = (size: window.Size): void => {
    this.state.updateSize(px2vp(size.width), px2vp(size.height))
  }
  private readonly avoidAreaListener = (options: window.AvoidAreaOptions): void => {
    this.applyAvoidArea(options.type, options.area)
  }

  init(windowObject: window.Window): void {
    if (this.windowObject === windowObject) {
      return
    }
    this.release()
    this.windowObject = windowObject
    const rect = windowObject.getWindowProperties().windowRect
    this.state.updateSize(px2vp(rect.width), px2vp(rect.height))
    this.applyAvoidArea(window.AvoidAreaType.TYPE_SYSTEM,
      windowObject.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM))
    this.applyAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD,
      windowObject.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD))
    windowObject.on('windowSizeChange', this.sizeListener)
    windowObject.on('avoidAreaChange', this.avoidAreaListener)
  }

  release(): void {
    if (!this.windowObject) {
      return
    }
    this.windowObject.off('windowSizeChange', this.sizeListener)
    this.windowObject.off('avoidAreaChange', this.avoidAreaListener)
    this.windowObject = undefined
  }

  private applyAvoidArea(type: window.AvoidAreaType, area: window.AvoidArea): void {
    const current = this.state.getSnapshot().avoidAreas
    if (type === window.AvoidAreaType.TYPE_KEYBOARD) {
      this.state.updateAvoidAreas(new AdaptiveAvoidAreaSnapshot(
        current.topVp,
        current.bottomVp,
        current.leftVp,
        current.rightVp,
        px2vp(area.bottomRect.height)
      ))
      return
    }
    if (type === window.AvoidAreaType.TYPE_SYSTEM) {
      this.state.updateAvoidAreas(new AdaptiveAvoidAreaSnapshot(
        px2vp(area.topRect.height),
        px2vp(area.bottomRect.height),
        px2vp(area.leftRect.width),
        px2vp(area.rightRect.width),
        current.keyboardVp
      ))
    }
  }
}

export const adaptiveWindowManager: AdaptiveWindowManager = new AdaptiveWindowManager()
