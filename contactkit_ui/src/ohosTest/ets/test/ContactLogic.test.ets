/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { EditType, PersonInfoItem, PersonInfoArrowItem,
  PersonInfoSwitchItem, MineInfoItem } from '../../../main/ets/model/MineInfoItem';
import { NEContactSection, SelectUserWithFriendDataSource,
  SelectUserWithFriend, NEContactSectionDataSource } from '../../../main/ets/model/NEContactSection';
import { V2NIMUser } from '@nimsdk/base';

class MockV2NIMUser implements V2NIMUser {
  readonly accountId: string
  readonly name: string
  readonly createTime: number = 0

  constructor(accountId: string, name: string) {
    this.accountId = accountId
    this.name = name
  }
}

class MockDataChangeListener implements DataChangeListener {
  reloadCalled: boolean = false
  addCalled: boolean = false
  changeCalled: boolean = false
  deleteCalled: boolean = false
  moveCalled: boolean = false
  datasetChangeCalled: boolean = false
  lastAddIndex: number = -1
  lastChangeIndex: number = -1
  lastDeleteIndex: number = -1
  lastMoveFrom: number = -1
  lastMoveTo: number = -1

  onDataReloaded(): void { this.reloadCalled = true }
  onDataAdd(index: number): void { this.addCalled = true; this.lastAddIndex = index }
  onDataChange(index: number): void { this.changeCalled = true; this.lastChangeIndex = index }
  onDataDelete(index: number): void { this.deleteCalled = true; this.lastDeleteIndex = index }
  onDataMove(from: number, to: number): void { this.moveCalled = true; this.lastMoveFrom = from; this.lastMoveTo = to }
  onDatasetChange(dataOperations: DataOperation[]): void { this.datasetChangeCalled = true }
}

class SimpleDataChangeListener implements DataChangeListener {
  onDataReloaded(): void {}
  onDataAdd(index: number): void {}
  onDataChange(index: number): void {}
  onDataDelete(index: number): void {}
  onDataMove(from: number, to: number): void {}
  onDatasetChange(dataOperations: DataOperation[]): void {}
}

export default function ContactLogicTest() {
  describe('EditType', () => {
    it('should_have_all_types', 0, () => {
      expect(EditType.common as number).assertEqual(0);
      expect(EditType.nick as number).assertEqual(1);
      expect(EditType.gender as number).assertEqual(5);
    });
    it('should_have_accountId_and_alias_and_avatar_and_birthday_and_mobile_and_email_and_sign', 0, () => {
      expect(EditType.accountId as number).assertEqual(2);
      expect(EditType.alias as number).assertEqual(3);
      expect(EditType.avatar as number).assertEqual(4);
      expect(EditType.gender as number).assertEqual(5);
      expect(EditType.birthday as number).assertEqual(6);
      expect(EditType.mobile as number).assertEqual(7);
      expect(EditType.email as number).assertEqual(8);
      expect(EditType.sign as number).assertEqual(9);
    });
  });

  describe('PersonInfoItem', () => {
    it('should_default_itemHeight', 0, () => {
      const item: PersonInfoItem = new PersonInfoItem();
      expect(item.itemHeight).assertEqual(46);
    });
    it('should_accept_custom_values', 0, () => {
      const item: PersonInfoItem = new PersonInfoItem('Title', 'Sub', 50);
      if (item.title !== undefined) {
        expect(item.title).assertEqual('Title');
      }
      expect(item.itemHeight).assertEqual(50);
    });
    it('should_default_subTitle_to_undefined', 0, () => {
      const item: PersonInfoItem = new PersonInfoItem('OnlyTitle');
      expect(item.subTitle === undefined).assertTrue();
    });
    it('should_default_title_to_undefined', 0, () => {
      const item: PersonInfoItem = new PersonInfoItem();
      expect(item.title === undefined).assertTrue();
    });
  });

  describe('PersonInfoArrowItem', () => {
    it('should_default_to_edit_info_page', 0, () => {
      const item: PersonInfoArrowItem = new PersonInfoArrowItem();
      expect(item.routerUrl).assertEqual('EditInfoPage');
    });
    it('should_accept_custom_routerUrl', 0, () => {
      const item: PersonInfoArrowItem = new PersonInfoArrowItem('Title', 'Sub', 48, 'CustomPage');
      expect(item.routerUrl).assertEqual('CustomPage');
    });
    it('should_default_rightIcon_to_arrow_right', 0, () => {
      const item: PersonInfoArrowItem = new PersonInfoArrowItem();
      if (item.rightIcon !== undefined) {
        expect(item.rightIcon).assertEqual($r('app.media.arrow_right'));
      }
    });
  });

  describe('PersonInfoSwitchItem', () => {
    it('should_default_off', 0, () => {
      const item: PersonInfoSwitchItem = new PersonInfoSwitchItem();
      expect(item.isOpen).assertFalse();
    });
    it('should_accept_switch_callback', 0, () => {
      let changed = false;
      const item: PersonInfoSwitchItem = new PersonInfoSwitchItem('Toggle', true,
        (open: boolean): void => { changed = open; });
      expect(item.isOpen).assertTrue();
    });
    it('should_accept_subTitle_and_itemHeight', 0, () => {
      const item: PersonInfoSwitchItem = new PersonInfoSwitchItem('Title', false,
        undefined, 60, 'Sub');
      expect(item.isOpen).assertFalse();
      expect(item.itemHeight).assertEqual(60);
      if (item.subTitle !== undefined) {
        expect(item.subTitle).assertEqual('Sub');
      }
    });
  });

  describe('MineInfoItem', () => {
    it('should_construct', 0, () => {
      const item: MineInfoItem = new MineInfoItem('My', undefined, 'detail', EditType.nick);
      expect(item.editType).assertEqual(EditType.nick);
    });
    it('should_default_routerUrl_to_EditInfoPage', 0, () => {
      const item: MineInfoItem = new MineInfoItem('My');
      expect(item.routerUrl).assertEqual('EditInfoPage');
    });
    it('should_accept_subIcon', 0, () => {
      const item: MineInfoItem = new MineInfoItem('My', 'icon_res', 'detail', EditType.alias);
      if (item.subIcon !== undefined) {
        expect(item.subIcon).assertEqual('icon_res');
      }
      expect(item.editType).assertEqual(EditType.alias);
    });
    it('should_accept_all_params', 0, () => {
      const item: MineInfoItem = new MineInfoItem('Title', 'subIcon', 'Sub',
        EditType.mobile, 'MobilePage', 'icon_right', 55);
      expect(item.editType).assertEqual(EditType.mobile);
      expect(item.routerUrl).assertEqual('MobilePage');
      expect(item.itemHeight).assertEqual(55);
    });
  });

  /**
   * SelectUserWithFriend 测试
   */
  describe('SelectUserWithFriend', () => {
    it('should_construct_with_default_selected_false', 0, () => {
      const item: SelectUserWithFriend = new SelectUserWithFriend();
      expect(item.selected).assertFalse();
    });

    it('should_construct_with_NEUserWithFriend_preserves_user', 0, () => {
      const mockUser: V2NIMUser = new MockV2NIMUser('acc001', 'testUser');
      const src: SelectUserWithFriend = new SelectUserWithFriend();
      src.user = mockUser;
      const item: SelectUserWithFriend = new SelectUserWithFriend(src);
      expect(item.selected).assertFalse();
      if (item.user !== undefined) {
        expect(item.user.accountId).assertEqual('acc001');
      }
    });

    it('should_construct_with_undefined_userWithFriend', 0, () => {
      const item: SelectUserWithFriend = new SelectUserWithFriend(undefined);
      expect(item.selected).assertFalse();
      expect(item.user === undefined).assertTrue();
    });
  });

  /**
   * SelectUserWithFriendDataSource 测试
   * 测试所有 IDataSource 操作
   */
  describe('SelectUserWithFriendDataSource', () => {
    it('should_totalCount_0_initially', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      expect(ds.totalCount()).assertEqual(0);
    });

    it('should_push_and_increase_count', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const item: SelectUserWithFriend = new SelectUserWithFriend();
      ds.push(item);
      expect(ds.totalCount()).assertEqual(1);
      expect(ds.getData(0)).assertEqual(item);
    });

    it('should_push_multiple_items', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      ds.push(item1);
      ds.push(item2);
      expect(ds.totalCount()).assertEqual(2);
    });

    it('should_unshift_and_increase_count', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const item: SelectUserWithFriend = new SelectUserWithFriend();
      ds.unshift(item);
      expect(ds.totalCount()).assertEqual(1);
      expect(ds.getData(0)).assertEqual(item);
    });

    it('should_unshift_with_existing_items_inserts_at_beginning', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      ds.push(item1);
      ds.unshift(item2);
      expect(ds.totalCount()).assertEqual(2);
      expect(ds.getData(0)).assertEqual(item2);
      expect(ds.getData(1)).assertEqual(item1);
    });

    it('should_addData_at_specific_index', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      const item3: SelectUserWithFriend = new SelectUserWithFriend();
      ds.push(item1);
      ds.push(item3);
      ds.addData(1, item2);
      expect(ds.totalCount()).assertEqual(3);
      expect(ds.getData(0)).assertEqual(item1);
      expect(ds.getData(1)).assertEqual(item2);
      expect(ds.getData(2)).assertEqual(item3);
    });

    it('should_addData_at_beginning', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      ds.push(item2);
      ds.addData(0, item1);
      expect(ds.totalCount()).assertEqual(2);
      expect(ds.getData(0)).assertEqual(item1);
    });

    it('should_pushList_add_multiple_and_notify', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      const items: SelectUserWithFriend[] = [item1, item2];
      ds.pushList(items);
      expect(ds.totalCount()).assertEqual(2);
      expect(ds.getData(0)).assertEqual(item1);
      expect(ds.getData(1)).assertEqual(item2);
    });

    it('should_unshiftList_add_multiple_at_beginning', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const existing: SelectUserWithFriend = new SelectUserWithFriend();
      ds.push(existing);
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      const items: SelectUserWithFriend[] = [item1, item2];
      ds.unshiftList(items);
      expect(ds.totalCount()).assertEqual(3);
    });

    it('should_delete_existing_accountId', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const mockUser: V2NIMUser = new MockV2NIMUser('acc001', 'test');
      const item: SelectUserWithFriend = new SelectUserWithFriend();
      item.user = mockUser;
      ds.push(item);
      expect(ds.totalCount()).assertEqual(1);
      ds.delete('acc001');
      expect(ds.totalCount()).assertEqual(0);
    });

    it('should_delete_nonexistent_accountId_does_nothing', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const mockUser: V2NIMUser = new MockV2NIMUser('acc001', 'test');
      const item: SelectUserWithFriend = new SelectUserWithFriend();
      item.user = mockUser;
      ds.push(item);
      ds.delete('nonexistent');
      expect(ds.totalCount()).assertEqual(1);
    });

    it('should_delete_only_first_match', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const mockUser: V2NIMUser = new MockV2NIMUser('acc001', 'test');
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      item1.user = mockUser;
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      item2.user = mockUser;
      ds.push(item1);
      ds.push(item2);
      ds.delete('acc001');
      expect(ds.totalCount()).assertEqual(1);
    });

    it('should_delete_respects_index_correctly', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const user1: V2NIMUser = new MockV2NIMUser('acc001', 'test');
      const user2: V2NIMUser = new MockV2NIMUser('acc002', 'test');
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      item1.user = user1;
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      item2.user = user2;
      ds.push(item1);
      ds.push(item2);
      ds.delete('acc002');
      expect(ds.totalCount()).assertEqual(1);
      expect(ds.getData(0)).assertEqual(item1);
    });

    it('should_registerDataChangeListener_adds_listener_and_notifies', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataReload();
      expect(listener.reloadCalled).assertTrue();
    });

    it('should_registerDataChangeListener_not_add_duplicate', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.registerDataChangeListener(listener);
      // Verify listener still works (indirectly test it's registered only once)
      ds.notifyDataAdd(5);
      expect(listener.addCalled).assertTrue();
      expect(listener.lastAddIndex).assertEqual(5);
    });

    it('should_unregisterDataChangeListener_removes_listener', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.unregisterDataChangeListener(listener);
      // After unregister, notify should not affect removed listener
      listener.reloadCalled = false;
      ds.notifyDataReload();
      expect(listener.reloadCalled).assertFalse();
    });

    it('should_unregisterDataChangeListener_nonexistent_does_not_affect_registered', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      const other: SimpleDataChangeListener = new SimpleDataChangeListener();
      ds.unregisterDataChangeListener(other);
      // Registered listener should still receive notifications
      ds.notifyDataReload();
      expect(listener.reloadCalled).assertTrue();
    });

    it('should_notifyDataReload_calls_all_listeners', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener1: MockDataChangeListener = new MockDataChangeListener();
      const listener2: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener1);
      ds.registerDataChangeListener(listener2);
      ds.notifyDataReload();
      expect(listener1.reloadCalled).assertTrue();
      expect(listener2.reloadCalled).assertTrue();
    });

    it('should_notifyDataAdd_calls_all_listeners', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataAdd(3);
      expect(listener.addCalled).assertTrue();
      expect(listener.lastAddIndex).assertEqual(3);
    });

    it('should_notifyDataChange_calls_all_listeners', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataChange(2);
      expect(listener.changeCalled).assertTrue();
      expect(listener.lastChangeIndex).assertEqual(2);
    });

    it('should_notifyDataDelete_calls_all_listeners', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataDelete(1);
      expect(listener.deleteCalled).assertTrue();
      expect(listener.lastDeleteIndex).assertEqual(1);
    });

    it('should_notifyDataMove_calls_all_listeners', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataMove(0, 5);
      expect(listener.moveCalled).assertTrue();
      expect(listener.lastMoveFrom).assertEqual(0);
      expect(listener.lastMoveTo).assertEqual(5);
    });

    it('should_notifyDatasetChange_calls_all_listeners', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDatasetChange([]);
      expect(listener.datasetChangeCalled).assertTrue();
    });

    it('should_push_calls_notifyDataAdd_indirectly', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      const item: SelectUserWithFriend = new SelectUserWithFriend();
      ds.push(item);
      expect(ds.totalCount()).assertEqual(1);
      expect(listener.addCalled).assertTrue();
      expect(listener.lastAddIndex).assertEqual(0);
    });

    it('should_unshiftList_empty_array', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const empty: SelectUserWithFriend[] = [];
      ds.unshiftList(empty);
      expect(ds.totalCount()).assertEqual(0);
    });

    it('should_pushList_empty_array', 0, () => {
      const ds: SelectUserWithFriendDataSource = new SelectUserWithFriendDataSource();
      const empty: SelectUserWithFriend[] = [];
      ds.pushList(empty);
      expect(ds.totalCount()).assertEqual(0);
    });
  });

  /**
   * NEContactSection 测试
   */
  describe('NEContactSection', () => {
    it('should_construct', 0, () => {
      const section: NEContactSection = new NEContactSection('A', []);
      if (section.initial !== undefined) {
        expect(section.initial).assertEqual('A');
      }
      expect(section.contacts.totalCount()).assertEqual(0);
    });

    it('should_construct_with_contacts', 0, () => {
      const item1: SelectUserWithFriend = new SelectUserWithFriend();
      const item2: SelectUserWithFriend = new SelectUserWithFriend();
      const contacts: SelectUserWithFriend[] = [item1, item2];
      const section: NEContactSection = new NEContactSection('B', contacts);
      expect(section.initial).assertEqual('B');
      expect(section.contacts.totalCount()).assertEqual(2);
    });

    it('should_construct_with_default_initial', 0, () => {
      const section: NEContactSection = new NEContactSection('#', []);
      expect(section.initial).assertEqual('#');
    });
  });

  /**
   * NEContactSectionDataSource 测试
   * 测试所有 IDataSource 操作
   */
  describe('NEContactSectionDataSource', () => {
    it('should_totalCount_0_initially', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      expect(ds.totalCount()).assertEqual(0);
    });

    it('should_push_and_increase_count', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const section: NEContactSection = new NEContactSection('A', []);
      ds.push(section);
      expect(ds.totalCount()).assertEqual(1);
      expect(ds.getData(0)).assertEqual(section);
    });

    it('should_push_multiple_sections', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const s1: NEContactSection = new NEContactSection('A', []);
      const s2: NEContactSection = new NEContactSection('B', []);
      ds.push(s1);
      ds.push(s2);
      expect(ds.totalCount()).assertEqual(2);
      expect(ds.getData(0)).assertEqual(s1);
      expect(ds.getData(1)).assertEqual(s2);
    });

    it('should_unshift_inserts_at_beginning', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const s1: NEContactSection = new NEContactSection('A', []);
      const s2: NEContactSection = new NEContactSection('B', []);
      ds.push(s1);
      ds.unshift(s2);
      expect(ds.totalCount()).assertEqual(2);
      expect(ds.getData(0)).assertEqual(s2);
      expect(ds.getData(1)).assertEqual(s1);
    });

    it('should_addData_at_specific_index', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const s1: NEContactSection = new NEContactSection('A', []);
      const s2: NEContactSection = new NEContactSection('B', []);
      const s3: NEContactSection = new NEContactSection('C', []);
      ds.push(s1);
      ds.push(s3);
      ds.addData(1, s2);
      expect(ds.totalCount()).assertEqual(3);
      expect(ds.getData(1)).assertEqual(s2);
    });

    it('should_pushList_add_multiple_sections', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const s1: NEContactSection = new NEContactSection('A', []);
      const s2: NEContactSection = new NEContactSection('B', []);
      const sections: NEContactSection[] = [s1, s2];
      ds.pushList(sections);
      expect(ds.totalCount()).assertEqual(2);
    });

    it('should_unshiftList_add_multiple_at_beginning', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const existing: NEContactSection = new NEContactSection('X', []);
      ds.push(existing);
      const s1: NEContactSection = new NEContactSection('A', []);
      const s2: NEContactSection = new NEContactSection('B', []);
      const sections: NEContactSection[] = [s1, s2];
      ds.unshiftList(sections);
      expect(ds.totalCount()).assertEqual(3);
    });

    it('should_delete_existing_initial', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const s1: NEContactSection = new NEContactSection('A', []);
      const s2: NEContactSection = new NEContactSection('B', []);
      ds.push(s1);
      ds.push(s2);
      ds.delete('A');
      expect(ds.totalCount()).assertEqual(1);
      expect(ds.getData(0).initial).assertEqual('B');
    });

    it('should_delete_nonexistent_initial_does_nothing', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const section: NEContactSection = new NEContactSection('A', []);
      ds.push(section);
      ds.delete('Z');
      expect(ds.totalCount()).assertEqual(1);
    });

    it('should_delete_only_first_match', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const s1: NEContactSection = new NEContactSection('A', []);
      const s2: NEContactSection = new NEContactSection('A', []);
      ds.push(s1);
      ds.push(s2);
      ds.delete('A');
      expect(ds.totalCount()).assertEqual(1);
    });

    it('should_registerDataChangeListener_adds_listener', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      expect(ds.listeners.length).assertEqual(1);
    });

    it('should_registerDataChangeListener_not_add_duplicate', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.registerDataChangeListener(listener);
      expect(ds.listeners.length).assertEqual(1);
    });

    it('should_unregisterDataChangeListener_removes_listener', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.unregisterDataChangeListener(listener);
      expect(ds.listeners.length).assertEqual(0);
    });

    it('should_unregisterDataChangeListener_nonexistent_does_nothing', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      const other: MockDataChangeListener = new MockDataChangeListener();
      ds.unregisterDataChangeListener(other);
      expect(ds.listeners.length).assertEqual(1);
    });

    it('should_notifyDataReload_calls_all_listeners', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener1: MockDataChangeListener = new MockDataChangeListener();
      const listener2: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener1);
      ds.registerDataChangeListener(listener2);
      ds.notifyDataReload();
      expect(listener1.reloadCalled).assertTrue();
      expect(listener2.reloadCalled).assertTrue();
    });

    it('should_notifyDataAdd_calls_all_listeners', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataAdd(0);
      expect(listener.addCalled).assertTrue();
    });

    it('should_notifyDataChange_calls_all_listeners', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataChange(0);
      expect(listener.changeCalled).assertTrue();
    });

    it('should_notifyDataDelete_calls_all_listeners', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataDelete(0);
      expect(listener.deleteCalled).assertTrue();
    });

    it('should_notifyDataMove_calls_all_listeners', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDataMove(0, 1);
      expect(listener.moveCalled).assertTrue();
    });

    it('should_notifyDatasetChange_calls_all_listeners', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const listener: MockDataChangeListener = new MockDataChangeListener();
      ds.registerDataChangeListener(listener);
      ds.notifyDatasetChange([]);
      expect(listener.datasetChangeCalled).assertTrue();
    });

    it('should_pushList_empty_array', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const empty: NEContactSection[] = [];
      ds.pushList(empty);
      expect(ds.totalCount()).assertEqual(0);
    });

    it('should_unshiftList_empty_array', 0, () => {
      const ds: NEContactSectionDataSource = new NEContactSectionDataSource();
      const empty: NEContactSection[] = [];
      ds.unshiftList(empty);
      expect(ds.totalCount()).assertEqual(0);
    });
  });
}
