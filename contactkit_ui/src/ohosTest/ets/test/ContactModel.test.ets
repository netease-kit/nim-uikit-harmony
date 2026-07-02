/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { NEContactItem } from '../../../main/ets/model/NEContactItem';
import { PersonSelectParam } from '@nimkit/chatkit';

export default function ContactModelTest() {
  describe('NEContactItem', () => {
    it('should_construct_with_all_fields', 0, () => {
      let backCalled = false;
      const backFn: () => void = (): void => { backCalled = true; };
      const item = new NEContactItem(undefined, 'Test Title', '/test_route', '99+', backFn);
      expect(item.title).assertEqual('Test Title');
      expect(item.routerUrl).assertEqual('/test_route');
      expect(item.unreadCount).assertEqual('99+');
      if (item.backAction !== undefined) {
        item.backAction();
      }
      expect(backCalled).assertTrue();
    });

    it('should_construct_with_default_undefined_fields', 0, () => {
      const item = new NEContactItem();
      expect(item.title === undefined).assertTrue();
      expect(item.routerUrl === undefined).assertTrue();
      expect(item.unreadCount === undefined).assertTrue();
      expect(item.backAction === undefined).assertTrue();
    });

    it('should_set_title_to_ResourceStr', 0, () => {
      const item = new NEContactItem();
      const titleStr: string = '联系人';
      const item2 = new NEContactItem(undefined, titleStr);
      expect(item2.title).assertEqual('联系人');
    });

    it('should_construct_with_only_backAction', 0, () => {
      let called = false;
      const item: NEContactItem = new NEContactItem(undefined, undefined, undefined,
        undefined, (): void => { called = true; });
      expect(item.avatarIcon === undefined).assertTrue();
      if (item.backAction !== undefined) {
        item.backAction();
      }
      expect(called).assertTrue();
    });

    it('should_construct_with_all_params_including_avatarIcon', 0, () => {
      const item: NEContactItem = new NEContactItem($r('app.media.arrow_right'),
        'Title', '/page', '5', undefined);
      expect(item.title).assertEqual('Title');
      expect(item.routerUrl).assertEqual('/page');
      expect(item.unreadCount).assertEqual('5');
    });
  });

  describe('PersonSelectParam', () => {
    it('should_not_show_ai_users_by_default', 0, () => {
      const param = new PersonSelectParam();
      expect(param.showAIUsers).assertFalse();
    });

    it('should_allow_callers_to_show_ai_users', 0, () => {
      const param = new PersonSelectParam(undefined, [], 10, true);
      expect(param.showAIUsers).assertTrue();
    });
  });
}
