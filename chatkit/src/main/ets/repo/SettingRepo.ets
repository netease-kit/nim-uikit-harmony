/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMDndConfig, V2NIMP2PMessageMuteMode, V2NIMTeamMessageMuteMode, V2NIMTeamType } from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';

export class SettingRepo {
  /**
   * 获取会话消息免打扰状态
   *
   * 注: 若会话类型为群, 则群消息免打扰模式为 {@link V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_OFF | V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_OFF} 返回为false. 其他的返回 true.
   *
   * @param conversationId 会话 id
   * @return mute 是否被免打扰
   */
  static async getConversationMuteStatus(conversationId: string): Promise<boolean | undefined> {
    return await ChatKitClient.nim.settingService?.getConversationMuteStatus(conversationId)
  }

  /**
   * 设置群消息免打扰模式
   *
   * @param teamId 群组ID
   * @param teamType 群组类型
   * @param muteMode 群消息免打扰模式
   */
  static async setTeamMessageMuteMode(teamId: string, teamType: V2NIMTeamType,
    muteMode: V2NIMTeamMessageMuteMode): Promise<void> {
    await ChatKitClient.nim.settingService?.setTeamMessageMuteMode(teamId, teamType, muteMode)
  }

  /**
   * 获取群消息免打扰模式
   *
   * @param teamId 群组ID
   * @param teamType 群组类型
   * @return muteMode 群消息免打扰模式
   */
  static async getTeamMessageMuteMode(teamId: string,
    teamType: V2NIMTeamType): Promise<V2NIMTeamMessageMuteMode | undefined> {
    return await ChatKitClient.nim.settingService?.getTeamMessageMuteMode(teamId, teamType)
  }

  /**
   * 设置点对点消息免打扰模式
   *
   * @param accountId 目标账号 ID
   * @param muteMode 设置用户的免打扰模式
   */
  static async setP2PMessageMuteMode(accountId: string, muteMode: V2NIMP2PMessageMuteMode): Promise<void> {
    await ChatKitClient.nim.settingService?.setP2PMessageMuteMode(accountId, muteMode)
  }

  /**
   * 获取用户消息免打扰模式
   *
   * @param accountId 目标账号 ID
   * @return muteMode p2p 类型消息免打扰模式
   */
  static async getP2PMessageMuteMode(accountId: string): Promise<V2NIMP2PMessageMuteMode | undefined> {
    return await ChatKitClient.nim.settingService?.getP2PMessageMuteMode(accountId)
  }

  /**
   * 获取点对点消息免打扰列表。
   *
   * 返回 V2NIMP2PMessageMuteMode 为 V2NIM_P2P_MESSAGE_MUTE_MODE_ON 的 accountId 列表。
   */
  static async getP2PMessageMuteList(): Promise<string[]> {
    return await ChatKitClient.nim.settingService?.getP2PMessageMuteList() ?? []
  }

  /**
   * 设置当桌面端在线时，移动端是否需要推送
   *
   * @param need 桌面端在线时，移动端是否需要推送
   */
  static async setPushMobileOnDesktopOnline(need: boolean): Promise<void> {
    await ChatKitClient.nim.settingService?.setPushMobileOnDesktopOnline(need)
  }

  /**
   *  设置Apns免打扰与详情显示
   *
   * @param config 免打扰与详情配置参数
   */
  static async setDndConfig(config: V2NIMDndConfig): Promise<void> {
    await ChatKitClient.nim.settingService?.setDndConfig(config)
  }

  /**
   * 获取Apns免打扰与详情显示
   *
   * @return 免打扰与详情配置参数
   */
  static async getDndConfig(): Promise<V2NIMDndConfig | undefined> {
    return await ChatKitClient.nim.settingService?.getDndConfig()
  }
}