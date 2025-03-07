/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ChatRepo, ContactRepo } from '@nimkit/chatkit'
import {
  V2NIMError,
  V2NIMErrorCode,
  V2NIMFriendAddApplication,
  V2NIMFriendAddApplicationResult,
  V2NIMFriendAddApplicationStatus,
  V2NIMFriendAddRejection
} from '@nimsdk/base'
import { NEFriendAddApplication } from '../model/NEFriendAddApplication'
import { common } from '@kit.AbilityKit'
import { NECommonUtils } from '@nimkit/common'

@ObservedV2
export class ValidationMessageViewModel {
  /**
   * 分页位置。首次查询传0，下一次传上一次返回的offset。查询结果不包含offset位置
   */
  offset: number = 0
  /**
   * 查询数量, 默认100
   */
  limit: number = 100
  /**
   * 是否查询结束（还有数据）
   */
  finished: boolean = false
  @Trace friendAddApplications: NEFriendAddApplication[] = []
  onFriendAddApplicationFun = async (application: V2NIMFriendAddApplication) => {
    try {
      const neApplication = await this.convertToNEFriendAddApplication(application, true)
      if (neApplication) {
        this.friendAddApplications.unshift(neApplication)
      }
    } catch (err) {
      console.log(err)
    }
  }
  onFriendAddRejectedFun = async (rejection: V2NIMFriendAddRejection) => {
    let currentApplication: V2NIMFriendAddApplication | undefined

    for (let item of this.friendAddApplications) {
      if (item.friendAddApplication.applicantAccountId === ChatKitClient.getLoginUserId() &&
        item.friendAddApplication.recipientAccountId === rejection.operatorAccountId &&
        item.status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_INIT) {
        currentApplication = item.friendAddApplication
      }
    }

    if (currentApplication === undefined) {
      for (let item of this.friendAddApplications) {
        if (item.friendAddApplication.applicantAccountId === ChatKitClient.getLoginUserId() &&
          item.friendAddApplication.recipientAccountId === rejection.operatorAccountId &&
          item.status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_REJECTED) {
          currentApplication = item.friendAddApplication
        }
      }
    }

    if (currentApplication) {
      this.setApplicationStatus(currentApplication,
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_REJECTED)
    }
  }
  private context = getContext(this) as common.UIAbilityContext

  constructor() {
    ChatKitClient.nim.friendService?.on("onFriendAddApplication", this.onFriendAddApplicationFun)
    ChatKitClient.nim.friendService?.on("onFriendAddRejected", this.onFriendAddRejectedFun)
  }

  async convertToNEFriendAddApplication(item: V2NIMFriendAddApplication, move: boolean = false) {
    let isExist: boolean = false
    for (let index = 0; index < this.friendAddApplications.length; index++) {
      const neItem = this.friendAddApplications[index]
      if (neItem.isEqualTo(item)) {
        isExist = true

        // 未读数
        if (item.read === false) {
          neItem.unreadCount += 1
        }

        // 移动到最前
        if (move && index !== 0) {
          this.friendAddApplications.splice(index, 1)
          this.friendAddApplications.unshift(neItem)
        }
        break
      }
    }

    if (isExist) {
      return
    }

    let friendAddApplication = new NEFriendAddApplication(item)
    let applicationAccid = friendAddApplication.friendAddApplication.applicantAccountId

    // 申请添加他人为好友
    if (friendAddApplication.friendAddApplication.applicantAccountId === ChatKitClient.getLoginUserId()) {
      applicationAccid = friendAddApplication.friendAddApplication.recipientAccountId
      // 同意
      if (friendAddApplication.friendAddApplication.status ===
      V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_AGREED) {
        friendAddApplication.description = $r('app.string.contact_validation_accepted_me')
      }

      // 拒绝
      if (friendAddApplication.friendAddApplication.status ===
      V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_REJECTED) {
        friendAddApplication.description = $r('app.string.contact_validation_refused_me')
      }
    }

    if (applicationAccid) {
      try {
        let users = await ContactRepo.getUserWithFriendByIds([applicationAccid])
        if (users.length > 0) {
          friendAddApplication.setApplicantUserWithFriend(users[0])
        }
      } catch (err) {
        console.log(err)
      }
    }

    return friendAddApplication
  }

  /**
   * 获取申请添加好友列表通知
   */
  async getAddApplicationList() {
    if (this.finished) {
      return
    }

    try {
      const result: V2NIMFriendAddApplicationResult | undefined = await ContactRepo.getAddApplicationList({
        offset: this.offset,
        limit: this.limit,
        status: []
      })

      if (result) {
        this.offset = result.offset
        this.finished = result.finished

        for (const item of result.infos) {
          const application = await this.convertToNEFriendAddApplication(item)
          if (application) {
            this.friendAddApplications.push(application)
          }
        }

        // 循环拉取
        this.getAddApplicationList()
      }
    } catch (err) {
      console.log(err)
    }
  }

  /**
   * 接受好友申请
   *
   * @param application 申请添加好友的相关信息
   */
  async acceptAddApplication(application: V2NIMFriendAddApplication) {
    try {
      await this.changeApplicationStatus(application,
        V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_AGREED)

      const text = this.context.resourceManager.getStringSync($r("app.string.let_us_chat"))
      const message = ChatRepo.createTextMessage(text)
      const conversationId = ChatKitClient.nim.conversationIdUtil.p2pConversationId(application.applicantAccountId)
      const result = await ChatRepo.sendMessage(message, conversationId)
      console.log("net ease send hello message success ", result);
    } catch (err) {
      console.log("net ease send hello message error", err);
    }
  }

  /**
   * 拒绝好友申请
   *
   * @param application 申请添加好友的相关信息
   */
  async rejectAddApplication(application: V2NIMFriendAddApplication) {
    this.changeApplicationStatus(application,
      V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_REJECTED)
  }

  /**
   * 接受/拒绝好友申请
   *
   * @param application 申请添加好友的相关信息
   * @param status 好友申请的处理状态
   */
  async changeApplicationStatus(application: V2NIMFriendAddApplication, status: V2NIMFriendAddApplicationStatus) {
    try {
      if (status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_AGREED) {
        await ContactRepo.acceptAddApplication(application)
      }

      if (status === V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_REJECTED) {
        await ContactRepo.rejectAddApplication(application)
      }

      this.setApplicationStatus(application, status)
    } catch (err) {
      console.log(err)
      let v2Error = err as V2NIMError
      if (v2Error) {
        switch (v2Error.code) {
          case V2NIMErrorCode.V2NIM_ERROR_CODE_FRIEND_ALREADY_EXIST:
            this.setApplicationStatus(application,
              V2NIMFriendAddApplicationStatus.V2NIM_FRIEND_ADD_APPLICATION_STATUS_AGREED)
            NECommonUtils.showToast($r('app.string.validate_processed'))
            break
          default:
            break
        }
      }
    }
  }

  async setApplicationStatus(application: V2NIMFriendAddApplication, status: V2NIMFriendAddApplicationStatus) {
    let currenApplication: NEFriendAddApplication | undefined

    for (let index = 0; index < this.friendAddApplications.length; index++) {
      const neApplication = this.friendAddApplications[index]
      if (neApplication.friendAddApplication === application) {
        currenApplication = neApplication
      }
    }

    if (currenApplication) {
      application.status = status
      for (let index = this.friendAddApplications.length - 1; index >= 0; index--) {
        const neApplication = this.friendAddApplications[index]
        // 验证消息中（不包含第一条）已存在相同消息
        if (neApplication.isEqualTo(application)) {
          this.friendAddApplications.splice(index, 1)
        }
      }

      /// 改变当前消息的状态
      currenApplication.unreadCount = 0
      currenApplication.status = status
    }
  }

  /**
   * 设置好友申请已读
   */
  async setAddApplicationRead() {
    try {
      await ContactRepo.setAddApplicationRead()
    } catch (err) {
      console.log(err)
    }
  }

  async clearAllAddApplication() {
    if (this.friendAddApplications.length < 1){
      return
    }
    try {
      await ContactRepo.clearAllAddApplication()
      this.friendAddApplications = []
    } catch (err) {
      console.log(err)
    }
  }

  onDestroy() {
    ChatKitClient.nim.friendService?.off("onFriendAddApplication", this.onFriendAddApplicationFun)
    ChatKitClient.nim.friendService?.off("onFriendAddRejected", this.onFriendAddRejectedFun)
  }
}