/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { ChatRepo, IMKitConfigCenter } from '@nimkit/chatkit'
import {
  V2NIMMessage,
  V2NIMMessageDeletedNotification,
  V2NIMMessageRevokeNotification,
  V2NIMMessageSearchExParams,
  V2NIMMessageSearchResult,
  V2NIMMessageType
} from '@nimsdk/base'
import { util } from '@kit.ArkTS'

export interface TeamMemberMessageParams {
  senderId: string
  conversationId: string
}

@ObservedV2
export class TeamMemberMessageViewModel {

  // 会话ID
  @Trace conversationId: string = ''

  //发送者ID
  @Trace sendId: string = ''

  //下一次请求所需token
  @Trace pageToken : string | undefined

  //是否正在加载
  @Trace isLoading : boolean = false

  //是否有更多
  @Trace hasMore : boolean = true

  @Trace messageList: V2NIMMessage[] = []

  // 消息删除或撤回标志
  @Trace revokeAndeDeleteMission = false

  init(conversationId: string, sendId: string) {
    this.conversationId = conversationId
    this.sendId = sendId
    // 注册消息删除监听
    ChatRepo.onDeleteMessage(this.onDeleteFun)
    // 注册消息撤回监听
    ChatRepo.onRevokeMessage(this.onRevokeFun)
  }

  // 销毁时取消注册监听
  onDestroy() {
    ChatRepo.offDeleteMessage(this.onDeleteFun)
    ChatRepo.offRevokeMessage(this.onRevokeFun)
  }

  // 查询历史消息,可通过 pageToken 加载更多
  async searchMessages() {

    let params: V2NIMMessageSearchExParams = {
      conversationId: this.conversationId,
      messageTypes: [
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT,
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE,
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO,
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO,
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION,
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE,
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM
      ],
      senderAccountIds: [this.sendId],
      limit: messageListLimit,
      pageToken: this.pageToken,
    }
    let searchResult: V2NIMMessageSearchResult | undefined = undefined
    if (IMKitConfigCenter.enableCloudSearch) {
      searchResult = await ChatRepo.searchCloudMessagesEx(params)
    } else {
      searchResult = await ChatRepo.searchLocalMessages(params)
    }

    if (!searchResult) {
      return
    }

    for (let index = searchResult.items.length - 1; index >= 0; index--) {
      let item = searchResult.items[index]
      if (item.conversationId === this.conversationId) {
        this.messageList.push(...item.messages)
      }
    }
    this.pageToken = searchResult.nextPageToken
    this.hasMore = searchResult.hasMore
  }

  // 删除消息回调
  private onDeleteFun = (deleteNotifications: V2NIMMessageDeletedNotification[]) => {
    for (const deleteNotification of deleteNotifications) {
      if (deleteNotification.messageRefer.conversationId === this.conversationId) {
        // 从消息列表中移除
        this.messageList = this.messageList.filter(
          item => item.messageClientId !== deleteNotification.messageRefer.messageClientId
        )
      }
    }
    this.revokeAndeDeleteMission = true
  }

  // 撤回消息回调
  private onRevokeFun = (revokeNotifications: V2NIMMessageRevokeNotification[]) => {
    for (const revokeNotification of revokeNotifications) {
      if (revokeNotification.messageRefer.conversationId === this.conversationId) {
        // 找到被撤回的消息，修改其 text 为已撤回
        let revokeIndex: number = -1
        for (let i = 0; i < this.messageList.length; i++) {
          if (this.messageList[i].messageClientId === revokeNotification.messageRefer.messageClientId) {
            revokeIndex = i
            break;
          }
        }
        if (revokeIndex < 0) {
          continue;
        }
        // 替换：修改 text 并增加版本号强制刷新
        this.messageList[revokeIndex].text = getContext().resourceManager.getStringByNameSync('chat_msg_undo_tips')
        const oldClientId = this.messageList[revokeIndex].messageClientId
        this.messageList[revokeIndex].messageClientId = util.generateRandomUUID()
        // sleep 200ms 后恢复 oldClientId
        setTimeout(() => {
          this.messageList[revokeIndex].messageClientId = oldClientId
        }, 200)
      }
    }
    this.revokeAndeDeleteMission = true
  }

  // 重置删除/撤回标志
  public resetRevokeAndeDeleteMission(): void {
    this.revokeAndeDeleteMission = false
  }
}

export const messageListLimit: number = 100
