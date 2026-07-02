/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * 消息列表项因为滚动、列表复用或输入区高度变化而离开视口时，
 * 不应影响全局语音播放。真正的停播时机由页面隐藏、页面销毁
 * 或用户主动切换播放目标来控制。
 */
export function shouldStopAudioPlaybackOnMessageItemDisappear(): boolean {
  return false
}
