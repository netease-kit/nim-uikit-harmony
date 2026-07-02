/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import localUnitTest from './LocalUnit.test';
import JSONUtilTest from './JSONUtil.test';
import DateUtilTest from './DateUtil.test';
import StringExtendTest from './StringExtend.test';
import CommonConstantsTest from './CommonConstants.test';
import DateConstTest from './DateConst.test';
import BreakpointConstantsTest from './BreakpointConstants.test';
import CommonUtilsTest from './CommonUtils.test';
import AppLanguageUtilsTest from './AppLanguageUtils.test';

export default function testsuite() {
  localUnitTest();
  JSONUtilTest();
  DateUtilTest();
  StringExtendTest();
  CommonConstantsTest();
  DateConstTest();
  BreakpointConstantsTest();
  CommonUtilsTest();
  AppLanguageUtilsTest();
}
