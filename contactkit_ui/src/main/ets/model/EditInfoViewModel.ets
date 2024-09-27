/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ContactRepo } from '@nimkit/chatkit';
import { NECommonUtils } from '@nimkit/common';

export class EditInfoViewModel {
  public saveName(name?: string) {
    ContactRepo.updateSelfUserProfile({
      name: name
    })
    NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
  }

  public saveAvatar(avatar?: string) {
    ContactRepo.updateSelfUserProfile({
      avatar: avatar
    })
    NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
  }

  public saveSign(sign?: string) {
    ContactRepo.updateSelfUserProfile({
      sign: sign
    })
    NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
  }

  public saveEmail(email?: string) {
    ContactRepo.updateSelfUserProfile({
      email: email
    })
    NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
  }

  public saveBirthday(birthday?: string) {
    ContactRepo.updateSelfUserProfile({
      birthday: birthday
    })
    NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
  }

  public saveMobile(mobile?: string) {
    ContactRepo.updateSelfUserProfile({
      mobile: mobile
    })
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