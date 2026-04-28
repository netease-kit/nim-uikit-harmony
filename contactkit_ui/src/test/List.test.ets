/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import localUnitTest from './LocalUnit.test';
import contactVerifyUnreadTest from './ContactVerifyUnread.test';
import teamVerifyViewModelTest from './TeamVerifyViewModel.test';
import teamProfilePageTest from './TeamProfilePage.test';

export default function testsuite() {
  localUnitTest();
  contactVerifyUnreadTest();
  teamVerifyViewModelTest();
  teamProfilePageTest();
}
