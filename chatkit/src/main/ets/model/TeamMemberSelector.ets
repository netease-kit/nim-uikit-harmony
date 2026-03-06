/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * 群成员选择器使用模式
 */
export enum TeamMemberSelectorMode {
  /** 添加管理员模式 - 需要网络，仅显示普通成员 */
  ADD_MANAGER = 'ADD_MANAGER',
  /** 全文检索模式 - 不需要网络，显示管理员和群主 */
  FTS_SEARCH = 'FTS_SEARCH',
}

export interface ManagerSelectorParams {
  selectLimit: number, //群成员选取数量限制
  teamId: string,
  /** 选择器模式，决定是否需要网络、是否显示管理员等行为 */
  mode: TeamMemberSelectorMode,
}