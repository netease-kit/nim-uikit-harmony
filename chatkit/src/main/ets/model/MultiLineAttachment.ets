/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { multiLineMessageCustomType } from '../constant/Constant';
import { V2NIMMessage, V2NIMMessageAttachment, V2NIMMessageType } from '@nimsdk/base';

/**
 * 换行消息附件数据结构
 */
export interface MultiLineAttachmentData {
  title: string;
  body: string;
}

/**
 * 换行消息附件
 * 用于换行消息功能，支持标题+正文的消息格式
 * 消息类型为自定义消息 (type=102)
 */
export interface MultiLineAttachment {
  type: number;  // 102
  data: MultiLineAttachmentData;
}

export const MULTI_LINE_TITLE_MAX_LENGTH: number = 20

export function normalizeMultiLineTitle(title: string): string {
  if (!title) {
    return ''
  }
  const singleLineTitle = title.replace(/\r\n/g, '').replace(/[\r\n]/g, '')
  return singleLineTitle.substring(0, MULTI_LINE_TITLE_MAX_LENGTH)
}

/**
 * 解析换行消息附件
 * @param attachmentStr 附件 JSON 字符串
 * @returns 解析后的 MultiLineAttachment，解析失败返回 null
 */
export function parseMultiLineAttachment(attachmentStr: string | undefined): MultiLineAttachment | null {
  if (!attachmentStr) {
    return null;
  }
  try {
    const attachment = JSON.parse(attachmentStr) as MultiLineAttachment;
    if (attachment.type === multiLineMessageCustomType && attachment.data) {
      return attachment;
    }
    return null;
  } catch (e) {
    Logger.error('ChatKit', `parseMultiLineAttachment failed: ${e}`);
    return null;
  }
}

/**
 * 创建换行消息附件 JSON 字符串
 * @param title 标题
 * @param body 正文
 * @returns 附件 JSON 字符串
 */
export function createMultiLineAttachment(title: string, body: string): string {
  const normalizedTitle = normalizeMultiLineTitle(title)
  const attachment: MultiLineAttachment = {
    type: multiLineMessageCustomType,
    data: {
      title: normalizedTitle,
      body
    }
  };
  return JSON.stringify(attachment);
}

/**
 * 判断消息是否为换行消息
 * @param message V2NIM 消息
 * @returns true 表示是换行消息
 */
export function isMultiLineMessage(message: V2NIMMessage): boolean {
  if (message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
    return false;
  }
  const attachment = parseMultiLineAttachment(message.attachment?.raw);
  return attachment !== null;
}

/**
 * 获取换行消息的标题
 * @param message V2NIM 消息
 * @returns 标题字符串，不是换行消息则返回空字符串
 */
export function getMultiLineTitle(message: V2NIMMessage): string {
  const attachment = parseMultiLineAttachment(message.attachment?.raw);
  return attachment?.data?.title ?? '';
}

/**
 * 获取换行消息的正文
 * @param message V2NIM 消息
 * @returns 正文字符串，不是换行消息则返回空字符串
 */
export function getMultiLineBody(message: V2NIMMessage): string {
  const attachment = parseMultiLineAttachment(message.attachment?.raw);
  return attachment?.data?.body ?? '';
}

/**
 * 获取换行消息的预览文本（用于聊天页面的完整消息）
 * 优先显示标题，标题为空则显示正文
 * @param message V2NIM 消息
 * @returns 预览文本
 */
export function getMultiLinePreview(message: V2NIMMessage): string {
  const attachment = parseMultiLineAttachment(message.attachment?.raw);
  if (!attachment) {
    return '';
  }
  const title = attachment.data?.title ?? '';
  const body = attachment.data?.body ?? '';
  return title.length > 0 ? title : body;
}

/**
 * 从 attachment 对象获取换行消息的预览文本（用于会话列表）
 * 优先显示标题，标题为空则显示正文
 * @param attachment 消息附件
 * @returns 预览文本
 */
export function getMultiLinePreviewFromAttachment(attachment: V2NIMMessageAttachment | undefined): string {
  if (!attachment) {
    return '';
  }
  const multiLine = parseMultiLineAttachment(attachment.raw);
  if (!multiLine) {
    return '';
  }
  const title = multiLine.data?.title ?? '';
  const body = multiLine.data?.body ?? '';
  return title.length > 0 ? title : body;
}
