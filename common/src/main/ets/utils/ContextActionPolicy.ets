/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

export function shouldOpenContextAction(button: MouseButton, action: MouseAction): boolean {
  return button === MouseButton.Right && action === MouseAction.Release
}

export enum ContextActionTrigger {
  TOUCH_LONG_PRESS = 'touchLongPress',
  MOUSE_RIGHT_CLICK = 'mouseRightClick'
}

export class ContextActionDecision {
  open: boolean
  stopPropagation: boolean

  constructor(open: boolean, stopPropagation: boolean) {
    this.open = open
    this.stopPropagation = stopPropagation
  }
}

export function resolveContextAction(button: MouseButton, action: MouseAction,
  nestedTarget: boolean = false): ContextActionDecision {
  const open = shouldOpenContextAction(button, action)
  return new ContextActionDecision(open, open && nestedTarget)
}

/**
 * 消息文本处于框选状态时，列表容器不能在首个触点上清理选区。
 * 否则系统会在拖动选区手柄前先销毁选择状态，导致拖动和菜单点击互相抢占。
 */
export function shouldDismissSelectionOnTouch(selectionActive: boolean): boolean {
  return !selectionActive
}

// 菜单刚打开时系统会把整条选区调整到按压位置，可能回报一次空选区；这段时间内不视为点击菜单外。
export const MOUSE_MENU_SETTLE_MS: number = 400

// 触屏下菜单刚弹出的瞬间，系统可能回报一次按压产生的触摸事件；
// 这段时间内不视为"点击菜单外"，避免菜单刚出现就被自己关掉。
export const TOUCH_MENU_SETTLE_MS: number = 200

/**
 * 鼠标操作菜单可见时，文本失焦会先回调一次空选区。
 * 指针不在菜单内且菜单已稳定显示时，才说明用户点了菜单外的区域，此时应结束本次选区；
 * 指针在菜单内或菜单刚打开时保持选区，等待菜单项完成点击或系统完成选区调整。
 */
export function shouldCloseMouseSelectionOnCollapse(collapsed: boolean, menuVisible: boolean,
  pointerInMenu: boolean, menuVisibleDurationMs: number): boolean {
  return collapsed && menuVisible && !pointerInMenu && menuVisibleDurationMs > MOUSE_MENU_SETTLE_MS
}
