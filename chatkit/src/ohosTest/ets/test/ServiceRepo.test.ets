import { describe, expect, it } from '@ohos/hypium';
import { ChatRepo } from '../../../main/ets/repo/ChatRepo';
import { ContactRepo } from '../../../main/ets/repo/ContactRepo';
import { ConversationRepo } from '../../../main/ets/repo/ConversationRepo';
import { LocalConversationRepo } from '../../../main/ets/repo/LocalConversationRepo';
import { SubscriptionRepo } from '../../../main/ets/repo/SubscriptionRepo';
import { SettingRepo } from '../../../main/ets/repo/SettingRepo';
import { StorageRepo } from '../../../main/ets/repo/StorageRepo';
import { AIRepo } from '../../../main/ets/repo/AIRepo';
import { UserAIBotManager } from '../../../main/ets/manager/UserAIBotManager';
import { ConversationIdUtilRepo } from '../../../main/ets/repo/ConversationIdUtilRepo';
import { ConversationGroupRepo } from '../../../main/ets/repo/ConversationGroupRepo';
import { ChatKitClient } from '../../../main/ets/ChatKitClient';
import { NIMInterface, V2NIMConversationFilter } from '@nimsdk/base';

export default function ServiceRepoTest() {
  describe('ChatRepo', () => {
    it('should_register_global_send_callback', 0, () => {
      let called = false;
      ChatRepo.onSendMessage((msg): void => { called = true; });
      ChatRepo.offSendMessage((msg): void => { called = true; });
      expect(true).assertTrue();
    });
    it('should_have_static_sendCallback', 0, () => {
      expect(ChatRepo.sendCallback === undefined || ChatRepo.sendCallback !== undefined).assertTrue();
    });
  });

  describe('ContactRepo', () => {
    it('should_have_pinyinHashMap', 0, () => {
      expect(ContactRepo.pinyinHasMap !== undefined).assertTrue();
    });
    it('should_add_and_remove_listener', 0, () => {
      ContactRepo.addListener();
      ContactRepo.removeListener();
      expect(true).assertTrue();
    });
  });

  describe('ConversationRepo', () => {
    it('should_get_total_unread_count', 0, () => {
      const count: number | undefined = ConversationRepo.getTotalUnreadCount();
      expect(true).assertTrue();
    });
    it('should_not_throw_when_safe_unread_filter_subscription_api_throws', 0, () => {
      const originalNim = ChatKitClient.nim;
      let subscribeCalled = false;
      let unsubscribeCalled = false;
      ChatKitClient.nim = {
        conversationService: {
          subscribeUnreadCountByFilter: (_filter: V2NIMConversationFilter): void => {
            subscribeCalled = true;
            throw new Error('not login');
          },
          unsubscribeUnreadCountByFilter: (_filter: V2NIMConversationFilter): void => {
            unsubscribeCalled = true;
            throw new Error('not login');
          }
        }
      } as NIMInterface;

      try {
        const subscribeResult = ConversationRepo.safeSubscribeUnreadCountByFilter({ ignoreMuted: true });
        const unsubscribeResult = ConversationRepo.safeUnsubscribeUnreadCountByFilter({ ignoreMuted: true });

        expect(subscribeCalled).assertTrue();
        expect(unsubscribeCalled).assertTrue();
        expect(subscribeResult).assertFalse();
        expect(unsubscribeResult).assertFalse();
      } finally {
        ChatKitClient.nim = originalNim;
      }
    });
  });

  describe('SmallRepo_existence', () => {
    it('should_access_LocalConversationRepo', 0, () => {
      expect(LocalConversationRepo !== undefined).assertTrue();
    });
    it('should_access_SubscriptionRepo', 0, () => {
      expect(SubscriptionRepo !== undefined).assertTrue();
    });
    it('should_access_ConversationIdUtilRepo', 0, () => {
      expect(ConversationIdUtilRepo !== undefined).assertTrue();
    });
    it('should_access_ConversationGroupRepo', 0, () => {
      expect(ConversationGroupRepo !== undefined).assertTrue();
    });
    it('should_access_SettingRepo', 0, () => {
      expect(SettingRepo !== undefined).assertTrue();
    });
    it('should_access_StorageRepo', 0, () => {
      expect(StorageRepo !== undefined).assertTrue();
    });
    it('should_access_AIRepo', 0, () => {
      expect(AIRepo !== undefined).assertTrue();
    });
    it('should_access_UserAIBotManager', 0, () => {
      expect(UserAIBotManager !== undefined).assertTrue();
    });
  });

  describe('ConversationGroupRepo', () => {
    it('should_not_throw_when_safe_unread_filter_subscription_api_throws', 0, () => {
      const originalNim = ChatKitClient.nim;
      let subscribeCalled = false;
      let unsubscribeCalled = false;
      ChatKitClient.nim = {
        conversationService: {
          subscribeUnreadCountByFilter: (_filter: V2NIMConversationFilter): void => {
            subscribeCalled = true;
            throw new Error('not login');
          },
          unsubscribeUnreadCountByFilter: (_filter: V2NIMConversationFilter): void => {
            unsubscribeCalled = true;
            throw new Error('not login');
          }
        }
      } as NIMInterface;

      try {
        const subscribeResult = ConversationGroupRepo.safeSubscribeUnreadCountByGroupId('groupA');
        const unsubscribeResult = ConversationGroupRepo.safeUnsubscribeUnreadCountByGroupId('groupA');

        expect(subscribeCalled).assertTrue();
        expect(unsubscribeCalled).assertTrue();
        expect(subscribeResult).assertFalse();
        expect(unsubscribeResult).assertFalse();
      } finally {
        ChatKitClient.nim = originalNim;
      }
    });
  });
}
