/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEUserWithFriend } from '@nimkit/chatkit';
import { V2NIMTeam } from '@nimsdk/base';

interface SearchListModelParams {
  userInfo?: NEUserWithFriend;
  team?: V2NIMTeam;
}

@ObservedV2
export class SearchListModel {
  @Trace userInfo?: NEUserWithFriend;
  @Trace team?: V2NIMTeam;

  constructor(params: SearchListModelParams) {
    if (params.userInfo) {
      this.userInfo = params.userInfo
    }

    if (params.team) {
      this.team = params.team
    }
  }
}