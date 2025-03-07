/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ContactRepo, NEFriendUserCache } from '@nimkit/chatkit';
import { NECommonUtils } from '@nimkit/common';

export class EditInfoViewModel {
  public async saveAvatar(avatar?: string) {
    await ContactRepo.updateSelfUserProfile({
      avatar: avatar
    })
    NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
  }

  public saveBirthday(birthday?: string) {
    ContactRepo.updateSelfUserProfile({
      birthday: birthday
    })
    if (NEFriendUserCache.mineUserCache?.user) {
      // NEFriendUserCache.mineUserCache.user.birthday = birthday
    }
    NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
  }


  public saveGender(gender?: number) {
    ContactRepo.updateSelfUserProfile({
      gender: gender
    })
    NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
  }

  public saveServerExtension(serverExtension?: string) {
    ContactRepo.updateSelfUserProfile({
      serverExtension: serverExtension
    })
  }
}