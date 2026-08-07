/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * Common constants for all features.
 */
export class CommonConstants {
  /**
   * Breakpoint sm.
   */
  static readonly BREAKPOINTS_SM_NAME: string = 'sm';
  /**
   * Breakpoint md.
   */
  static readonly BREAKPOINTS_MD_NAME: string = 'md';
  /**
   * Breakpoint lg.
   */
  static readonly BREAKPOINTS_LG_NAME: string = 'lg';
  /**
   * Breakpoint xl.
   */
  static readonly BREAKPOINTS_XL_NAME: string = 'xl';
  /**
   * The break point value of sm device.
   */
  static readonly BREAKPOINTS_SM_SIZE: number = 0;
  /**
   * The break point value of md device.
   */
  static readonly BREAKPOINTS_MD_SIZE: number = 600;
  /**
   * The break point value of lg device.
   */
  static readonly BREAKPOINTS_LG_SIZE: number = 840;
  /**
   * The break point value of xl device.
   */
  static readonly BREAKPOINTS_XL_SIZE: number = 1320;
  /**
   * Initialize device breakpoints.
   */
  static readonly BREAKPOINTS_INITIALIZE_NAME: string = 'md';
  /**
   * Initialize device breakpoint Id.
   */
  static readonly BREAKPOINT_ID_INITIALIZE_NAME: string = 'unknown';
  /**
   * 【听筒模式】存储 key
   */
  static readonly KEY_SETTING_EARPIECE_MODE: string = 'KEY_SETTING_EARPIECE_MODE';
  /**
   * 【消息已读未读功能】存储 key
   */
  static readonly KEY_SETTING_MESSAGE_READ_OR: string = 'KEY_SETTING_MESSAGE_READ_OR';
  /**
   * use local conversation kit
   * if true , use local conversation kit
   * if false , use remote conversation kit
   */
  static readonly KEY_SETTING_LOCAL_CONVERSATION: string = 'KEY_SETTING_LOCAL_CONVERSATION';
  /**
   * 在线状态是否显示
   */
  static readonly KEY_SETTING_SHOWN_ONLINE_STATE: string = 'KEY_SETTING_SHOWN_ONLINE_STATE';
  /**
   * 反垃圾是否发送 TIP 消息
   */
  static readonly KEY_SETTING_ANTISPAM_TIP_MESSAGE: string = 'KEY_SETTING_ANTISPAM_TIP_MESSAGE';
  /**
   * 是否启用云端搜索
   */
  static readonly KEY_SETTING_CLOUD_SEARCH: string = 'KEY_SETTING_CLOUD_SEARCH';
  /**
   * 收藏功能开关 存储 key
   */
  static readonly KEY_SETTING_COLLECTION_ENABLE: string = 'KEY_SETTING_COLLECTION_ENABLE';
  /**
   * 标记功能开关 存储 key
   */
  static readonly KEY_SETTING_PIN_ENABLE: string = 'KEY_SETTING_PIN_ENABLE';
  /**
   * 正在输入功能开关 存储 key
   */
  static readonly KEY_SETTING_TYPING_STATUS: string = 'KEY_SETTING_TYPING_STATUS';
  /**
   * 仅好友音视频通话开关 存储 key
   */
  static readonly KEY_SETTING_ONLY_FRIEND_CALL: string = 'KEY_SETTING_ONLY_FRIEND_CALL';
  /**
   * 群聊申请/邀请审批模式开关 存储 key
   */
  static readonly KEY_SETTING_TEAM_JOIN_AGREE_MODE: string = 'KEY_SETTING_TEAM_JOIN_AGREE_MODE';
  /**
   * 群功能总开关 存储 key
   */
  static readonly KEY_SETTING_TEAM_ENABLE: string = 'KEY_SETTING_TEAM_ENABLE';
  /**
   * 置顶消息开关 存储 key
   */
  static readonly KEY_SETTING_TOP_MESSAGE: string = 'KEY_SETTING_TOP_MESSAGE';
  /**
   * AI流式输出模式开关 存储 key
   */
  static readonly KEY_SETTING_AI_STREAM: string = 'KEY_SETTING_AI_STREAM';
  /**
   * 富文本消息开关 存储 key
   */
  static readonly KEY_SETTING_RICH_TEXT_MESSAGE: string = 'KEY_SETTING_RICH_TEXT_MESSAGE';
  /**
   * 群管理员数量上限 存储 key
   */
  static readonly KEY_SETTING_TEAM_MANAGER_MAX_COUNT: string = 'KEY_SETTING_TEAM_MANAGER_MAX_COUNT';
  /**
   * 消息已读未读开关 存储 key
   */
  static readonly KEY_SETTING_READ_MESSAGE: string = 'KEY_SETTING_READ_MESSAGE';
  /**
   * 推送配置开关 存储 key
   */
  static readonly KEY_SETTING_PUSH_CONFIG_ENABLED: string = 'KEY_SETTING_PUSH_CONFIG_ENABLED';
  /**
   * 推送配置内容 存储 key
   */
  static readonly KEY_SETTING_PUSH_CONFIG_CONTENT: string = 'KEY_SETTING_PUSH_CONFIG_CONTENT';
  /**
   * 新消息响铃开关 存储 key
   */
  static readonly KEY_SETTING_NOTIFY_RING: string = 'KEY_SETTING_NOTIFY_RING';
  /**
   * 新消息震动开关 存储 key
   */
  static readonly KEY_SETTING_NOTIFY_VIBRATE: string = 'KEY_SETTING_NOTIFY_VIBRATE';
  /**
   * 自动翻译开启时间戳 存储 key
   */
  static readonly KEY_SETTING_AUTO_TRANSLATION_ENABLE_TIME: string = 'KEY_SETTING_AUTO_TRANSLATION_ENABLE_TIME';
  /**
   * 翻译目标语言 存储 key
   */
  static readonly KEY_SETTING_TRANSLATION_TARGET_LANGUAGE: string = 'KEY_SETTING_TRANSLATION_TARGET_LANGUAGE';
  /**
   * 应用语言 存储 key
   */
  static readonly KEY_SETTING_APP_LANGUAGE: string = 'KEY_SETTING_APP_LANGUAGE';
}

export enum TranslationLanguageCode {
  ZH_CHS = 'zh-CHS',
  ZH_CHT = 'zh-CHT',
  EN = 'en',
  JA = 'ja',
  KO = 'ko',
  FR = 'fr',
  DE = 'de',
  ES = 'es',
  RU = 'ru',
  PT = 'pt',
  IT = 'it',
  AR = 'ar',
  HI = 'hi',
  VI = 'vi',
  TH = 'th',
  ID = 'id'
}

export const SUPPORTED_TRANSLATION_LANGUAGES: TranslationLanguageCode[] = [
  TranslationLanguageCode.ZH_CHS,
  TranslationLanguageCode.ZH_CHT,
  TranslationLanguageCode.EN,
  TranslationLanguageCode.JA,
  TranslationLanguageCode.KO,
  TranslationLanguageCode.FR,
  TranslationLanguageCode.DE,
  TranslationLanguageCode.ES,
  TranslationLanguageCode.RU,
  TranslationLanguageCode.PT,
  // Keep the exposed language list aligned with product support
  TranslationLanguageCode.IT,
  TranslationLanguageCode.VI,
  TranslationLanguageCode.TH,
  TranslationLanguageCode.ID
]

export enum AppLanguageCode {
  Auto = 'auto',
  ZhCN = 'zh-CN',
  EnUS = 'en-US'
}
