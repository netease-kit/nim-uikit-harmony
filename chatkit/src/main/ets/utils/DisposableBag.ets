/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export type EventDisposer = () => void

export class DisposableBag {
  private disposers: EventDisposer[] = []

  add(disposer: EventDisposer): void {
    this.disposers.push(disposer)
  }

  addAll(disposers: EventDisposer[]): void {
    this.disposers.push(...disposers)
  }

  dispose(): void {
    this.disposers.forEach((dispose) => dispose())
    this.disposers = []
  }
}
