/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  ChatKitClient,
  ChatRepo,
  ContactRepo,
  ConversationSelectModel,
  ErrorUtils,
  NEFriendUserCache,
  NEUserWithFriend,
  TeamMemberWithUser,
  TeamRepo
} from '@nimkit/chatkit';
import {
  V2NIMCollection,
  V2NIMConversationType,
  V2NIMErrorCode,
  V2NIMMessage,
  V2NIMQueryDirection,
  V2NIMSendMessageParams,
  V2NIMTeamType
} from '@nimsdk/base';
import {
  buildSendMessageParams,
  getMessageImageUrls,
  NIMMessageInfo,
  sendMessageFailedTips
} from '@nimkit/chatkit_ui';
import { CollectionMessageModel } from '../model/CollectionMessageModel';
import { BusinessError } from '@kit.BasicServicesKit';
import { NECommonUtils } from '@nimkit/common';

@ObservedV2
export class CollectionMessageViewModel {
  @Trace collectionList: CollectionMessageModel[] = [];
  @Trace collectionListEmpty: boolean = false;
  @Trace conversationId: string = "";
  @Trace topInsert = false
  @Trace isFinished = false
  pageLimit = 100
  private userInfoCache: Map<string, NEUserWithFriend | null> = new Map()
  private teamNameCache: Map<string, string> = new Map()
  private teamMemberCache: Map<string, TeamMemberWithUser | null> = new Map()

  // 获取标记列表
  async getCollectionMessageList() {
    if (this.isFinished) {
      return
    }

    let anchor: V2NIMCollection | undefined = undefined
    if (this.collectionList.length > 0) {
      anchor = this.collectionList[this.collectionList.length - 1].collection
    }

    let beginTime: number | undefined = undefined
    let endTime: number | undefined = undefined
    if (!anchor) {
      endTime = Date.now()
    }

    try {
      const collections = await ChatRepo.getCollectionListByOption({
        anchorCollection: anchor,
        endTime: endTime,
        limit: this.pageLimit,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC
      })

      this.isFinished = collections.length <= 0
      if (!this.isFinished) {
        await this.parseCollectionMessage(collections)
      }
      this.collectionListEmpty = this.collectionList.length <= 0
    } catch (err) {
      console.error(err)
    }
  }

  async parseCollectionMessage(collections: V2NIMCollection[]) {
    for (const collection of collections) {
      let collectionModel = new CollectionMessageModel()
      collectionModel.collection = collection

      try {
        const jsonData = JSON.parse(collection.collectionData) as Record<string, string>

        const messageJSON = jsonData['message'] as string
        const message = ChatKitClient.nim.messageConverter.messageDeserialization(messageJSON)
        if (!message) {
          continue
        }
        collectionModel.message = new NIMMessageInfo(message)

        const conversationName = jsonData['conversationName'] as string
        collectionModel.conversationName = conversationName

        const senderName = jsonData['senderName'] as string
        collectionModel.senderName = senderName

        const avatar = jsonData['avatar'] as string
        collectionModel.avatar = avatar

        // 历史收藏快照可能缺少展示资料，按消息当前资料兜底
        await this.fillCollectionDisplayInfo(collectionModel, message)
        this.collectionList.push(collectionModel)
      } catch (err) {
        console.error(err)
      }
    }
  }

  private async fillCollectionDisplayInfo(collectionModel: CollectionMessageModel, message: V2NIMMessage) {
    if (!this.isBlank(collectionModel.conversationName) &&
      !this.isBlank(collectionModel.senderName) &&
      !this.isBlank(collectionModel.avatar)) {
      return
    }

    if (message.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      await this.fillP2PCollectionDisplayInfo(collectionModel, message)
      return
    }

    if (message.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
      await this.fillTeamCollectionDisplayInfo(collectionModel, message)
    }
  }

  private async fillP2PCollectionDisplayInfo(collectionModel: CollectionMessageModel, message: V2NIMMessage) {
    const senderId = message.senderId ?? ''
    const targetId = this.getConversationTargetId(message)
    const senderInfo = await this.getUserWithFriend(senderId)
    const targetInfo = targetId.length > 0 && targetId !== senderId ? await this.getUserWithFriend(targetId) : senderInfo

    if (this.isBlank(collectionModel.senderName)) {
      collectionModel.senderName = this.getDisplayName(senderId, senderInfo)
    }
    if (this.isBlank(collectionModel.avatar)) {
      collectionModel.avatar = this.getAvatar(senderInfo)
    }
    if (this.isBlank(collectionModel.conversationName)) {
      collectionModel.conversationName = this.getDisplayName(targetId, targetInfo)
    }
  }

  private async fillTeamCollectionDisplayInfo(collectionModel: CollectionMessageModel, message: V2NIMMessage) {
    const senderId = message.senderId ?? ''
    const teamId = this.getConversationTargetId(message)
    const member = await this.getTeamMember(teamId, senderId)
    const senderInfo = member ? undefined : await this.getUserWithFriend(senderId)

    if (this.isBlank(collectionModel.senderName)) {
      collectionModel.senderName = member?.getNickname() ?? this.getDisplayName(senderId, senderInfo)
    }
    if (this.isBlank(collectionModel.avatar)) {
      collectionModel.avatar = member?.getAvatar() ?? this.getAvatar(senderInfo)
    }
    if (this.isBlank(collectionModel.conversationName)) {
      const teamName = await this.getTeamName(teamId)
      collectionModel.conversationName = teamName.length > 0 ? teamName : teamId
    }
  }

  private async getUserWithFriend(accountId: string): Promise<NEUserWithFriend | undefined> {
    if (accountId.length <= 0) {
      return undefined
    }

    if (this.userInfoCache.has(accountId)) {
      return this.userInfoCache.get(accountId) ?? undefined
    }

    const friendUserCache = NEFriendUserCache.getInstance()
    const cachedInfo = accountId === ChatKitClient.getLoginUserId() ?
      NEFriendUserCache.mineUserCache : friendUserCache.getFriendById(accountId)

    if (cachedInfo?.user) {
      this.userInfoCache.set(accountId, cachedInfo)
      return cachedInfo
    }

    const localUser = (await ContactRepo.getUserList([accountId]))[0]
    if (localUser) {
      const localInfo = new NEUserWithFriend({
        friend: cachedInfo?.friend,
        user: localUser
      })
      if (accountId === ChatKitClient.getLoginUserId()) {
        NEFriendUserCache.mineUserCache = localInfo
      }
      this.userInfoCache.set(accountId, localInfo)
      return localInfo
    }

    const remoteInfo = (await ContactRepo.getUserWithFriendByIds([accountId]))[0]
    const finalInfo = remoteInfo ?? cachedInfo
    if (accountId === ChatKitClient.getLoginUserId() && finalInfo) {
      NEFriendUserCache.mineUserCache = finalInfo
    }
    this.userInfoCache.set(accountId, finalInfo ?? null)
    return finalInfo
  }

  private async getTeamMember(teamId: string, accountId: string): Promise<TeamMemberWithUser | undefined> {
    if (teamId.length <= 0 || accountId.length <= 0) {
      return undefined
    }

    const cacheKey = `${teamId}|${accountId}`
    if (this.teamMemberCache.has(cacheKey)) {
      return this.teamMemberCache.get(cacheKey) ?? undefined
    }

    const member = (await TeamRepo.getTeamMembersByIds(
      teamId,
      V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
      [accountId]
    ))[0]
    this.teamMemberCache.set(cacheKey, member ?? null)
    return member
  }

  private async getTeamName(teamId: string): Promise<string> {
    if (teamId.length <= 0) {
      return ''
    }

    if (this.teamNameCache.has(teamId)) {
      return this.teamNameCache.get(teamId) ?? ''
    }

    const team = await TeamRepo.getTeamInfo(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL)
    const teamName = team?.name ?? ''
    this.teamNameCache.set(teamId, teamName)
    return teamName
  }

  private getConversationTargetId(message: V2NIMMessage): string {
    const conversationId = message.conversationId ?? ''
    const targetId = conversationId.length > 0 ?
      ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId) : ''
    if (targetId.length > 0) {
      return targetId
    }
    return message.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P ?
      (message.senderId === ChatKitClient.getLoginUserId() ? message.receiverId : message.senderId) :
      (message.receiverId ?? '')
  }

  private getDisplayName(accountId: string, userWithFriend?: NEUserWithFriend): string {
    if (accountId.length <= 0) {
      return ''
    }
    return userWithFriend?.showName() ?? accountId
  }

  private getAvatar(userWithFriend?: NEUserWithFriend): string {
    return userWithFriend?.getAvatar() ?? ''
  }

  private isBlank(value?: string): boolean {
    return value === undefined || value.trim().length <= 0
  }

  async deleteCollectionMessage(collection: CollectionMessageModel) {
    if (collection.collection) {
      await ChatRepo.removeCollections([collection.collection]).catch((err: BusinessError) => {
        if (err.code == V2NIMErrorCode.V2NIM_ERROR_CODE_COLLECTION_NOT_EXIST) {
          return
        }
        ErrorUtils.handleErrorToast(err.code)
      })
      NECommonUtils.showToast($r('app.string.delete_success'))
      for (let index = 0; index < this.collectionList.length; index++) {
        const deleteCollection = this.collectionList[index];
        if (deleteCollection === collection) {
          this.collectionList.splice(index, 1)
        }
      }
    }
  }

  getMessageImageUrls(message?: NIMMessageInfo) {
    let messageList: NIMMessageInfo[] = []
    for (const collection of this.collectionList) {
      if (collection.message) {
        messageList.push(collection.message)
      }
    }

    return getMessageImageUrls(message, undefined, messageList)
  }

  // 消息发送之前调用，用于配置消息通用参数
  beforeSendMessage(params?: V2NIMSendMessageParams): V2NIMSendMessageParams | undefined {
    return buildSendMessageParams(params)
  }

  /**
   * 转发消息
   * @param msg 消息体
   * @param conversationId 转发到某个会话
   * @param params 消息参数
   * @param progress 消息发送进度
   */
  async sendForwardMessage(msg: V2NIMMessage, conversationId: string, params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void) {
    msg.subType = undefined // 兼容其他端
    const mergedParams = this.beforeSendMessage(params)
    ChatRepo.sendMessage(msg, conversationId, mergedParams, progress).catch((err: BusinessError) => {
      console.error("net ease send message error", err.code, err.message);
      sendMessageFailedTips(msg, err, conversationId)
    })
  }

  /**
   * 将多个消息转发到多个会话中，并将留言发送到多个会话中
   * @param messages 待转发的消息
   * @param conversationIds 带转发的会话
   * @param leaveText 留言
   */
  forwardMessage(messages: NIMMessageInfo[], conversationIds: ConversationSelectModel[],
    leaveText: string | undefined) {
    conversationIds.forEach((conversation) => {
      messages.forEach((message) => {
        const forwardMsg = ChatRepo.createForwardMessage(message.message)
        try {
          if (forwardMsg && conversation.conversationId) {
            this.sendForwardMessage(forwardMsg, conversation.conversationId)
          }
        } catch (err) {
          console.error(err)
        }
      })

      // 发送留言
      if (leaveText && leaveText.length > 0) {
        const leaveMsg = ChatRepo.createTextMessage(leaveText)
        if (leaveMsg && conversation.conversationId) {
          setTimeout(() => {
            ChatRepo.sendMessage(leaveMsg, conversation.conversationId!).catch((err: BusinessError) => {
              console.error("net ease send message error", err.code, err.message);
              sendMessageFailedTips(leaveMsg, err, conversation.conversationId!)
            })
          }, 200)
        }
      }
    })
  }

  onDestroy(): void {
  }
}
