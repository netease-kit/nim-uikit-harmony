/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import localUnitTest from './LocalUnit.test';
import chatJumpUtilsTest from './ChatJumpUtils.test';
import chatUtilsTest from './ChatUtils.test';
import dateUtilsTest from './DateUtils.test';
import fileUtilsTest from './FileUtils.test';
import messageHelperTest from './MessageHelper.test';
import chatConstAndModelTest from './ChatConstAndModel.test';
import conversationConstantTest from './ConversationConstant.test';
import emojiManagerTest from './EmojiManager.test';
import typingStatusTest from './TypingStatus.test';
import textLinkifyTest from './TextLinkify.test';
import linkClickTest from './LinkClick.test';
import inputTransferUtilsTest from './InputTransferUtils.test';
import audioPlaybackPolicyTest from './AudioPlaybackPolicy.test';
import aitRoutingUtilsTest from './AitRoutingUtils.test';
import aitAIUserUtilsTest from './AitAIUserUtils.test';
import aiResponseOperationTest from './AIResponseOperation.test';
import aiSearchMenuUtilsTest from './AISearchMenuUtils.test';
import chatConstTest from './ChatConst.test';
import isReceiveMsgTest from './IsReceiveMsg.test';
import chatModelTest from './ChatModel.test';
import topMessageBarUtilsTest from './TopMessageBarUtils.test';
import aiChatUtilsTest from './AIChatUtils.test';
import chatOperationMenuTest from './ChatOperationMenu.test';
import aiHelperUtilsTest from './AIHelperUtils.test';
import chatUserInfoTest from './ChatUserInfo.test';

export default function testsuite() {
  localUnitTest();
  chatJumpUtilsTest();
  chatUtilsTest();
  dateUtilsTest();
  fileUtilsTest();
  messageHelperTest();
  chatConstAndModelTest();
  conversationConstantTest();
  emojiManagerTest();
  typingStatusTest();
  textLinkifyTest();
  linkClickTest();
  inputTransferUtilsTest();
  audioPlaybackPolicyTest();
  aitRoutingUtilsTest();
  aitAIUserUtilsTest();
  aiResponseOperationTest();
  aiSearchMenuUtilsTest();
  chatConstTest();
  isReceiveMsgTest();
  chatModelTest();
  topMessageBarUtilsTest();
  aiChatUtilsTest();
  chatOperationMenuTest();
  aiHelperUtilsTest();
  chatUserInfoTest();
}
