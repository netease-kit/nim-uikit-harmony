/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

/**
 * Common constants for all features.
 */
export class ChatConst {
  //消息分页拉取，每页大小
  static readonly chatMessagePageSize: number = 50;
  // 图片消息图片的高度
  static readonly imageMessageHeight: number = 124;
  // 图片消息图片的宽度
  static readonly imageMessageWidth: number = 222;
  // 合并转发消息高度
  static readonly mergedMessageHeight: number = 130;
  // 合并转发消息最小宽度
  static readonly mergedMessageMinHeight: number = 80;
  // 消息单行高度 vp
  static readonly messageLineHeight: number = 60;
  // 文本消息单行高度 vp
  static readonly textLineHeight: number = 20;
  //文本消息字体大小
  static readonly messageTextFontSize: number = 14;
  // 地图消息默认高度 vp
  static readonly mapMessageHeight: number = 160;
  // 文件消息默认宽度 vp
  static readonly fileMessageWidth: number = 60;
  // 语音消息默认宽度 vp
  static readonly audioMessageWidth: number = 35;
  // 消息输入区域高度
  static readonly messageInputAreaHeight: number = 180;
  // 消息长按菜单每个item的宽度
  static readonly menuItemWidth: number = 60;
  static readonly menuItemHeight: number = 66;
  // 消息长按菜单列数
  static readonly menuItemColumnNum: number = 5;
  // PIN 消息操作者名称最大长度
  static readonly pinOperatorNameMaxLen: number = 15;
  // 消息撤回本地存储，是否为本端撤回消息
  static readonly revokeLocalKey: string = 'revoke_message_local';
  // 消息撤回本地存储，撤回时间
  static readonly revokeLocalTimeKey: string = 'revoke_message_local_time';
  // 消息撤回本地存储，撤回的消息clientId
  static readonly revokeMsgClientIdKey: string = 'revoke_message_client_id';
  // 消息撤回本地存储，撤回的消息内容
  static readonly revokeMsgTextKey: string = 'revoke_message_local_content';
  // 消息撤回本地存储，撤回的消息是否为编辑状态
  static readonly revokeMsgEditKey: string = 'revoke_message_local_edit';
  // 消息删除限制
  static readonly messageDeleteLimit: number = 50;
}