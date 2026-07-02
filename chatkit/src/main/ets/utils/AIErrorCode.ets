/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * 数字人相关错误码
 * 对齐 Android AIErrorCode.kt
 */
export class AIErrorCode {
  // 请求大语言模型失败
  static readonly V2NIM_ERROR_CODE_FAILED_TO_REQUEST_LLM = 189308
  // AI消息功能未开通
  static readonly V2NIM_ERROR_CODE_AI_MESSAGES_FUNCTION_DISABLED = 107337
  // 不是数字人账号
  static readonly V2NIM_ERROR_CODE_IS_NOT_AI_ACCOUNT = 102304
  // 不允许对数字人进行黑名单操作
  static readonly V2NIM_ERROR_CODE_AI_ACCOUNT_BLOCKLIST_OPERATION_NOT_ALLOWED = 106403
  // 参数错误
  static readonly V2NIM_ERROR_CODE_PARAMETER_ERROR = 414
  // AI消息格式不支持
  static readonly AI_ERROR_TIPS_CODE = 107336
  // 不存在
  static readonly V2NIM_ERROR_CODE_ACCOUNT_NOT_EXIST = 102404
  static readonly V2NIM_ERROR_CODE_FRIEND_NOT_EXIST = 104404
  // 账号被封禁
  static readonly V2NIM_ERROR_CODE_ACCOUNT_BANNED = 102422
  // 账号被禁言
  static readonly V2NIM_ERROR_CODE_ACCOUNT_CHAT_BANNED = 102421
  // 命中反垃圾
  static readonly V2NIM_ERROR_CODE_MESSAGE_HIT_ANTISPAM = 107451
  // 群成员不存在
  static readonly V2NIM_ERROR_CODE_TEAM_MEMBER_NOT_EXIST = 109404
  // 群普通成员被禁言
  static readonly V2NIM_ERROR_CODE_TEAM_NORMAL_MEMBER_CHAT_BANNED = 108306
  // 群被禁言
  static readonly V2NIM_ERROR_CODE_TEAM_MEMBER_CHAT_BANNED = 109424
  // 频控
  static readonly V2NIM_ERROR_CODE_RATE_LIMIT = 416
}
