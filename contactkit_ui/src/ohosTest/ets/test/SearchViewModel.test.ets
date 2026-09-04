/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import { NEFriendUserCache } from '@nimkit/chatkit'
import { V2NIMFriend, V2NIMUser } from '@nimsdk/base'
import { SearchViewModel } from '../../../main/ets/viewmodel/SearchViewModel'

class MockFriend {
  accountId: string = 'friend_1'
  alias?: string = '旧备注'
}

class MockUser {
  accountId: string = 'friend_1'
  name?: string = '旧名称'
}

export default function searchViewModelTest() {
  describe('SearchViewModel_profile_refresh', () => {
    it('should_recalculate_current_search_when_user_profile_changes', 0, () => {
      const cache = NEFriendUserCache.getInstance()
      cache.friendCache.clear()
      cache.blockAccountList = []
      cache.updateFriendInfo({
        friend: new MockFriend() as V2NIMFriend,
        user: new MockUser() as V2NIMUser
      })
      const viewModel = new SearchViewModel()

      viewModel.doSearch('新名称')
      expect(viewModel.friendData.length).assertEqual(0)

      const updatedUser = new MockUser()
      updatedUser.name = '新名称'
      cache.updateFriendInfo({ user: updatedUser as V2NIMUser })
      viewModel.updateUserInfoFun([updatedUser as V2NIMUser])

      expect(viewModel.friendData.length).assertEqual(1)
      expect(viewModel.friendData[0].userInfo?.showName()).assertEqual('旧备注')
      viewModel.onDestroy()
      cache.friendCache.clear()
    })

    it('should_keep_results_empty_when_profile_changes_without_keyword', 0, () => {
      const cache = NEFriendUserCache.getInstance()
      cache.friendCache.clear()
      cache.blockAccountList = []
      cache.updateFriendInfo({
        friend: new MockFriend() as V2NIMFriend,
        user: new MockUser() as V2NIMUser
      })
      const viewModel = new SearchViewModel()

      const updatedUser = new MockUser()
      updatedUser.name = '新名称'
      cache.updateFriendInfo({ user: updatedUser as V2NIMUser })
      viewModel.updateUserInfoFun([updatedUser as V2NIMUser])

      expect(viewModel.friendData.length).assertEqual(0)
      expect(viewModel.discussData.length).assertEqual(0)
      expect(viewModel.seniorData.length).assertEqual(0)
      viewModel.onDestroy()
      cache.friendCache.clear()
    })
  })
}
