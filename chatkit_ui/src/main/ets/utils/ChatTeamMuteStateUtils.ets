/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

export class CollapsedChatInputLayout {
  expandHeight: number = 0
  bottomHeight: number
  pendingExpandPanelAfterKeyboardHide: boolean = false
  hideInput: boolean = false
  shouldStopRecord: boolean = true

  constructor(bottomHeight: number) {
    this.bottomHeight = bottomHeight
  }
}

export function createCollapsedChatInputLayout(bottomHeight: number): CollapsedChatInputLayout {
  return new CollapsedChatInputLayout(bottomHeight)
}
