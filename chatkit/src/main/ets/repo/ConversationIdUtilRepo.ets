/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMConversationType } from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';

export class ConversationIdUtilRepo {
  /**
   * 构造点对点会话ID
   *
   * @param accountId 对方的账号 id
   * @returns 会话 id
   */
  static p2pConversationId(accountId: string): string {
    return ChatKitClient.nim.conversationIdUtil.p2pConversationId(accountId)
  }

  /**
   * 构造群会话ID
   *
   * @param teamId 群 id
   * @returns 会话 id
   */
  static teamConversationId(teamId: string): string {
    return ChatKitClient.nim.conversationIdUtil.teamConversationId(teamId)
  }

  /**
   * 构造超大群会话ID
   *
   * @param superTeamId 超大群 id
   * @returns 会话 id
   * ```
   */
  static superTeamConversationId(superTeamId: string): string {
    return ChatKitClient.nim.conversationIdUtil.teamConversationId(superTeamId)
  }

  /**
   * 解析会话类型
   *
   * @param conversationId 会话 id
   * @returns 会话类型
   */
  static parseConversationType(conversationId: string): V2NIMConversationType {
    return ChatKitClient.nim.conversationIdUtil.parseConversationType(conversationId)
  }

  /**
   * 解析会话目标账号
   *
   * @param conversationId 会话 id
   * @returns 点对点会话返回对方账号 id; 群会话返回群 id; 超大群会话返回超大群 id
   */
  static parseConversationTargetId(conversationId: string): string {
    return ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
  }
}