/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { LoginEventRepo } from '../../../main/ets/repo/LoginEventRepo';
import { UserEventRepo } from '../../../main/ets/repo/UserEventRepo';
import { FriendEventRepo } from '../../../main/ets/repo/FriendEventRepo';
import { TeamEventRepo } from '../../../main/ets/repo/TeamEventRepo';
import { ConversationEventRepo } from '../../../main/ets/repo/ConversationEventRepo';
import { V2NIMDataSyncType, V2NIMDataSyncState, V2NIMError,
  V2NIMConnectStatus, V2NIMLoginStatus, V2NIMUser, V2NIMFriend,
  V2NIMFriendAddApplication, V2NIMFriendAddRejection, V2NIMTeam,
  V2NIMTeamMember } from '@nimsdk/base';

export default function EventRepoTest() {
  describe('LoginEventRepo', () => {
    it('should_register_onDataSync', 0, () => {
      const cb = (type: V2NIMDataSyncType, state: V2NIMDataSyncState, error?: V2NIMError): void => {};
      const d = LoginEventRepo.onDataSync(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
    it('should_register_onConnectStatus', 0, () => {
      const cb = (status: V2NIMConnectStatus): void => {};
      const d = LoginEventRepo.onConnectStatus(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
    it('should_register_onLoginStatus', 0, () => {
      const cb = (status: V2NIMLoginStatus): void => {};
      const d = LoginEventRepo.onLoginStatus(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
  });

  describe('UserEventRepo', () => {
    it('should_register_onUserProfileChanged', 0, () => {
      const cb = (users: V2NIMUser[]): void => {};
      const d = UserEventRepo.onUserProfileChanged(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
  });

  describe('FriendEventRepo', () => {
    it('should_register_onFriendAddApplication', 0, () => {
      const cb = (application: V2NIMFriendAddApplication): void => {};
      const d = FriendEventRepo.onFriendAddApplication(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
    it('should_register_onFriendAddRejected', 0, () => {
      const cb = (rejection: V2NIMFriendAddRejection): void => {};
      const d = FriendEventRepo.onFriendAddRejected(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
    it('should_register_onFriendAdded', 0, () => {
      const cb = (friend: V2NIMFriend): void => {};
      const d = FriendEventRepo.onFriendAdded(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
  });

  describe('TeamEventRepo', () => {
    it('should_register_onTeamCreated', 0, () => {
      const cb = (team: V2NIMTeam): void => {};
      const d = TeamEventRepo.onTeamCreated(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
    it('should_register_onTeamDismissed', 0, () => {
      const cb = (team: V2NIMTeam): void => {};
      const d = TeamEventRepo.onTeamDismissed(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
    it('should_register_onTeamInfoUpdated', 0, () => {
      const cb = (team: V2NIMTeam): void => {};
      const d = TeamEventRepo.onTeamInfoUpdated(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
    it('should_register_onTeamMemberJoined', 0, () => {
      const cb = (members: V2NIMTeamMember[]): void => {};
      const d = TeamEventRepo.onTeamMemberJoined(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
    it('should_register_onTeamMemberLeft', 0, () => {
      const cb = (members: V2NIMTeamMember[]): void => {};
      const d = TeamEventRepo.onTeamMemberLeft(cb);
      expect(d !== undefined).assertTrue();
      d();
    });
  });

  describe('ConversationEventRepo', () => {
    it('should_register_onCloudSyncStarted', 0, () => {
      const cb = (): void => {};
      ConversationEventRepo.onCloudSyncStarted(cb);
      ConversationEventRepo.offCloudSyncStarted(cb);
      expect(true).assertTrue();
    });
    it('should_register_onCloudSyncFinished', 0, () => {
      const cb = (): void => {};
      ConversationEventRepo.onCloudSyncFinished(cb);
      ConversationEventRepo.offCloudSyncFinished(cb);
      expect(true).assertTrue();
    });
    it('should_register_onCloudSyncFailed', 0, () => {
      const cb = (error?: V2NIMError): void => {};
      ConversationEventRepo.onCloudSyncFailed(cb);
      ConversationEventRepo.offCloudSyncFailed(cb);
      expect(true).assertTrue();
    });
    it('should_register_onCloudTotalUnreadCountChanged', 0, () => {
      const cb = (unreadCount: number): void => {};
      ConversationEventRepo.onCloudTotalUnreadCountChanged(cb);
      ConversationEventRepo.offCloudTotalUnreadCountChanged(cb);
      expect(true).assertTrue();
    });
  });
}
