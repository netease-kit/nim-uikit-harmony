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

  constructor(onClickSureButton?: (selectedList: NEUserWithFriend[]) => void, filterList: string[] = [],
    selectLimit: number = 200) {
    this.filterList = filterList
    this.selectLimit = selectLimit
    this.onClickSureButton = onClickSureButton
  }
}