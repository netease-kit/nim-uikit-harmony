/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { V2NIMMessagePushConfig, V2NIMTeamAgreeMode, V2NIMTeamJoinMode } from "@nimsdk/base";
import { TranslationLanguageCode } from '@nimkit/common';

@ObservedV2
export class IMKitConfigCenter {
  /**
   * 是否使用本地会话列表
   */
  @Trace static enableLocalConversation: boolean = true;
  /**
   * 是否显示在线状态
   */
  @Trace static enableShownOnlineState: boolean = true;
  /**
   * 是否反垃圾检测提示消息，控制消息发送后命中反垃圾，是否提示TIPS消息
   */
  @Trace static enableAntiSpamTipMessage: boolean = true;
  /**
   * 是否开启云端搜索功能
   */
  @Trace static enableCloudSearch = false
  /**
   * 是否启用收藏功能
   */
  @Trace static enableCollection: boolean = true;
  /**
   * 是否启用标记功能
   */
  @Trace static enablePin: boolean = true;
  /**
   * 是否启用"正在输入"状态功能（仅 P2P 会话）
   */
  @Trace static enableTypingStatus: boolean = true;
  /**
   * 是否仅允许好友音视频通话（默认 true，非好友将提示"非好友暂不支持音视频通话"）
   */
  @Trace static enableOnlyFriendCall: boolean = true;
  /**
   * 群管理页是否显示 JoinMode/AgreeMode 开关
   * 默认 true，群管理页中展示审批开关
   * 设为 true，群主/管理员可在群管理页动态修改
   */
  @Trace static enableTeamJoinAgreeModelAuth: boolean = true;
  /**
   * 高级群创建时的默认申请入群模式
   */
  static teamJoinMode: V2NIMTeamJoinMode = V2NIMTeamJoinMode.V2NIM_TEAM_JOIN_MODE_FREE;
  /**
   * 高级群创建时的默认邀请入群同意模式
   */
  static teamAgreeMode: V2NIMTeamAgreeMode = V2NIMTeamAgreeMode.V2NIM_TEAM_AGREE_MODE_NO_AUTH;
  /**
   * 群功能总开关
   */
  @Trace static enableTeam: boolean = true;
  /**
   * 是否启用置顶消息功能
   */
  @Trace static enableTopMessage: boolean = true;
  /**
   * 是否启用 AI 数字人功能
   */
  @Trace static enableAI: boolean = true;
  /**
   * 是否启用 AI 流式输出模式
   */
  @Trace static enableAIStream: boolean = true;
  /**
   * 是否启用 AI 助聊功能
   */
  @Trace static enableAIChatHelper: boolean = true;
  /**
   * 是否启用 AI 划词搜索功能
   */
  @Trace static enableAIWordSearch: boolean = true;
  /**
   * 是否启用富文本消息
   */
  @Trace static enableRichTextMessage: boolean = true;
  /**
   * 群管理员数量上限
   */
  @Trace static teamManagerMaxCount: number = 10;
  /**
   * 是否启用听筒模式播放语音
   * true: 听筒模式，false: 扬声器模式
   */
  @Trace static enableEarphoneMode: boolean = false;

  /**
   * 是否开启消息已读未读功能，默认开启
   */
  @Trace static enableReadMessage: boolean = true;
  /**
   * 是否启用推送配置
   */
  @Trace static enablePushConfig: boolean = false;
  /**
   * 推送配置对象（供消息发送时使用）
   */
  static pushConfig: V2NIMMessagePushConfig | undefined = undefined;
  /**
   * 自动翻译开启时间戳（毫秒），0 = 关闭，非 0 = 开启时刻
   */
  @Trace static autoTranslationEnableTime: number = 0;
  /**
   * 翻译目标语言
   */
  @Trace static translationTargetLanguage: string = TranslationLanguageCode.ZH_CHS;
}
