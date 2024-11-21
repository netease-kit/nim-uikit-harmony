/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export enum NEChatMoreOperationType {
  Video = 1,
  File = 2,
  Location = 3
}

export class NEChatMoreOperationData {
  type?: NEChatMoreOperationType;
  operationTitle?: ResourceStr;
  imageSource?: string;
}