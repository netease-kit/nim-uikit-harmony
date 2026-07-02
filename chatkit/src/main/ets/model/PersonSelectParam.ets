/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEUserWithFriend } from './NEUserWithFriend';

export class PersonSelectParam {
  filterList?: string[] = [];
  selectLimit: number = 200;
  onClickSureButton?: (selectedList: NEUserWithFriend[]) => void = undefined
  showAIUsers: boolean = false

  constructor(onClickSureButton?: (selectedList: NEUserWithFriend[]) => void, filterList: string[] = [],
    selectLimit: number = 200, showAIUsers: boolean = false) {
    this.filterList = filterList
    this.selectLimit = selectLimit
    this.onClickSureButton = onClickSureButton
    this.showAIUsers = showAIUsers
  }
}
