/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';
import { IsDiscussion } from '../../../main/ets/utils/Utils';
import { V2NIMTeam } from '@nimsdk/base';
import { AitSegment } from '../../../main/ets/model/ait/AitSegment';
import { AitMessage } from '../../../main/ets/model/ait/AitMessage';
import { AitModel, accountAll, aitKey, getAitModelFromJson } from '../../../main/ets/model/ait/AitModel';

export default function UtilsAndAitTest() {
  describe('Utils_IsDiscussion', () => {
    it('should_return_false_for_undefined', 0, () => {
      expect(IsDiscussion(undefined)).assertFalse();
    });
    it('should_return_false_for_empty_extension', 0, () => {
      const team: V2NIMTeam = JSON.parse('{"serverExtension":""}') as V2NIMTeam;
      expect(IsDiscussion(team)).assertFalse();
    });
    it('should_return_true_for_discussion_team', 0, () => {
      const team: V2NIMTeam = JSON.parse('{"serverExtension":"im_ui_kit_group"}') as V2NIMTeam;
      expect(IsDiscussion(team)).assertTrue();
    });
  });

  describe('AitSegment', () => {
    it('should_default_values', 0, () => {
      const seg: AitSegment = new AitSegment();
      expect(seg.start).assertEqual(0);
      expect(seg.end).assertEqual(0);
      expect(seg.broken).assertFalse();
    });
  });

  describe('AitMessage', () => {
    it('should_construct', 0, () => {
      const msg: AitMessage = new AitMessage('@Tom', 'user_001');
      expect(msg.text).assertEqual('@Tom');
      expect(msg.accountId).assertEqual('user_001');
      expect(msg.segments.length).assertEqual(0);
    });
    it('should_add_and_remove_segment', 0, () => {
      const msg: AitMessage = new AitMessage('@Tom', 'user_001');
      msg.addSegment(0, 3);
      expect(msg.segments.length).assertEqual(1);
      msg.removeSegment(0, 3);
      expect(msg.segments.length).assertEqual(0);
    });
    it('should_valid', 0, () => {
      const msg: AitMessage = new AitMessage('@Tom', 'user_001');
      expect(msg.valid()).assertFalse();
      msg.addSegment(0, 3);
      expect(msg.valid()).assertTrue();
    });
    it('should_segment_to_map', 0, () => {
      const seg: AitSegment = new AitSegment();
      seg.start = 2;
      seg.end = 5;
      const map: Map<string, number | boolean> = new AitMessage('@Tom', 'u').segmentToMap(seg);
      expect(map.get('start') as number).assertEqual(2);
      expect(map.get('end') as number).assertEqual(5);
    });
  });

  describe('AitModel', () => {
    it('should_reset', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      model.reset();
      expect(model.aitBlocks.size).assertEqual(0);
    });
    it('should_isUserBeenAit', 0, () => {
      const model: AitModel = new AitModel();
      expect(model.isUserBeenAit(null)).assertFalse();
      model.addAitMember('ux', '@Ux', 0);
      expect(model.isUserBeenAit('ux')).assertTrue();
    });
    it('should_isUserBeenAit_all', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember(accountAll, '@All', 0);
      expect(model.isUserBeenAit('any')).assertTrue();
    });
    it('should_isUserBeenAit_not_found', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      expect(model.isUserBeenAit('u2')).assertFalse();
    });
    it('should_deleteAitUser_empty_text', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      expect(model.deleteAitUser('', 0, 0)).assertNull();
    });
    it('should_deleteAitUser_endIndex_before_segment', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 5);
      const result: AitMessage | null = model.deleteAitUser('ab', 2, 2);
      expect(result).assertNull();
      const block: AitMessage | undefined = model.aitBlocks.get('u1');
      if (block !== undefined) {
        expect(block.segments[0].start).assertEqual(3);
        expect(block.segments[0].end).assertEqual(3);
      }
    });
    it('should_deleteAitUser_short_text_breaks_segment', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      const result: AitMessage | null = model.deleteAitUser('x', 1, 1);
      expect(result !== null).assertTrue();
      expect(model.aitBlocks.size).assertEqual(0);
    });
    it('should_deleteAitUser_matching_text_preserves_segment', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      const result: AitMessage | null = model.deleteAitUser('@U1', 2, 3);
      expect(result).assertNull();
      const block: AitMessage | undefined = model.aitBlocks.get('u1');
      if (block !== undefined) {
        expect(block.segments.length).assertEqual(1);
      }
    });
    it('should_deleteText_endIndex_equals_end', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      model.deleteText(2, 1);
      const block: AitMessage | undefined = model.aitBlocks.get('u1');
      if (block !== undefined) {
        expect(block.segments.length).assertEqual(1);
      }
    });
    it('should_deleteText_endIndex_before_start', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 5);
      model.deleteText(2, 1);
      const block: AitMessage | undefined = model.aitBlocks.get('u1');
      if (block !== undefined) {
        expect(block.segments[0].start).assertEqual(4);
        expect(block.segments[0].end).assertEqual(4);
      }
    });
    it('should_deleteText_endIndex_after_end', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      model.deleteText(5, 1);
      const block: AitMessage | undefined = model.aitBlocks.get('u1');
      if (block !== undefined) {
        expect(block.segments[0].start).assertEqual(0);
        expect(block.segments[0].end).assertEqual(2);
      }
    });
    it('should_insertText_before_segment', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 3);
      model.insertText(1, 2);
      const block: AitMessage | undefined = model.aitBlocks.get('u1');
      if (block !== undefined) {
        expect(block.segments[0].start).assertEqual(5);
        expect(block.segments[0].end).assertEqual(7);
      }
    });
    it('should_insertText_inside_segment', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      model.insertText(2, 1);
      expect(model.aitBlocks.size).assertEqual(0);
    });
    it('should_addAitMember_shift_existing', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      model.addAitMember('u2', '@U2', 0);
      const block1: AitMessage | undefined = model.aitBlocks.get('u1');
      if (block1 !== undefined) {
        expect(block1.segments[0].start).assertEqual(3);
        expect(block1.segments[0].end).assertEqual(5);
      }
    });
    it('should_addAitMember_same_user', 0, () => {
      const model: AitModel = new AitModel();
      model.addAitMember('u1', '@U1', 0);
      model.addAitMember('u1', '@U1', 5);
      const block: AitMessage | undefined = model.aitBlocks.get('u1');
      if (block !== undefined) {
        expect(block.segments.length).assertEqual(2);
      }
    });
    it('should_fork', 0, () => {
      const m1: AitModel = new AitModel();
      m1.addAitMember('ua', '@Ua', 0);
      const m2: AitModel = new AitModel();
      m2.fork(m1);
      expect(m2.aitBlocks.size > 0).assertTrue();
    });
    it('should_constants', 0, () => {
      expect(accountAll.length > 0).assertTrue();
      expect(aitKey.length > 0).assertTrue();
    });
    it('should_getAitModelFromJson_undefined', 0, () => {
      expect(getAitModelFromJson(undefined)).assertUndefined();
    });
    it('should_getAitModelFromJson_invalid_json', 0, () => {
      expect(getAitModelFromJson('{invalid}')).assertUndefined();
    });
    it('should_getAitModelFromJson_no_ait_key', 0, () => {
      expect(getAitModelFromJson('{"other":"value"}')).assertUndefined();
    });
  });
}
