/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ChatRepo, ErrorUtils } from '@nimkit/chatkit';
import {
  V2NIMCollection,
  V2NIMErrorCode,
  V2NIMMessage,
  V2NIMMessageConfig,
  V2NIMQueryDirection,
  V2NIMSendMessageParams
} from '@nimsdk/base';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { CollectionMessageModel } from '../model/CollectionMessageModel';
import { getMessageImageUrls, sendMessageFailedTips } from '../common/MessageHelper';
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
        this.parseCollectionMessage(collections)
      }
      this.collectionListEmpty = this.collectionList.length <= 0
    } catch (err) {
      console.error(err)
    }
  }

  parseCollectionMessage(collections: V2NIMCollection[]) {
    for (const collection of collections) {
      let collectionModel = new CollectionMessageModel()
      collectionModel.collection = collection

      const jsonData = JSON.parse(collection.collectionData) as object
      if (jsonData) {

        const messageJSON = jsonData['message'] as string
        const message = ChatKitClient.nim.messageConverter.messageDeserialization(messageJSON)
        if (message) {
          collectionModel.message = new NIMMessageInfo(message)
        }

        const conversationName = jsonData['conversationName'] as string
        collectionModel.conversationName = conversationName

        const senderName = jsonData['senderName'] as string
        collectionModel.senderName = senderName

        const avatar = jsonData['avatar'] as string
        collectionModel.avatar = avatar

        this.collectionList.push(collectionModel)
      }
    }
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
  beforeSendMessage(msg: V2NIMMessage): V2NIMMessage {
    let msgConfig: V2NIMMessageConfig = {
      readReceiptEnabled: true
    }
    msg.messageConfig = msgConfig
    return msg
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
    ChatRepo.sendMessage(this.beforeSendMessage(msg), conversationId, params, progress).catch((err: BusinessError) => {
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