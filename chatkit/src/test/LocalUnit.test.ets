/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  V2NIMCreateTeamParams,
  V2NIMFriend,
  V2NIMMessage,
  V2NIMMessageNotificationType,
  V2NIMMessageType,
  V2NIMTeamType
} from '@nimsdk/base';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { NEFriendUserCache } from '../main/ets/NEFriendUserCache';
import {
  buildTeamCreateInviteNotificationAttachment,
  getCreateTeamSuccessTipResourceName,
  getTeamCreateInviteNotificationType
} from '../main/ets/repo/TeamRepo';
import {
  buildTeamCreateInviteLocalExtension,
  isLocalTeamCreateInviteMessage,
  shouldCollapseTeamCreateInviteNotifications
} from '../main/ets/utils/TeamInviteNotificationUtils';

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

      const persistedAttachment = JSON.parse(attachment.raw ?? '{}') as {
        type?: number
        targetIds?: string[]
      };
      expect(persistedAttachment.type).assertEqual(
        V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_INVITE
      );
      expect(persistedAttachment.targetIds?.length).assertEqual(2);
      expect(persistedAttachment.targetIds?.[0]).assertEqual('user_a');
      expect(persistedAttachment.targetIds?.[1]).assertEqual('user_b');
    });

    it('should_mark_local_team_create_invite_message', 0, () => {
      const localExtension = buildTeamCreateInviteLocalExtension();
      expect(isLocalTeamCreateInviteMessage({
        localExtension
      } as unknown as V2NIMMessage)).assertTrue();
    });

    it('should_match_local_and_remote_create_team_invite_notifications', 0, () => {
      const attachment = buildTeamCreateInviteNotificationAttachment(
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        ['user_a', 'user_b']
      );

      const localMessage = {
        conversationId: 'team|team123',
        senderId: 'me',
        createTime: 1000,
        messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION,
        attachment,
        localExtension: buildTeamCreateInviteLocalExtension()
      } as unknown as V2NIMMessage;

      const remoteMessage = {
        conversationId: 'team|team123',
        senderId: 'me',
        createTime: 1000,
        messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION,
        attachment
      } as unknown as V2NIMMessage;

      expect(shouldCollapseTeamCreateInviteNotifications(localMessage, remoteMessage)).assertTrue();
    });

    it('should_match_local_and_remote_create_team_invite_notifications_when_create_time_differs', 0, () => {
      const attachment = buildTeamCreateInviteNotificationAttachment(
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        ['user_a', 'user_b']
      );

      const localMessage = {
        conversationId: 'team|team123',
        senderId: 'me',
        createTime: 1000,
        messageServerId: '',
        messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION,
        attachment,
        localExtension: buildTeamCreateInviteLocalExtension()
      } as unknown as V2NIMMessage;

      const remoteMessage = {
        conversationId: 'team|team123',
        senderId: 'me',
        createTime: 1200,
        messageServerId: 'server_msg_1',
        messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION,
        attachment
      } as unknown as V2NIMMessage;

      expect(shouldCollapseTeamCreateInviteNotifications(localMessage, remoteMessage)).assertTrue();
    });

    it('should_match_local_inserted_create_team_invite_without_local_extension', 0, () => {
      const attachment = buildTeamCreateInviteNotificationAttachment(
        V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        ['user_a', 'user_b']
      );

      const localMessage = {
        conversationId: 'team|team123',
        senderId: 'me',
        createTime: 1000,
        messageServerId: '',
        messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION,
        attachment
      } as unknown as V2NIMMessage;

      const remoteMessage = {
        conversationId: 'team|team123',
        senderId: 'me',
        createTime: 1200,
        messageServerId: 'server_msg_1',
        messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION,
        attachment
      } as unknown as V2NIMMessage;

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

    it('should_keep_friend_relation_when_account_is_in_block_list', 0, () => {
      const cache = Object.create(NEFriendUserCache.prototype) as NEFriendUserCache
      cache.blockAccountList = ['user_a']
      cache.friendCache = new Map()
      cache.updateFriendInfo({
        friend: {
          accountId: 'user_a'
        } as V2NIMFriend
      })

      expect(cache.isFriend('user_a')).assertFalse()
      expect(cache.hasFriendRelation('user_a')).assertTrue()
    });
  });
}
