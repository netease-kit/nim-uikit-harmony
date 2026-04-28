/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import localUnitTest from './LocalUnit.test';
import teamJoinManageTest from './TeamJoinManage.test';

export default function testsuite() {
  localUnitTest();
  teamJoinManageTest();
}