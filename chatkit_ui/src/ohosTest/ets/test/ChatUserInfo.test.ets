/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { NIMInterface, V2NIMFriend, V2NIMUser } from '@nimsdk/base';
import { ChatKitClient } from '@nimkit/chatkit';
import { ChatUserInfo } from '../../../main/ets/model/ChatUserInfo';
import { ChatP2PViewModel } from '../../../main/ets/viewmodel/ChatP2PViewModel';

class TestUser implements V2NIMUser {
  readonly accountId: string
  readonly name: string
  readonly avatar: string
  readonly createTime: number = 0

  constructor(accountId: string, name: string, avatar: string) {
    this.accountId = accountId
    this.name = name
    this.avatar = avatar
  }
}

class TestFriend implements V2NIMFriend {
  readonly accountId: string
  readonly alias: string

  constructor(accountId: string, alias: string) {
    this.accountId = accountId
    this.alias = alias
  }
}

class MockListenerService {
  on(): void {
  }

  off(): void {
  }
}

class MockLoginService extends MockListenerService {
  getLoginUser(): string {
    return 'loginUser'
  }
}

class MockConversationIdUtil {
  parseConversationTargetId(conversationId: string): string {
    return conversationId
  }
}

class MockNim {
  loginService: MockLoginService = new MockLoginService()
  userService: MockListenerService = new MockListenerService()
  friendService: MockListenerService = new MockListenerService()
  conversationIdUtil: MockConversationIdUtil = new MockConversationIdUtil()
}

function makeUser(accountId: string, name: string, avatar: string): V2NIMUser {
  return new TestUser(accountId, name, avatar)
}

function mockChatKitClient(): void {
  ChatKitClient.nim = new MockNim() as Object as NIMInterface
}

export default function chatUserInfoTest() {
  describe('ChatUserInfo_extra_user_profile', () => {
    it('should_use_extra_user_for_non_target_sender_name_and_avatar', 0, () => {
      mockChatKitClient()
      const chatUserInfo = new ChatUserInfo()
      chatUserInfo.setChatUser(makeUser('targetA', '会话对方', 'https://example.com/target.png'))
      chatUserInfo.setChatFriend(new TestFriend('targetA', '好友备注'))
      chatUserInfo.addExtraUsers([
        makeUser('extraB', '张三', 'https://example.com/extra.png')
      ])

      expect(chatUserInfo.getChatUserShowName('extraB')).assertEqual('张三')
      expect(chatUserInfo.getChatUserAvatarName('extraB')).assertEqual('张三')
      expect(chatUserInfo.getChatUserAvatarUrl('extraB')).assertEqual('https://example.com/extra.png')
    })

    it('should_update_existing_extra_user_profile', 0, () => {
      mockChatKitClient()
      const chatUserInfo = new ChatUserInfo()
      chatUserInfo.addExtraUsers([
        makeUser('extraB', '旧名', 'https://example.com/old.png')
      ])

      const updated = chatUserInfo.updateExtraUser(
        makeUser('extraB', '新名', 'https://example.com/new.png')
      )

      expect(updated).assertTrue()
      expect(chatUserInfo.getChatUserShowName('extraB')).assertEqual('新名')
      expect(chatUserInfo.getChatUserAvatarName('extraB')).assertEqual('新名')
      expect(chatUserInfo.getChatUserAvatarUrl('extraB')).assertEqual('https://example.com/new.png')
    })

    it('should_update_current_user_profile_by_login_account_event', 0, () => {
      mockChatKitClient()
      const chatUserInfo = new ChatUserInfo()
      const viewModel = new ChatP2PViewModel()
      viewModel.chatUserInfo = chatUserInfo

      viewModel.onUserProfileChangedFun([
        makeUser('loginUser', '登录用户', 'https://example.com/mine.png')
      ])

      expect(chatUserInfo.getCurrentUserShowName()).assertEqual('登录用户')
      expect(chatUserInfo.getCurrentUserAvatarName()).assertEqual('登录用户')
      expect(chatUserInfo.getCurrentUserAvatarUrl()).assertEqual('https://example.com/mine.png')
    })

    it('should_ignore_unknown_extra_user_update', 0, () => {
      mockChatKitClient()
      const chatUserInfo = new ChatUserInfo()

      const updated = chatUserInfo.updateExtraUser(
        makeUser('extraB', '新名', 'https://example.com/new.png')
      )

      expect(updated).assertFalse()
      expect(chatUserInfo.getChatUserShowName('extraB')).assertEqual('extraB')
    })
  })
}
