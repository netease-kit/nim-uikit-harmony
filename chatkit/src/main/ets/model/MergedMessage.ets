/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

// 用于显示合并后的消息的发送方Nick的key
export const mergedMessageNickKey: string = 'mergedMessageNickKey';

// 用于显示合并后的消息的发送方avatar的key
export const mergedMessageAvatarKey: string = 'mergedMessageAvatarKey';


//默认合并转发最大深度
export const defaultMaxDepth: number = 3;

// 合并消息
export interface MergedMessage {

  // 会话id
  sessionId: string;

  // 会话名称
  sessionName: string;

  // 合并消息上传NOS后的url
  url: string;

  // 合并消息文件的md5
  md5?: string;

  // 合并消息的深度
  depth?: number;

  // 合并消息的摘要，用于在消息列表展示，默认三条
  abstracts: MergeMessageAbstract[];

  // 合并消息的id，用于标识合并消息
  // 通[NIMMessage.uuid]获取
  messageId?: string;
}

// 合并转发消息的缩略
export interface MergeMessageAbstract {
  // 消息展示的nick，只取fromNick，没有就accId
  senderNick: string;

  // 内容，不是Text的显示缩略
  content: string;

  // 发送方的accId
  userAccId: string;

}

// 消息上传后的信息
export interface MessageUploadInfo {
  url: string;
  md5: string;
}