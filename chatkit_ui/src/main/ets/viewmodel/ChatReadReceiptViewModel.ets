/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatKitClient, ChatRepo, TeamMemberWithUser, TeamRepo } from '@nimkit/chatkit'
import { V2NIMMessage, V2NIMTeamMessageReadReceiptDetail, V2NIMTeamType } from '@nimsdk/base'

@ObservedV2
export class ChatReadReceiptViewModel {
  //群Id
  teamId?: string
  //消息
  message?: V2NIMMessage
  //已读回执
  @Trace readReceiptDetail: V2NIMTeamMessageReadReceiptDetail | null = null
  @Trace readMemberList: TeamMemberWithUser[] = []
  @Trace unreadMemberList: TeamMemberWithUser[] = []

  init(message?: V2NIMMessage) {
    this.message = message
    if (message) {
      this.teamId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(message.conversationId)
    }
  }

  /**
   * 获取未读数详情
   */
  getMessageReadReceipt() {
    if (this.message) {
      ChatRepo.getTeamMessageReceiptDetail(this.message).then(
        (result) => {
          this.readReceiptDetail = result
          if (result) {
            this.getMemberList(result.readAccountList, true)
          }
        }
      ).catch((error: Error) => {
        console.log(error.message)
      })
    }

  }

  /**
   * 获取群成员信息
   * @param accountIds
   * @param read 是否已读
   */
  async getMemberList(accountIds: string[], read: boolean) {
    if (accountIds.length <= 0) {
      return
    }
    const chunks: string[][] = [];
    //每页请求20条
    const pageSize: number = 20
    for (let i = 0; i < accountIds.length; i += pageSize) {
      chunks.push(accountIds.slice(i, i + pageSize));
    }
    //async 请求，防止触发频控
    chunks.forEach(async (accIds) => {
      if (this.teamId) {
        let memberList = await TeamRepo.getTeamMembersByIds(this.teamId,
          V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, accIds)
        if (read) {
          this.readMemberList.push(...memberList)
        } else {
          this.unreadMemberList.push(...memberList)
        }
      }
    })
  }
}

