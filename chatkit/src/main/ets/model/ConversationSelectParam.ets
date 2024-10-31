/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ConversationSelectModel } from './ConversationSelectModel';


export class ConversationSelectParam {
  filterList?: string[] = [];
  selectLimit: number = 200;
  onSureButtonClick?: (selectedList: ConversationSelectModel[]) => void = undefined

  constructor(filterList: string[] = [],
    selectLimit: number = 200,
    onSureButtonClick?: (selectedList: ConversationSelectModel[]) => void
  ) {
    this.filterList = filterList
    this.selectLimit = selectLimit
    this.onSureButtonClick = onSureButtonClick
  }
}