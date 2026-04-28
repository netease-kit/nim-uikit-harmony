/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { ChatKitClient } from '@nimkit/chatkit';
import {
  V2NIMConversationType,
  V2NIMMessage,
  V2NIMMessageAudioAttachment,
  V2NIMMessageNotificationAttachment,
  V2NIMMessageNotificationType,
  V2NIMMessageSendingState,
  V2NIMMessageType
} from '@nimsdk/base';
import { ChatInfo } from '../main/ets/model/ChatInfo';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    const conversationId = 'team|team123'

    function createInviteAttachment(): V2NIMMessageNotificationAttachment {
      const attachment = {
        type: V2NIMMessageNotificationType.V2NIM_MESSAGE_NOTIFICATION_TYPE_TEAM_INVITE,
        targetIds: ['user_a']
      } as V2NIMMessageNotificationAttachment
      attachment.raw = JSON.stringify({
        type: attachment.type,
        targetIds: attachment.targetIds
      })
      return attachment
    }

    function createInviteMessage(messageClientId: string, createTime: number, local: boolean): V2NIMMessage {
      return {
        messageClientId,
        messageServerId: local ? '' : `server_${messageClientId}`,
        createTime,
        conversationId,
        conversationType: V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM,
        senderId: 'me',
        receiverId: 'team123',
        isSelf: true,
        sendingState: V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED,
        messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION,
        text: '',
        attachment: createInviteAttachment(),
        localExtension: local ? JSON.stringify({
          nimkit_local_team_create_invite: true
        }) : undefined
      } as V2NIMMessage
    }

    function createAudioMessage(messageClientId: string, createTime: number): V2NIMMessage {
      return {
        messageClientId,
        messageServerId: `server_${messageClientId}`,
        createTime,
        conversationId,
        conversationType: V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM,
        senderId: 'user_a',
        receiverId: 'team123',
        isSelf: false,
        sendingState: V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED,
        messageType: V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO,
        text: '',
        attachment: {
          duration: 1000,
          url: 'https://example.com/audio.aac'
        } as V2NIMMessageAudioAttachment
      } as V2NIMMessage
    }

    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
      ChatKitClient.nim = {
        conversationIdUtil: {
          parseConversationTargetId: (id: string) => {
            return id.split('|')[1] ?? ''
          }
        },
        loginService: {
          getLoginUser: () => {
            return 'me'
          }
        }
      } as object as typeof ChatKitClient.nim
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

    it('should_keep_only_one_team_invite_notification_when_official_message_arrives', 0, () => {
      const chatInfo = new ChatInfo(conversationId)
      const localMessage = createInviteMessage('local_msg', 1000, true)
      const remoteMessage = createInviteMessage('remote_msg', 1200, false)

      chatInfo.pushMessage(localMessage)
      chatInfo.pushMessage(remoteMessage)

      expect(chatInfo.msgList.totalCount()).assertEqual(1)
      expect(chatInfo.getMessage('local_msg')).assertUndefined()
      expect(chatInfo.getMessage('remote_msg')?.message.messageClientId).assertEqual('remote_msg')
    });

    it('should_keep_only_one_team_invite_notification_when_local_marker_is_missing', 0, () => {
      const chatInfo = new ChatInfo(conversationId)
      const localMessage = createInviteMessage('local_msg', 1000, false)
      localMessage.messageServerId = ''
      const remoteMessage = createInviteMessage('remote_msg', 1200, false)

      chatInfo.pushMessage(localMessage)
      chatInfo.pushMessage(remoteMessage)

      expect(chatInfo.msgList.totalCount()).assertEqual(1)
      expect(chatInfo.getMessage('local_msg')).assertUndefined()
      expect(chatInfo.getMessage('remote_msg')?.message.messageClientId).assertEqual('remote_msg')
    });

    it('should_restore_voice_to_text_when_history_messages_are_unshifted', 0, () => {
      const chatInfo = new ChatInfo(conversationId)
      const audioMessage = createAudioMessage('audio_msg', 1000)

      chatInfo.cacheVoiceToText('audio_msg', 'voice text result')
      const result = chatInfo.unshiftMessage([audioMessage])

      expect(result.length).assertEqual(1)
      expect(result[0].voiceToText).assertEqual('voice text result')
      expect(chatInfo.getMessage('audio_msg')?.voiceToText).assertEqual('voice text result')
    });
  });
}
