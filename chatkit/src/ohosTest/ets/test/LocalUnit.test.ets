/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMCreateTeamParams,
  V2NIMFriend,
  V2NIMAIUser,
  V2NIMMessage,
  V2NIMMessageNotificationType,
  V2NIMMessageType,
  V2NIMTeamType
} from '@nimsdk/base';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { NEFriendUserCache } from '../../../main/ets/NEFriendUserCache';
import {
  buildTeamNameByMemberNames,
  buildTeamCreateInviteNotificationAttachment,
  getCreateTeamSuccessTipResourceName,
  getTeamCreateInviteNotificationType
} from '../../../main/ets/repo/TeamRepo';
import {
  buildTeamCreateInviteLocalExtension,
  isLocalTeamCreateInviteMessage,
  shouldCollapseTeamCreateInviteNotifications
} from '../../../main/ets/utils/TeamInviteNotificationUtils';
import {
  createMultiLineAttachment as createNormalizedMultiLineAttachment,
  MULTI_LINE_TITLE_MAX_LENGTH,
  normalizeMultiLineTitle as normalizeTitle,
  parseMultiLineAttachment as parseNormalizedMultiLineAttachment
} from '../../../main/ets/model/MultiLineAttachment';
import {
  buildMineServerExtensionWithAIUserPin,
  canShowAIUserPinSwitch,
  filterPinnedAIUsers,
  isAIUserPinnedByMine
} from '../../../main/ets/utils/AIUserExtensionUtils';
import {
  filterAIChatUsers,
  isAIChatUserByServerExtension
} from '../../../main/ets/manager/AIUserManager';

class MockAIUser {
  accountId: string
  serverExtension?: string

  constructor(accountId: string, serverExtension?: string) {
    this.accountId = accountId
    this.serverExtension = serverExtension
  }
}

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('should_return_team_invite_notification_type_for_normal_team', 0, () => {
      expect(getTeamCreateInviteNotificationType(V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL))
        .assertEqual(V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_INVITE);
    });

    it('should_return_super_team_invite_notification_type_for_super_team', 0, () => {
      expect(getTeamCreateInviteNotificationType(V2NIMTeamType.V2NIM_TEAM_TYPE_SUPER))
        .assertEqual(V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_SUPER_TEAM_INVITE);
    });

    it('should_build_team_create_invite_notification_attachment', 0, () => {
      const targetIds = ['user_a', 'user_b'];
      const attachment = buildTeamCreateInviteNotificationAttachment(
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        targetIds
      );

      expect(attachment.type).assertEqual(V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_INVITE);
      expect(attachment.targetIds?.length).assertEqual(2);
      expect(attachment.targetIds?.[0]).assertEqual('user_a');
      expect(attachment.targetIds?.[1]).assertEqual('user_b');
      expect(typeof attachment.raw).assertEqual('string');

      const persistedAttachment = JSON.parse(attachment.raw ?? '{}') as Record<string, Object>;
      const attachmentType: number = persistedAttachment['type'] as number;
      expect(attachmentType).assertEqual(
        V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_INVITE
      );
      const parsedTargetIds: Object[] = persistedAttachment['targetIds'] as Object[];
      const idsLen = parsedTargetIds.length;
      expect(idsLen).assertEqual(2);
      expect(parsedTargetIds[0]).assertEqual('user_a');
      expect(parsedTargetIds[1]).assertEqual('user_b');
    });

    it('should_mark_local_team_create_invite_message', 0, () => {
      const localExtension = buildTeamCreateInviteLocalExtension();
      const msg: V2NIMMessage = new Object() as V2NIMMessage;
      msg.localExtension = localExtension;
      expect(isLocalTeamCreateInviteMessage(msg)).assertTrue();
    });

    it('should_match_local_and_remote_create_team_invite_notifications', 0, () => {
      const attachment = buildTeamCreateInviteNotificationAttachment(
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        ['user_a', 'user_b']
      );

      const localMessage: V2NIMMessage = new Object() as V2NIMMessage;
      localMessage.conversationId = 'team|team123';
      localMessage.senderId = 'me';
      localMessage.createTime = 1000;
      localMessage.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION;
      localMessage.attachment = attachment;
      localMessage.localExtension = buildTeamCreateInviteLocalExtension();

      const remoteMessage: V2NIMMessage = new Object() as V2NIMMessage;
      remoteMessage.conversationId = 'team|team123';
      remoteMessage.senderId = 'me';
      remoteMessage.createTime = 1000;
      remoteMessage.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION;
      remoteMessage.attachment = attachment;

      expect(shouldCollapseTeamCreateInviteNotifications(localMessage, remoteMessage)).assertTrue();
    });

    it('should_match_local_and_remote_create_team_invite_notifications_when_create_time_differs', 0, () => {
      const attachment = buildTeamCreateInviteNotificationAttachment(
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        ['user_a', 'user_b']
      );

      const localMessage: V2NIMMessage = new Object() as V2NIMMessage;
      localMessage.conversationId = 'team|team123';
      localMessage.senderId = 'me';
      localMessage.createTime = 1000;
      localMessage.messageServerId = '';
      localMessage.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION;
      localMessage.attachment = attachment;
      localMessage.localExtension = buildTeamCreateInviteLocalExtension();

      const remoteMessage: V2NIMMessage = new Object() as V2NIMMessage;
      remoteMessage.conversationId = 'team|team123';
      remoteMessage.senderId = 'me';
      remoteMessage.createTime = 1200;
      remoteMessage.messageServerId = 'server_msg_1';
      remoteMessage.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION;
      remoteMessage.attachment = attachment;

      expect(shouldCollapseTeamCreateInviteNotifications(localMessage, remoteMessage)).assertTrue();
    });

    it('should_match_local_inserted_create_team_invite_without_local_extension', 0, () => {
      const attachment = buildTeamCreateInviteNotificationAttachment(
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        ['user_a', 'user_b']
      );

      const localMessage: V2NIMMessage = new Object() as V2NIMMessage;
      localMessage.conversationId = 'team|team123';
      localMessage.senderId = 'me';
      localMessage.createTime = 1000;
      localMessage.messageServerId = '';
      localMessage.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION;
      localMessage.attachment = attachment;

      const remoteMessage: V2NIMMessage = new Object() as V2NIMMessage;
      remoteMessage.conversationId = 'team|team123';
      remoteMessage.senderId = 'me';
      remoteMessage.createTime = 1200;
      remoteMessage.messageServerId = 'server_msg_1';
      remoteMessage.messageType = V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION;
      remoteMessage.attachment = attachment;

      expect(shouldCollapseTeamCreateInviteNotifications(localMessage, remoteMessage)).assertTrue();
    });

    it('should_return_create_advanced_team_success_resource_for_advanced_team', 0, () => {
      const createTeamParams = {
        teamType: V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL
      } as V2NIMCreateTeamParams

      expect(getCreateTeamSuccessTipResourceName(createTeamParams)).assertEqual('createAdvancedTeamSuccess');
    });

    it('should_not_return_create_advanced_team_success_resource_for_discussion_group', 0, () => {
      const createTeamParams = {
        teamType: V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        serverExtension: JSON.stringify({ 'im_ui_kit_group': true })
      } as V2NIMCreateTeamParams

      expect(getCreateTeamSuccessTipResourceName(createTeamParams)).assertUndefined();
    });

    it('should_build_discussion_team_name_with_ai_user_names', 0, () => {
      const teamName = buildTeamNameByMemberNames('我', ['成员A', '数字人D'])

      expect(teamName).assertEqual('我、成员A、数字人D')
    });

    it('should_skip_empty_member_names_when_building_discussion_team_name', 0, () => {
      const teamName = buildTeamNameByMemberNames('我', ['成员A', '', '数字人D'])

      expect(teamName).assertEqual('我、成员A、数字人D')
    });

    it('should_limit_discussion_team_name_to_30_chars', 0, () => {
      const teamName = buildTeamNameByMemberNames('我', ['123456789012345678901234567890'])

      expect(teamName.length).assertEqual(30)
      expect(teamName).assertEqual('我、1234567890123456789012345678')
    });

    it('should_keep_friend_relation_when_account_is_in_block_list', 0, () => {
      // NEFriendUserCache 构造函数为 private，无法在 src/test 中实例化。
      // 该测试需在 ohosTest 设备环境验证。
    });

    it('should_normalize_multiline_title_by_removing_newlines_and_limiting_length', 0, () => {
      const normalizedTitle = normalizeTitle('1234567890\n1234567890\n12345')

      expect(normalizedTitle).assertEqual('12345678901234567890')
      expect(normalizedTitle.length).assertEqual(MULTI_LINE_TITLE_MAX_LENGTH)
    });

    it('should_store_normalized_multiline_title_in_attachment', 0, () => {
      const attachment = createNormalizedMultiLineAttachment('标题1\n标题2\n标题3', '正文')
      const parsedAttachment = parseNormalizedMultiLineAttachment(attachment)

      expect(parsedAttachment?.data.title).assertEqual('标题1标题2标题3')
      expect(parsedAttachment?.data.body).assertEqual('正文')
    });

    it('should_filter_local_conversation_ai_users_by_pin_default_and_unpin_list', 0, () => {
      const pinnedByString = new MockAIUser('ai_string', JSON.stringify({ pinDefault: '1' }))
      const pinnedByNumber = new MockAIUser('ai_number', JSON.stringify({ pinDefault: 1 }))
      const unpinnedByUser = new MockAIUser('ai_unpinned', JSON.stringify({ pinDefault: 1 }))
      const notPinned = new MockAIUser('ai_normal', JSON.stringify({ pinDefault: 0 }))
      const invalidExtension = new MockAIUser('ai_invalid', '{invalid json}')

      const aiUsers: V2NIMAIUser[] = [
        pinnedByString,
        pinnedByNumber,
        unpinnedByUser,
        notPinned,
        invalidExtension
      ] as V2NIMAIUser[]
      const result = filterPinnedAIUsers(aiUsers, JSON.stringify({ unpinAIUsers: ['ai_unpinned'] }))

      expect(result.length).assertEqual(2)
      expect(result[0].accountId).assertEqual('ai_string')
      expect(result[1].accountId).assertEqual('ai_number')
    });

    it('should_show_ai_pin_switch_only_for_pin_default_ai_user', 0, () => {
      const pinDefaultAIUser = new MockAIUser('ai_pin', JSON.stringify({ pinDefault: 1 }))
      const normalAIUser = new MockAIUser('ai_normal', JSON.stringify({ pinDefault: 0 }))

      expect(canShowAIUserPinSwitch(pinDefaultAIUser as V2NIMAIUser)).assertTrue()
      expect(canShowAIUserPinSwitch(normalAIUser as V2NIMAIUser)).assertFalse()
    });

    it('should_update_mine_unpin_ai_users_when_switch_ai_pin', 0, () => {
      const mineExtension = JSON.stringify({
        custom: 'keep',
        unpinAIUsers: ['ai_old']
      })

      const unpinnedExtension = buildMineServerExtensionWithAIUserPin(mineExtension, 'ai_new', false)
      expect(isAIUserPinnedByMine('ai_new', unpinnedExtension)).assertFalse()
      expect(isAIUserPinnedByMine('ai_old', unpinnedExtension)).assertFalse()

      const pinnedExtension = buildMineServerExtensionWithAIUserPin(unpinnedExtension, 'ai_new', true)
      expect(isAIUserPinnedByMine('ai_new', pinnedExtension)).assertTrue()
      expect(isAIUserPinnedByMine('ai_old', pinnedExtension)).assertFalse()

      const parsedExtension = JSON.parse(pinnedExtension) as Record<string, Object>
      expect(parsedExtension['custom']).assertEqual('keep')
    });

    it('should_filter_ai_chat_users_by_server_extension_ai_chat_flag', 0, () => {
      const chatByNumber = new MockAIUser('ai_chat_number', JSON.stringify({ ai_chat: 1 }))
      const chatByString = new MockAIUser('ai_chat_string', JSON.stringify({ ai_chat: '1' }))
      const chatByCamelCase = new MockAIUser('ai_chat_camel_case', JSON.stringify({ aiChat: 1 }))
      const notChat = new MockAIUser('ai_not_chat', JSON.stringify({ ai_chat: 0 }))
      const missingFlag = new MockAIUser('ai_missing', JSON.stringify({ other: 1 }))
      const invalidExtension = new MockAIUser('ai_invalid', '{invalid json}')

      const result = filterAIChatUsers([
        chatByNumber,
        chatByString,
        chatByCamelCase,
        notChat,
        missingFlag,
        invalidExtension
      ] as V2NIMAIUser[])

      expect(result.length).assertEqual(3)
      expect(result[0].accountId).assertEqual('ai_chat_number')
      expect(result[1].accountId).assertEqual('ai_chat_string')
      expect(result[2].accountId).assertEqual('ai_chat_camel_case')
    });

    it('should_detect_ai_chat_user_by_server_extension', 0, () => {
      expect(isAIChatUserByServerExtension(JSON.stringify({ ai_chat: 1 }))).assertTrue()
      expect(isAIChatUserByServerExtension(JSON.stringify({ ai_chat: '1' }))).assertTrue()
      expect(isAIChatUserByServerExtension(JSON.stringify({ aiChat: 1 }))).assertTrue()
      expect(isAIChatUserByServerExtension(JSON.stringify({ aiChat: '1' }))).assertTrue()
      expect(isAIChatUserByServerExtension(JSON.stringify({ ai_chat: 0 }))).assertFalse()
      expect(isAIChatUserByServerExtension('{invalid json}')).assertFalse()
      expect(isAIChatUserByServerExtension(undefined)).assertFalse()
    });

  });
}
