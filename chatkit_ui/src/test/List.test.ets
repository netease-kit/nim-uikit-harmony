/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import lastReadPositionUtilsTest from './LastReadPositionUtils.test';
import aitMemberSearchUtilsTest from './AitMemberSearchUtils.test';
import messageReactionUtilsTest from './MessageReactionUtils.test';
import messageReactionManagerTest from './MessageReactionManager.test';
import neEmojiManagerTest from './NEEmojiManager.test';
import emoticonPaginationUtilsTest from './EmoticonPaginationUtils.test';
import stickerFileUtilsTest from './StickerFileUtils.test';
import chatTeamMuteStateUtilsTest from './ChatTeamMuteStateUtils.test';

export default function testsuite() {
  lastReadPositionUtilsTest();
  aitMemberSearchUtilsTest();
  messageReactionUtilsTest();
  messageReactionManagerTest();
  neEmojiManagerTest();
  emoticonPaginationUtilsTest();
  stickerFileUtilsTest();
  chatTeamMuteStateUtilsTest();
}
