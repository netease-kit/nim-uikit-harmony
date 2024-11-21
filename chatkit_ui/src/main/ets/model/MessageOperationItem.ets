/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export enum MessageOperationType {
  // 删除
  Delete = 1,
  // 复制
  Copy = 2,
  // 撤回
  Undo = 3,
  // 转发
  Forward = 4,
  //标记
  Pin = 5,
  //取消标记
  Unpin = 6,
  // 多选
  Select = 7,
  // 收藏
  Collection = 8,
  // 回复
  Reply = 9
}

export class MessageOperationItem {
  // 操作提示图片
  operationImage?: ResourceStr;
  // 操作提示文字
  operationText?: ResourceStr;
  // 操作类型
  operationType: MessageOperationType = MessageOperationType.Delete;
}