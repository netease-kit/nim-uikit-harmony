/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';

/**
 * ChatConst 常量值验证测试 & NEChatMoreOperationData / MessageOperationItem 模型测试
 *
 * 将常量和模型类复制为本地版本用于纯逻辑单元测试。
 */

class ChatConst {
  static readonly chatMessagePageSize: number = 50;
  static readonly imageMessageHeight: number = 124;
  static readonly imageMessageWidth: number = 222;
  static readonly mergedMessageHeight: number = 130;
  static readonly mergedMessageMinHeight: number = 80;
  static readonly messageLineHeight: number = 60;
  static readonly textLineHeight: number = 20;
  static readonly messageTextFontSize: number = 14;
  static readonly mapMessageHeight: number = 160;
  static readonly fileMessageWidth: number = 60;
  static readonly audioMessageWidth: number = 35;
  static readonly messageInputAreaHeight: number = 180;
  static readonly menuItemWidth: number = 60;
  static readonly menuItemHeight: number = 66;
  static readonly menuItemColumnNum: number = 5;
  static readonly pinOperatorNameMaxLen: number = 15;
  static readonly revokeLocalKey: string = 'revoke_message_local';
  static readonly revokeLocalTimeKey: string = 'revoke_message_local_time';
  static readonly revokeMsgClientIdKey: string = 'revoke_message_client_id';
  static readonly revokeMsgTextKey: string = 'revoke_message_local_content';
  static readonly revokeMsgEditKey: string = 'revoke_message_local_edit';
  static readonly messageDeleteLimit: number = 50;
}

enum NEChatMoreOperationType {
  Video = 1,
  File = 2,
  Location = 3,
  Call = 4
}

class NEChatMoreOperationData {
  type?: NEChatMoreOperationType;
  operationTitle?: string;
  imageSource?: string;
}

enum MessageOperationType {
  Delete = 1,
  Copy = 2,
  Undo = 3,
  Forward = 4,
  Pin = 5,
  Unpin = 6,
  Select = 7,
  Collection = 8,
  Reply = 9
}

class MessageOperationItem {
  operationImage?: string;
  operationText?: string;
  operationType: MessageOperationType = MessageOperationType.Delete;
}

/**
 * setupMoreOperationData 的纯逻辑本地版本
 */
function setupMoreOperationData(isP2P: boolean): Array<NEChatMoreOperationData> {
  let operationMoreDataList: Array<NEChatMoreOperationData> = Array()

  const videoOperationData = new NEChatMoreOperationData();
  videoOperationData.operationTitle = 'chat_camera_take';
  videoOperationData.type = NEChatMoreOperationType.Video;
  videoOperationData.imageSource = "app.media.ic_public_chat_photo";
  operationMoreDataList.push(videoOperationData);

  const locationOperationData = new NEChatMoreOperationData();
  locationOperationData.operationTitle = 'chat_send_location';
  locationOperationData.type = NEChatMoreOperationType.Location;
  locationOperationData.imageSource = "app.media.ic_chat_more_location";
  operationMoreDataList.push(locationOperationData);

  const fileOperationData = new NEChatMoreOperationData();
  fileOperationData.operationTitle = 'chat_send_file';
  fileOperationData.type = NEChatMoreOperationType.File;
  fileOperationData.imageSource = "app.media.ic_public_chat_file";
  operationMoreDataList.push(fileOperationData);

  if (isP2P) {
    const callOperationData = new NEChatMoreOperationData();
    callOperationData.operationTitle = 'chat_send_call';
    callOperationData.type = NEChatMoreOperationType.Call;
    callOperationData.imageSource = "app.media.ic_public_chat_call";
    operationMoreDataList.push(callOperationData);
  }

  return operationMoreDataList
}

/**
 * computeOperateViewWidth / computeOperateViewHeight 的纯逻辑本地版本
 */
function computeOperateViewWidth(menuCount: number): number {
  return ChatConst.menuItemWidth * Math.min(menuCount, ChatConst.menuItemColumnNum)
}

function computeOperateViewHeight(menuCount: number): number {
  return ChatConst.menuItemHeight * (Math.ceil(menuCount / ChatConst.menuItemColumnNum))
}

export default function chatConstAndModelTest() {
  describe('ChatConst_Constants', () => {
    it('should_have_correct_chatMessagePageSize', 0, () => {
      expect(ChatConst.chatMessagePageSize).assertEqual(50);
    });

    it('should_have_correct_imageMessageHeight', 0, () => {
      expect(ChatConst.imageMessageHeight).assertEqual(124);
    });

    it('should_have_correct_imageMessageWidth', 0, () => {
      expect(ChatConst.imageMessageWidth).assertEqual(222);
    });

    it('should_have_correct_mergedMessageHeight', 0, () => {
      expect(ChatConst.mergedMessageHeight).assertEqual(130);
    });

    it('should_have_correct_mergedMessageMinHeight', 0, () => {
      expect(ChatConst.mergedMessageMinHeight).assertEqual(80);
    });

    it('should_have_correct_messageLineHeight', 0, () => {
      expect(ChatConst.messageLineHeight).assertEqual(60);
    });

    it('should_have_correct_textLineHeight', 0, () => {
      expect(ChatConst.textLineHeight).assertEqual(20);
    });

    it('should_have_correct_menuItemWidth', 0, () => {
      expect(ChatConst.menuItemWidth).assertEqual(60);
    });

    it('should_have_correct_menuItemHeight', 0, () => {
      expect(ChatConst.menuItemHeight).assertEqual(66);
    });

    it('should_have_correct_menuItemColumnNum', 0, () => {
      expect(ChatConst.menuItemColumnNum).assertEqual(5);
    });

    it('should_have_correct_pinOperatorNameMaxLen', 0, () => {
      expect(ChatConst.pinOperatorNameMaxLen).assertEqual(15);
    });

    it('should_have_correct_revokeLocalKey', 0, () => {
      expect(ChatConst.revokeLocalKey).assertEqual('revoke_message_local');
    });

    it('should_have_correct_messageDeleteLimit', 0, () => {
      expect(ChatConst.messageDeleteLimit).assertEqual(50);
    });
  });

  describe('NEChatMoreOperationData_Model', () => {
    it('should_create_default_instance', 0, () => {
      let data = new NEChatMoreOperationData();
      expect(data.type).assertUndefined();
      expect(data.operationTitle).assertUndefined();
      expect(data.imageSource).assertUndefined();
    });

    it('should_set_video_operation_data', 0, () => {
      let data = new NEChatMoreOperationData();
      data.type = NEChatMoreOperationType.Video;
      data.operationTitle = '拍摄';
      data.imageSource = 'ic_public_chat_photo';
      expect(data.type).assertEqual(NEChatMoreOperationType.Video);
      expect(data.operationTitle).assertEqual('拍摄');
      expect(data.imageSource).assertEqual('ic_public_chat_photo');
    });

    it('should_verify_enum_values', 0, () => {
      expect(NEChatMoreOperationType.Video).assertEqual(1);
      expect(NEChatMoreOperationType.File).assertEqual(2);
      expect(NEChatMoreOperationType.Location).assertEqual(3);
      expect(NEChatMoreOperationType.Call).assertEqual(4);
    });
  });

  describe('MessageOperationItem_Model', () => {
    it('should_have_default_delete_type', 0, () => {
      let item = new MessageOperationItem();
      expect(item.operationType).assertEqual(MessageOperationType.Delete);
    });

    it('should_set_copy_type', 0, () => {
      let item = new MessageOperationItem();
      item.operationType = MessageOperationType.Copy;
      item.operationText = '复制';
      expect(item.operationType).assertEqual(MessageOperationType.Copy);
      expect(item.operationText).assertEqual('复制');
    });

    it('should_verify_all_operation_types', 0, () => {
      expect(MessageOperationType.Delete).assertEqual(1);
      expect(MessageOperationType.Copy).assertEqual(2);
      expect(MessageOperationType.Undo).assertEqual(3);
      expect(MessageOperationType.Forward).assertEqual(4);
      expect(MessageOperationType.Pin).assertEqual(5);
      expect(MessageOperationType.Unpin).assertEqual(6);
      expect(MessageOperationType.Select).assertEqual(7);
      expect(MessageOperationType.Collection).assertEqual(8);
      expect(MessageOperationType.Reply).assertEqual(9);
    });
  });

  describe('ChatUtils_setupMoreOperationData', () => {
    it('should_return_3_items_for_non_p2p', 0, () => {
      let result = setupMoreOperationData(false);
      expect(result.length).assertEqual(3);
    });

    it('should_return_4_items_for_p2p', 0, () => {
      let result = setupMoreOperationData(true);
      expect(result.length).assertEqual(4);
    });

    it('should_have_video_as_first_item', 0, () => {
      let result = setupMoreOperationData(false);
      expect(result[0].type).assertEqual(NEChatMoreOperationType.Video);
    });

    it('should_have_location_as_second_item', 0, () => {
      let result = setupMoreOperationData(false);
      expect(result[1].type).assertEqual(NEChatMoreOperationType.Location);
    });

    it('should_have_file_as_third_item', 0, () => {
      let result = setupMoreOperationData(false);
      expect(result[2].type).assertEqual(NEChatMoreOperationType.File);
    });

    it('should_have_call_as_fourth_item_for_p2p', 0, () => {
      let result = setupMoreOperationData(true);
      expect(result[3].type).assertEqual(NEChatMoreOperationType.Call);
    });

    it('should_not_contain_call_for_non_p2p', 0, () => {
      let result = setupMoreOperationData(false);
      let hasCall = result.some(item => item.type === NEChatMoreOperationType.Call);
      expect(hasCall).assertFalse();
    });

    it('should_set_correct_imageSource_for_video', 0, () => {
      let result = setupMoreOperationData(true);
      expect(result[0].imageSource).assertEqual('app.media.ic_public_chat_photo');
    });

    it('should_set_correct_imageSource_for_location', 0, () => {
      let result = setupMoreOperationData(true);
      expect(result[1].imageSource).assertEqual('app.media.ic_chat_more_location');
    });

    it('should_set_correct_imageSource_for_file', 0, () => {
      let result = setupMoreOperationData(true);
      expect(result[2].imageSource).assertEqual('app.media.ic_public_chat_file');
    });

    it('should_set_correct_imageSource_for_call', 0, () => {
      let result = setupMoreOperationData(true);
      expect(result[3].imageSource).assertEqual('app.media.ic_public_chat_call');
    });
  });

  describe('ChatUtils_computeOperateView', () => {
    it('should_compute_width_for_3_items', 0, () => {
      // min(3, 5) = 3, 3 * 60 = 180
      expect(computeOperateViewWidth(3)).assertEqual(180);
    });

    it('should_compute_width_for_5_items', 0, () => {
      // min(5, 5) = 5, 5 * 60 = 300
      expect(computeOperateViewWidth(5)).assertEqual(300);
    });

    it('should_compute_width_for_7_items_capped_at_column', 0, () => {
      // min(7, 5) = 5, 5 * 60 = 300
      expect(computeOperateViewWidth(7)).assertEqual(300);
    });

    it('should_compute_width_for_0_items', 0, () => {
      expect(computeOperateViewWidth(0)).assertEqual(0);
    });

    it('should_compute_height_for_3_items', 0, () => {
      // ceil(3/5) = 1, 1 * 66 = 66
      expect(computeOperateViewHeight(3)).assertEqual(66);
    });

    it('should_compute_height_for_5_items', 0, () => {
      // ceil(5/5) = 1, 1 * 66 = 66
      expect(computeOperateViewHeight(5)).assertEqual(66);
    });

    it('should_compute_height_for_6_items', 0, () => {
      // ceil(6/5) = 2, 2 * 66 = 132
      expect(computeOperateViewHeight(6)).assertEqual(132);
    });

    it('should_compute_height_for_10_items', 0, () => {
      // ceil(10/5) = 2, 2 * 66 = 132
      expect(computeOperateViewHeight(10)).assertEqual(132);
    });

    it('should_compute_height_for_0_items', 0, () => {
      expect(computeOperateViewHeight(0)).assertEqual(0);
    });
  });
}
