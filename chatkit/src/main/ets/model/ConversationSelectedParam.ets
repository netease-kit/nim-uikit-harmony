/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ConversationSelectModel } from './ConversationSelectModel';


export class ConversationSelectedParam {
  selectedList?: ConversationSelectModel[] = [];
  onRemoveButtonClick?: (item: ConversationSelectModel) => void = undefined // 移除按钮点击事件

  constructor(selectedList?: ConversationSelectModel[],
    onRemoveButtonClick?: (item: ConversationSelectModel) => void
  ) {
    this.selectedList = selectedList
    this.onRemoveButtonClick = onRemoveButtonClick
  }
}