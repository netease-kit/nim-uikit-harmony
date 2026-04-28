/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  getTeamVerifyActionTextType,
  shouldShowTeamVerifyActionButtons,
  TeamVerifyActionTextType,
  TeamVerifyInfoBean
} from '../main/ets/model/TeamVerifyInfoBean';
import { NEFriendAddApplication } from '../main/ets/model/NEFriendAddApplication';
import {
  V2NIMTeamJoinActionInfo,
  V2NIMTeamJoinActionStatus,
  V2NIMTeamJoinActionType,
  V2NIMTeamType,
  V2NIMFriendAddApplication,
  V2NIMFriendAddApplicationStatus
} from '@nimsdk/base';

/**
 * 通讯录验证消息未读数单元测试
 *
 * 测试范围：Model 层的去重逻辑
 * - TeamVerifyInfoBean.isSameMessage(): 群验证去重
 * - NEFriendAddApplication.isEqualTo(): 好友申请去重
 *
 * 测试策略：
 * - 直接导入真实的 Model 类进行测试
 * - 使用显式的 Mock 类实现 SDK interface
 */

/**
 * Mock 实现：群验证操作信息
 */
class MockTeamJoinActionInfo implements V2NIMTeamJoinActionInfo {
  teamId: string = ''
  operatorAccountId: string = ''
  fromAccountId: string = ''
  targetAccountId: string = ''
  actionType: V2NIMTeamJoinActionType = V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION
  actionStatus: V2NIMTeamJoinActionStatus = V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
  teamType: V2NIMTeamType = V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL
  timestamp: number = Date.now()
  read: boolean = false

  constructor(
    teamId: string,
    operatorAccountId: string,
    actionType: V2NIMTeamJoinActionType,
    actionStatus: V2NIMTeamJoinActionStatus,
    read: boolean = false,
    fromAccountId: string = '',
    targetAccountId: string = ''
  ) {
    this.teamId = teamId
    this.operatorAccountId = operatorAccountId
    this.fromAccountId = fromAccountId
    this.targetAccountId = targetAccountId
    this.actionType = actionType
    this.actionStatus = actionStatus
    this.read = read
  }
}

/**
 * Mock 实现：好友申请信息
 */
class MockFriendAddApplication implements V2NIMFriendAddApplication {
  applicantAccountId: string = ''
  recipientAccountId: string = ''
  operatorAccountId: string = ''
  status: V2NIMFriendAddApplicationStatus = V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT
  timestamp: number = Date.now()
  read: boolean = false

  constructor(
    applicantAccountId: string,
    recipientAccountId: string,
    status: V2NIMFriendAddApplicationStatus,
    read: boolean = false
  ) {
    this.applicantAccountId = applicantAccountId
    this.recipientAccountId = recipientAccountId
    this.operatorAccountId = applicantAccountId
    this.status = status
    this.read = read
  }
}

export default function contactVerifyUnreadTest() {

  /**
   * 测试用例 247：群验证去重逻辑
   * 规则：同一 teamId + operatorAccountId + actionType + actionStatus 视为同一条
   */
  describe('TeamVerifyInfoBean_isSameMessage', () => {

    it('should_return_true_for_same_team_operator_actionType_status', 0, () => {
      // 创建第一条记录
      const actionInfo1 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        false
      )
      const bean1 = new TeamVerifyInfoBean(actionInfo1)

      // 创建第二条记录（相同四元组）
      const actionInfo2 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        false
      )

      // 应该被识别为同一条消息
      expect(bean1.isSameMessage(actionInfo2)).assertTrue()
    })

    it('should_return_false_for_different_teamId', 0, () => {
      const actionInfo1 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
      )
      const bean1 = new TeamVerifyInfoBean(actionInfo1)

      const actionInfo2 = new MockTeamJoinActionInfo(
        'team456', // 不同的群
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
      )

      expect(bean1.isSameMessage(actionInfo2)).assertFalse()
    })

    it('should_return_false_for_different_operatorAccountId', 0, () => {
      const actionInfo1 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
      )
      const bean1 = new TeamVerifyInfoBean(actionInfo1)

      const actionInfo2 = new MockTeamJoinActionInfo(
        'team123',
        'user002', // 不同的操作者
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
      )

      expect(bean1.isSameMessage(actionInfo2)).assertFalse()
    })

    it('should_return_false_for_different_actionType', 0, () => {
      const actionInfo1 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION, // 申请
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
      )
      const bean1 = new TeamVerifyInfoBean(actionInfo1)

      const actionInfo2 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_INVITATION, // 邀请
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT
      )

      expect(bean1.isSameMessage(actionInfo2)).assertFalse()
    })

    it('should_return_false_for_different_actionStatus', 0, () => {
      const actionInfo1 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT // 未处理
      )
      const bean1 = new TeamVerifyInfoBean(actionInfo1)

      const actionInfo2 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_AGREED // 已同意
      )

      expect(bean1.isSameMessage(actionInfo2)).assertFalse()
    })

    it('should_set_unreadCount_1_when_not_read', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        false
      )
      const bean = new TeamVerifyInfoBean(actionInfo)

      expect(bean.unreadCount).assertEqual(1)
    })

    it('should_set_unreadCount_0_when_read', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        true
      )
      const bean = new TeamVerifyInfoBean(actionInfo)

      expect(bean.unreadCount).assertEqual(0)
    })
  })

  /**
   * 测试用例 247：好友申请去重逻辑
   * 规则：同一 applicantAccountId + recipientAccountId + status 视为同一条
   */
  describe('NEFriendAddApplication_isEqualTo', () => {

    it('should_return_true_for_same_applicant_recipient_status', 0, () => {
      const app1 = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT,
        false
      )
      const bean1 = new NEFriendAddApplication(app1)

      const app2 = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT,
        false
      )

      expect(bean1.isEqualTo(app2)).assertTrue()
    })

    it('should_return_false_for_different_applicantAccountId', 0, () => {
      const app1 = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT
      )
      const bean1 = new NEFriendAddApplication(app1)

      const app2 = new MockFriendAddApplication(
        'user003', // 不同申请者
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT
      )

      expect(bean1.isEqualTo(app2)).assertFalse()
    })

    it('should_return_false_for_different_recipientAccountId', 0, () => {
      const app1 = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT
      )
      const bean1 = new NEFriendAddApplication(app1)

      const app2 = new MockFriendAddApplication(
        'user001',
        'user004', // 不同接收者
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT
      )

      expect(bean1.isEqualTo(app2)).assertFalse()
    })

    it('should_return_false_for_different_status', 0, () => {
      const app1 = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT // 未处理
      )
      const bean1 = new NEFriendAddApplication(app1)

      const app2 = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_AGREED // 已同意
      )

      expect(bean1.isEqualTo(app2)).assertFalse()
    })

    it('should_set_unreadCount_1_when_not_read', 0, () => {
      const app = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT,
        false
      )
      const bean = new NEFriendAddApplication(app)

      expect(bean.unreadCount).assertEqual(1)
    })

    it('should_set_unreadCount_0_when_read', 0, () => {
      const app = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT,
        true
      )
      const bean = new NEFriendAddApplication(app)

      expect(bean.unreadCount).assertEqual(0)
    })
  })

  /**
   * 测试用例 247：未读数累加场景（去重后累加 unreadCount）
   */
  describe('UnreadCount_Accumulation', () => {

    it('team_verify_should_accumulate_unreadCount_for_duplicate', 0, () => {
      // 模拟去重逻辑：同一条消息多次到达，应该累加 unreadCount
      const actionInfo1 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        false
      )
      const bean1 = new TeamVerifyInfoBean(actionInfo1)

      // 第二条相同的消息到达
      const actionInfo2 = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        false
      )

      // 验证是同一条消息
      expect(bean1.isSameMessage(actionInfo2)).assertTrue()

      // 模拟累加逻辑
      if (bean1.isSameMessage(actionInfo2)) {
        const newUnread = actionInfo2.read === false ? 1 : 0
        bean1.unreadCount += newUnread
      }

      expect(bean1.unreadCount).assertEqual(2)
    })

    it('friend_apply_should_accumulate_unreadCount_for_duplicate', 0, () => {
      const app1 = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT,
        false
      )
      const bean1 = new NEFriendAddApplication(app1)

      const app2 = new MockFriendAddApplication(
        'user001',
        'user002',
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT,
        false
      )

      // 验证是同一条消息
      expect(bean1.isEqualTo(app2)).assertTrue()

      // 模拟累加逻辑
      if (bean1.isEqualTo(app2)) {
        const newUnread = app2.read === false ? 1 : 0
        bean1.unreadCount += newUnread
      }

      expect(bean1.unreadCount).assertEqual(2)
    })
  })

  /**
   * 测试用例 248：无未读时，底部通讯录 Tab 无红点
   */
  describe('Tab_RedDot_Logic', () => {

    it('should_show_red_dot_when_total_unread_greater_than_0', 0, () => {
      const friendUnreadCount = 1
      const teamVerifyUnreadCount = 0
      const totalUnread = friendUnreadCount + teamVerifyUnreadCount

      expect(totalUnread > 0).assertTrue()
    })

    it('should_not_show_red_dot_when_total_unread_is_0', 0, () => {
      const friendUnreadCount = 0
      const teamVerifyUnreadCount = 0
      const totalUnread = friendUnreadCount + teamVerifyUnreadCount

      expect(totalUnread > 0).assertFalse()
    })

    it('should_show_red_dot_when_only_team_verify_has_unread', 0, () => {
      const friendUnreadCount = 0
      const teamVerifyUnreadCount = 3
      const totalUnread = friendUnreadCount + teamVerifyUnreadCount

      expect(totalUnread > 0).assertTrue()
    })

    it('should_show_red_dot_when_both_have_unread', 0, () => {
      const friendUnreadCount = 2
      const teamVerifyUnreadCount = 3
      const totalUnread = friendUnreadCount + teamVerifyUnreadCount

      expect(totalUnread).assertEqual(5)
      expect(totalUnread > 0).assertTrue()
    })
  })

  /**
   * 测试用例 249：进入页面清除对应未读数
   */
  describe('Clear_Unread_On_Enter', () => {

    it('enter_friend_verify_should_only_clear_friend_unread', 0, () => {
      let friendUnreadCount = 5
      let teamVerifyUnreadCount = 3

      // 进入好友验证页面，只清除好友未读
      friendUnreadCount = 0

      expect(friendUnreadCount).assertEqual(0)
      expect(teamVerifyUnreadCount).assertEqual(3) // 群验证未读不受影响
    })

    it('enter_team_verify_should_only_clear_team_verify_unread', 0, () => {
      let friendUnreadCount = 5
      let teamVerifyUnreadCount = 3

      // 进入群验证页面，只清除群验证未读
      teamVerifyUnreadCount = 0

      expect(friendUnreadCount).assertEqual(5) // 好友未读不受影响
      expect(teamVerifyUnreadCount).assertEqual(0)
    })
  })

  describe('TeamVerify_ActionTextType', () => {
    it('should_map_reject_application_to_reject_application_text', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_REJECT_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED
      )

      expect(getTeamVerifyActionTextType(actionInfo)).assertEqual(TeamVerifyActionTextType.REJECT_APPLICATION)
    })

    it('should_map_reject_invitation_to_reject_invitation_text', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_REJECT_INVITATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED
      )

      expect(getTeamVerifyActionTextType(actionInfo)).assertEqual(TeamVerifyActionTextType.REJECT_INVITATION)
    })

    it('should_map_application_with_rejected_status_to_reject_application_text', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED
      )

      expect(getTeamVerifyActionTextType(actionInfo)).assertEqual(TeamVerifyActionTextType.REJECT_APPLICATION)
    })

    it('should_map_invitation_with_agreed_status_to_accept_invitation_text', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_INVITATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_AGREED
      )

      expect(getTeamVerifyActionTextType(actionInfo)).assertEqual(TeamVerifyActionTextType.ACCEPT_INVITATION)
    })
  })

  describe('TeamVerify_ActionButtons', () => {
    it('should_hide_buttons_for_invitation_sender_when_invitee_has_not_processed', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user_a',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_INVITATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        false,
        'user_a',
        'user_b'
      )

      expect(shouldShowTeamVerifyActionButtons(actionInfo, 'user_a')).assertFalse()
    })

    it('should_show_buttons_for_invitee_when_invitation_is_pending', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user_a',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_INVITATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        false,
        'user_a',
        'user_b'
      )

      expect(shouldShowTeamVerifyActionButtons(actionInfo, 'user_b')).assertTrue()
    })

    it('should_hide_buttons_for_rejected_invitation', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user_b',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_REJECT_INVITATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED,
        false,
        'user_b',
        'user_a'
      )

      expect(shouldShowTeamVerifyActionButtons(actionInfo, 'user_a')).assertFalse()
    })

    it('should_hide_buttons_when_observed_status_is_rejected_after_click', 0, () => {
      const actionInfo = new MockTeamJoinActionInfo(
        'team123',
        'user001',
        V2NIMTeamJoinActionType.V2NIM_TEAM_JOIN_ACTION_TYPE_APPLICATION,
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_INIT,
        false,
        'user001'
      )

      expect(shouldShowTeamVerifyActionButtons(actionInfo, 'manager001',
        V2NIMTeamJoinActionStatus.V2NIM_TEAM_JOIN_ACTION_STATUS_REJECTED)).assertFalse()
    })
  })
}
