/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

export class ChatViewport {
  widthVp: number
  heightVp: number
  keyboardVp: number
  availableHeightVp: number

  constructor(widthVp: number, heightVp: number, keyboardVp: number, availableHeightVp: number) {
    this.widthVp = widthVp
    this.heightVp = heightVp
    this.keyboardVp = keyboardVp
    this.availableHeightVp = availableHeightVp
  }
}

export function resolveChatViewport(widthVp: number, heightVp: number, keyboardVp: number): ChatViewport {
  const safeWidth = Math.max(0, widthVp)
  const safeHeight = Math.max(0, heightVp)
  const safeKeyboard = Math.max(0, keyboardVp)
  return new ChatViewport(safeWidth, safeHeight, safeKeyboard, Math.max(0, safeHeight - safeKeyboard))
}

export function resolveChatBaseHeight(windowHeightVp: number, measuredAreaHeightVp: number): number {
  const safeWindowHeight = Math.max(0, windowHeightVp)
  if (safeWindowHeight > 0) {
    return safeWindowHeight
  }
  return Math.max(0, measuredAreaHeightVp)
}

export function clampPopupX(xVp: number, popupWidthVp: number, containerWidthVp: number,
  marginVp: number): number {
  const safeMargin = Math.max(0, marginVp)
  const maximum = Math.max(safeMargin, Math.max(0, containerWidthVp) - Math.max(0, popupWidthVp) - safeMargin)
  return Math.min(maximum, Math.max(safeMargin, xVp))
}

/**
 * 分栏/折叠分屏下，窗口宽度包含左侧会话栏，聊天栏实际宽度小于窗口宽度。
 * 聊天栏宽度 = 窗口宽度 - 聊天栏左边界（左边界即聊天栏内的 globalPosition.x）。
 */
export function resolveChatPaneWidth(windowWidthVp: number, paneOriginXVp: number,
  measuredWidthVp: number): number {
  // 优先使用聊天页自身实测宽度：分栏/多栏（三折、2in1）时它就是聊天栏宽度。
  // 不能再用"整窗宽度 - 栏左边界"——页面 onAreaChange 会把 screenWidth 覆盖成页面宽度，
  // 再减一次左边界会让栏宽被算小（三折实测 701vp 被算成 294vp），
  // 导致长按菜单/快捷评论面板被夹到栏左侧，离右侧消息很远。
  if (measuredWidthVp > 0) {
    return measuredWidthVp
  }
  const safeWindow = Math.max(0, windowWidthVp)
  const safeOrigin = Math.max(0, paneOriginXVp)
  if (safeWindow > safeOrigin) {
    return safeWindow - safeOrigin
  }
  return 0
}

export class ReactionPickerLayout {
  xVp: number
  widthVp: number

  constructor(xVp: number, widthVp: number) {
    this.xVp = xVp
    this.widthVp = widthVp
  }
}

/**
 * 快捷评论面板横向布局：
 * 1）宽度不超过聊天栏（窄分栏下等比收窄），基准是聊天栏而不是整窗；
 * 2）有锚点时面板跟着点击位置走（以「+」矩形中心居中），点到哪就在哪附近弹出；
 *    只有贴着聊天栏边界时才夹住，不跳到聊天栏中间；
 * 3）没有锚点（锚点未测量到）时才退回「聊天栏内居中」。
 *
 * @param anchorCenterXVp 「+」矩形中心相对聊天栏左边的横坐标，传负数表示没有锚点
 */
export function resolveReactionPickerLayout(paneWidthVp: number, preferredWidthVp: number,
  marginVp: number, anchorCenterXVp: number = -1): ReactionPickerLayout {
  const safePane = Math.max(0, paneWidthVp)
  const safeMargin = Math.max(0, marginVp)
  // 面板宽度保持设计值（320vp）不变：内部是 7 列固定图片尺寸的 Grid，
  // 压缩宽度会让表情溢出；越界只通过 x 夹取解决。
  const width = Math.max(0, preferredWidthVp)
  if (anchorCenterXVp >= 0) {
    // 跟随点击位置：仅在会越出聊天栏时贴边夹住
    return new ReactionPickerLayout(clampPopupX(anchorCenterXVp - width / 2, width, safePane, safeMargin), width)
  }
  return new ReactionPickerLayout(clampPopupX((safePane - width) / 2, width, safePane, safeMargin), width)
}
