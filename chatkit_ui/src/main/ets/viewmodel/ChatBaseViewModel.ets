/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  AitModel,
  ChatKitClient,
  ChatRepo,
  CloudConversationStrategy,
  collectionTypeOffset,
  ConversationStrategy,
  createMultiLineAttachment,
  DisposableBag,
  ErrorUtils,
  IMKitConfigCenter,
  LoginEventRepo,
  LocalConversationStrategy,
  NEAIUserCache,
  normalizeMultiLineTitle,
  PushConfigManager,
  StorageRepo,
  YxAitMsg
} from '@nimkit/chatkit';
import fs from '@ohos.file.fs';
import {
  NIMEStrAnyObj,
  V2NIMAIUser,
  V2NIMConnectStatus,
  V2NIMDataSyncState,
  V2NIMDataSyncType,
  V2NIMError,
  V2NIMErrorCode,
  V2NIMErrorMap,
  V2NIMLoginStatus,
  V2NIMMessage,
  V2NIMMessageListOption,
  V2NIMMessageListResult,
  V2NIMMessageAIConfigParams,
  V2NIMMessageAIRegenOpType,
  V2NIMMessageAIRegenParams,
  V2NIMMessageAIStatus,
  V2NIMMessageAIStreamStatus,
  V2NIMMessageAIStreamStopOpType,
  V2NIMMessageAIStreamStopParams,
  V2NIMMessageAudioAttachment,
  V2NIMMessageDeletedNotification,
  V2NIMMessageFileAttachment,
  V2NIMMessagePinNotification,
  V2NIMMessagePinState,
  V2NIMMessageQuickComment,
  V2NIMMessageQuickCommentNotification,
  V2NIMMessageRevokeNotification,
  V2NIMMessageSendingState,
  V2NIMMessageType,
  V2NIMQueryDirection,
  V2NIMSendMessageParams,
  V2NIMSendMessageResult,
  V2NIMVoiceToTextParams
} from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { ChatInfo } from '../model/ChatInfo';
import { ChatConst } from '../constants/ChatConst';
import { BusinessError } from '@kit.BasicServicesKit';
import { DeviceUtils } from '../common/DeviceUtils';
import { image } from '@kit.ImageKit';
import {
  saveLocalRevokeMessage,
  saveLocalRevokeMessageFormOther
} from '@nimkit/chatkit';
import { ConversationSelectModel } from '@nimkit/chatkit';
import { sceneMap } from '@kit.MapKit';
import { clearForwardAtMark, createForwardMessageListFileDetail, sendMessageFailedTips } from '../common/MessageHelper';
import { buildSendMessageParams } from '../common/SendMessageParamsHelper';
import { instanceToPlain } from 'class-transformer';
import { NECommonUtils } from '@nimkit/common';
import { HashMap, JSON } from '@kit.ArkTS';
import { buildMessageJumpPlan } from '../utils/ChatJumpUtils';
import {
  buildAIReplyContextMessage,
  buildAIContextMessages,
  getAIMessageContent,
  resolveAIMessageContentForForward,
  resolveAIMessageContentForSend
} from '../common/AIChatUtils';
import {
  buildLastReadMessageQueryOption,
  canShowLastReadPosition,
  createLastReadPositionStatus,
  finishLastReadPositionJump,
  LastReadUnreadDisplayCount,
  LastReadPositionStatus,
  queryLocalUnreadDisplayCount,
  resolveLastReadPositionAfterUnreadCount,
  startLastReadPositionJump,
  updateLastReadPositionStatus
} from '../utils/LastReadPositionUtils';
import {
  applyQuickCommentNotification,
  buildQuickCommentBatches,
  canShowMessageReaction,
  isMessageReactionEnabled,
  isQuickCommentLimitErrorCode,
  quickCommentResultToMap
} from '../utils/MessageReactionUtils';
import { ChatKitConfig } from '../ChatKitConfig';
import { buildStickerTempFileName, toExactArrayBuffer, writeStickerBufferSync } from '../utils/StickerFileUtils';

@ObservedV2
export class ChatBaseViewModel {
  @Trace static currentViewModel: ChatBaseViewModel | undefined = undefined
  @Trace anchorMsg: NIMMessageInfo | undefined = undefined
  @Trace conversationId: string = ''
  // p2p 会话是对方账号ID，群聊是为群ID teamId
  targetId: string = ''
  @Trace chatInfo: ChatInfo | undefined = undefined
  @Trace selectMsgMap: Map<string, NIMMessageInfo> = new Map()
  @Trace selectMsgCount = 0
  @Trace needScrollToBottom = false
  @Trace lastReadTime: number = 0
  @Trace lastReadPositionStatus: LastReadPositionStatus = LastReadPositionStatus.DISABLED
  @Trace lastReadUnreadCount: number = 0
  @Trace lastReadUnreadOverflow: boolean = false
  @Trace lastReadVisibleStateReady: boolean = false
  isLoading = false
  hasMore = false
  hasNew = false
  onOperateMessageInvalid?: (messageClientId: string) => void = undefined
  onLastReadTimeReady?: () => void = undefined
  revokeMsg: NIMMessageInfo | undefined = undefined
  sendingMsgClientId: string = ''
  saveRevokeClientId: string = ''
  hasLoadData = false
  // 网络连接状态
  @Trace networkBroken: boolean = ChatKitClient.connectBroken()
  // 页面是否可见（用于控制是否发送已读回执）
  isPageVisible: boolean = true
  // 流式 ing 缓存数据
  private streamingMessageMap: HashMap<string, StreamMessage> = new HashMap();
  private loginEventDisposers: DisposableBag = new DisposableBag()
  private conversationReadReadyPromise: Promise<void> = Promise.resolve()
  private conversationLifecycleVersion: number = 0
  private lastReadConfigVersion: number = 0
  private lastReadTimeFrozen: boolean = false
  private lastReadTargetMessageClientId: string = ''
  private lastReadTargetMessageCreateTime: number = 0
  private useLocalConversation: boolean = false
  private readonly cloudConversationStrategy: ConversationStrategy = new CloudConversationStrategy()
  private readonly localConversationStrategy: ConversationStrategy = new LocalConversationStrategy()
  private conversationStrategy: ConversationStrategy = this.cloudConversationStrategy
  private queriedQuickCommentMessageIds: Set<string> = new Set<string>()
  private inFlightQuickCommentMessageIds: Set<string> = new Set<string>()
  private quickCommentNotificationsDuringQuery: Map<string, V2NIMMessageQuickCommentNotification[]> =
    new Map<string, V2NIMMessageQuickCommentNotification[]>()
  private quickCommentRetryConnectionVersions: Map<string, number> = new Map<string, number>()
  private pendingQuickCommentKeys: Set<string> = new Set<string>()
  private quickCommentQueryGeneration: number = 0
  private quickCommentConnectionVersion: number = 0
  private messageReactionListenerRegistered: boolean = false
  // 最早未读定位期间收到的消息需要在 cleanMessage 后重新合并。
  private pendingReceivedMessages: V2NIMMessage[] = []
  // 发送消息
  onSendFun = async (message: V2NIMMessage): Promise<void> => {
    if (message.conversationId === this.conversationId) {
      if (message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
        if (message.messageClientId !== this.sendingMsgClientId) {
          this.sendingMsgClientId = message.messageClientId
          this.chatInfo?.pushMessage(message)
          this.chatInfo?.setReceiveMsg(true, [message])
        }

      } else {
        // 发送失败 & 发送失败等其他状态
        let result = this.chatInfo?.updateMessageStatus(message)
        if (!result) {
          this.chatInfo?.setReceiveMsg(true, [message])
        }
        if (message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SUCCEEDED) {
          const messageInfo = this.chatInfo?.getMessage(message.messageClientId)
          if (messageInfo !== undefined) {
            this.loadQuickComments([messageInfo])
          }
          // 调用钩子方法，子类可以实现自定义逻辑（如获取群消息已读回执）
          this.toHandleSendMessageSuccess(message)
        }
      }
    }
  }
  private msgDirection: number = 0

  setAnchorMessage(msg: NIMMessageInfo | undefined) {
    this.anchorMsg = msg
    if (msg !== undefined) {
      this.lastReadPositionStatus = updateLastReadPositionStatus(
        this.lastReadPositionStatus,
        this.lastReadTime,
        msg.message.createTime
      )
    }
  }

  jumpToMessage(msg: NIMMessageInfo | undefined): void {
    if (!msg) {
      return
    }

    const messageClientIds = this.chatInfo?.msgList.getMessageList().map((item: NIMMessageInfo) => {
      return item.message.messageClientId
    }) ?? []
    const jumpPlan = buildMessageJumpPlan(msg.message.messageClientId, messageClientIds)
    if (jumpPlan.scrollIndex >= 0) {
      this.chatInfo?.setScrollIndex(jumpPlan.scrollIndex)
      return
    }
    if (jumpPlan.shouldLoadAnchor) {
      this.setAnchorMessage(msg)
    }
  }

  init(conversationId: string, chatInfo: ChatInfo) {
    const lifecycleVersion = ++this.conversationLifecycleVersion
    const lastReadConfigVersion = ++this.lastReadConfigVersion
    this.conversationId = conversationId
    this.targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    this.chatInfo = chatInfo;
    this.lastReadTime = 0
    this.lastReadPositionStatus = LastReadPositionStatus.DISABLED
    this.lastReadUnreadCount = 0
    this.lastReadUnreadOverflow = false
    this.lastReadVisibleStateReady = false
    this.lastReadTimeFrozen = false
    this.lastReadTargetMessageClientId = ''
    this.lastReadTargetMessageCreateTime = 0
    this.useLocalConversation = IMKitConfigCenter.enableLocalConversation
    this.conversationStrategy = this.useLocalConversation ? this.localConversationStrategy : this.cloudConversationStrategy
    this.queriedQuickCommentMessageIds.clear()
    this.inFlightQuickCommentMessageIds.clear()
    this.quickCommentNotificationsDuringQuery.clear()
    this.quickCommentRetryConnectionVersions.clear()
    this.pendingQuickCommentKeys.clear()
    this.quickCommentQueryGeneration++
    this.pendingReceivedMessages = []
    // UIKit 当前会话需立即生效；本地 SDK current conversation 在旧 read time 冻结后再同步。
    ChatKitClient.registerCurrentConversationId(this.conversationId)
    // 注册消息接受监听
    ChatRepo.onReceiverMessage(this.onReceiveFun)
    // 注册消息更新监听
    ChatRepo.onReceiveMessagesModified(this.onModifyFun)
    // 注册消息发送监听
    ChatRepo.onSendMessage(this.onSendFun)
    // 注册消息删除监听
    ChatRepo.onDeleteMessage(this.onDeleteFun)
    // 注册消息撤回监听
    ChatRepo.onRevokeMessage(this.onRevokeFun)
    // 注册消息置顶监听
    ChatRepo.onMessagePinNotification(this.onPinFun)
    if (this.isMessageReactionEnabled()) {
      ChatRepo.onMessageQuickCommentNotification(this.onQuickCommentFun)
      this.messageReactionListenerRegistered = true
    }

    // 监听数据同步完成监听
    this.loginEventDisposers.dispose()
    this.loginEventDisposers.addAll([
      LoginEventRepo.onDataSync(this.onSyncFinishedFun),
      LoginEventRepo.onConnectStatus(this.onConnectStatusChange),
      LoginEventRepo.onLoginStatus(this.onLoginStatusChange)
    ])

    ChatBaseViewModel.currentViewModel = this
    if (this.enableLastReadPosition()) {
      this.conversationReadReadyPromise = this.prepareConversationReadState(lifecycleVersion, lastReadConfigVersion)
    } else {
      ChatKitClient.setCurrentConversationId(this.conversationId)
      this.conversationReadReadyPromise = this.clearUnread()
    }
  }

  enableLastReadPosition(): boolean {
    return ChatKitConfig.enableLastReadPosition
  }

  refreshLastReadPositionState(): void {
    const configVersion = ++this.lastReadConfigVersion
    if (!this.enableLastReadPosition()) {
      this.lastReadPositionStatus = LastReadPositionStatus.DISABLED
      this.lastReadUnreadCount = 0
      this.lastReadUnreadOverflow = false
      this.lastReadVisibleStateReady = false
      this.lastReadTime = 0
      this.lastReadTimeFrozen = false
      this.conversationReadReadyPromise = Promise.resolve()
      return
    }
    this.lastReadTimeFrozen = false
    this.lastReadPositionStatus = LastReadPositionStatus.DISABLED
    this.lastReadUnreadCount = 0
    this.lastReadUnreadOverflow = false
    this.lastReadVisibleStateReady = false
    this.lastReadTargetMessageClientId = ''
    this.lastReadTargetMessageCreateTime = 0
    this.conversationReadReadyPromise = this.prepareConversationReadState(
      this.conversationLifecycleVersion, configVersion)
  }

  private isCurrentConversationLifecycle(lifecycleVersion: number): boolean {
    return lifecycleVersion === this.conversationLifecycleVersion
  }

  private async prepareConversationReadState(lifecycleVersion: number, configVersion: number): Promise<void> {
    let readTime: number | undefined = undefined
    try {
      readTime = await this.conversationStrategy.getConversationReadTime(this.conversationId)
    } catch (err) {
      Logger.error('ChatKitUI', '[LastReadPosition] getConversationReadTime failed', `${err}`)
    }

    if (!this.isCurrentConversationLifecycle(lifecycleVersion) ||
      configVersion !== this.lastReadConfigVersion || !this.enableLastReadPosition()) {
      return
    }
    if (!this.lastReadTimeFrozen) {
      this.lastReadTimeFrozen = true
      this.lastReadPositionStatus = createLastReadPositionStatus(readTime)
      this.lastReadTime = readTime ?? 0
      Logger.debug('ChatKitUI', '[LastReadPosition] read time frozen', this.conversationId, this.lastReadTime,
        this.useLocalConversation)
    }

    if (readTime !== undefined && readTime >= 0) {
      try {
        const unreadDisplayCount: LastReadUnreadDisplayCount = await queryLocalUnreadDisplayCount(
          this.conversationId,
          readTime,
          async (option: V2NIMMessageListOption): Promise<V2NIMMessageListResult> => {
            return await ChatRepo.getMessageListEx(option)
          }
        )
        if (!this.isCurrentConversationLifecycle(lifecycleVersion) ||
          configVersion !== this.lastReadConfigVersion || !this.enableLastReadPosition()) {
          return
        }
        this.lastReadUnreadCount = unreadDisplayCount.count
        this.lastReadUnreadOverflow = unreadDisplayCount.overflow
        this.lastReadTargetMessageClientId = unreadDisplayCount.targetMessageClientId
        this.lastReadTargetMessageCreateTime = unreadDisplayCount.targetMessageCreateTime
        this.lastReadPositionStatus = resolveLastReadPositionAfterUnreadCount(
          this.lastReadPositionStatus,
          unreadDisplayCount.count
        )
        Logger.debug('ChatKitUI', '[LastReadPosition] local unread count frozen', this.conversationId,
          unreadDisplayCount.count, unreadDisplayCount.overflow)
        this.onLastReadTimeReady?.()
      } catch (err) {
        if (!this.isCurrentConversationLifecycle(lifecycleVersion) ||
          configVersion !== this.lastReadConfigVersion || !this.enableLastReadPosition()) {
          return
        }
        this.lastReadUnreadCount = 0
        this.lastReadUnreadOverflow = false
        this.lastReadPositionStatus = LastReadPositionStatus.DISABLED
        Logger.error('ChatKitUI', '[LastReadPosition] query local unread count failed', `${err}`)
      }
    }

    await this.clearUnread()
    if (!this.isCurrentConversationLifecycle(lifecycleVersion) ||
      configVersion !== this.lastReadConfigVersion || !this.enableLastReadPosition()) {
      return
    }
    ChatKitClient.setCurrentConversationId(this.conversationId)
  }

  onConnectStatusChange = (status: V2NIMConnectStatus) => {
    if (status === V2NIMConnectStatus.V2NIM_CONNECT_STATUS_CONNECTED) {
      this.networkBroken = false
      this.quickCommentConnectionVersion++
      this.loadVisibleQuickComments()
    } else {
      this.networkBroken = true
    }
  }
  onLoginStatusChange = (status: V2NIMLoginStatus) => {
    if (status === V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED) {
      this.networkBroken = false
      this.quickCommentConnectionVersion++
      this.loadVisibleQuickComments()
    }
  }
  // 处理数据同步完成
  onSyncFinishedFun = (type: V2NIMDataSyncType,
    state: V2NIMDataSyncState,
    error?: V2NIMError) => {
    if (state == V2NIMDataSyncState.V2NIM_DATA_SYNC_STATE_COMPLETED) {
      this.toHandleDataSyncFinished()
    }
  }
  // 接受消息
  onReceiveFun = (messages: V2NIMMessage[]) => {
    this.handleReceiveMessages(messages)
  }

  handleReceiveMessages(messages: V2NIMMessage[]): void {
    if (this.hasNew) {
      // 定位历史消息时保留新消息在列表尾部，避免手动滚动后仍无法看到消息。
      const messagesWhenHasNew: V2NIMMessage[] = messages.filter((msg: V2NIMMessage) => {
        return msg.conversationId == this.conversationId
      })
      const newMessages: V2NIMMessage[] = messagesWhenHasNew.filter((msg: V2NIMMessage) => {
        return this.chatInfo?.getMessage(msg.messageClientId) === undefined &&
          !this.pendingReceivedMessages.some((pending: V2NIMMessage) => {
            return pending.messageClientId === msg.messageClientId
          })
      })
      if (this.isLastReadPositionLocating) {
        this.pendingReceivedMessages.push(...newMessages)
      }
      const receiveMessages: NIMMessageInfo[] = []
      newMessages.forEach((message: V2NIMMessage): void => {
        const messageInfo = this.chatInfo?.pushMessage(message)
        if (messageInfo !== undefined) {
          receiveMessages.push(messageInfo)
        }
      })
      if (receiveMessages.length > 0) {
        this.toHandleReceiveMessage(receiveMessages)
        this.loadQuickComments(receiveMessages)
      }
      this.chatInfo?.setReceiveMsg(true, newMessages)
      return
    }
    let hasNew = false
    let receiveMsgs: NIMMessageInfo[] = [];
    for (let i = messages.length - 1; i >= 0; i--) {
      let msg = messages[i];
      if (msg.conversationId == this.conversationId) {
        const msgInfo: NIMMessageInfo | undefined = this.chatInfo?.pushMessage(msg);
        if (msgInfo !== undefined) {
          receiveMsgs.push(msgInfo)
        }
        hasNew = true;
      }
    }
    if (hasNew) {
      this.toHandleReceiveMessage(receiveMsgs)
      this.loadQuickComments(receiveMsgs)
      // this.clearUnreadCount()
      this.chatInfo?.setReceiveMsg(true, receiveMsgs.map((receiveMsg: NIMMessageInfo) => { return receiveMsg.message}));
    }
  }
  // 更新消息
  onModifyFun = (messages: V2NIMMessage[]) => {
    for (let i = messages.length - 1; i >= 0; i--) {
      let message = messages[i];
      // 流式并且机器人回复消息，走流式展示逻辑
      if (message.aiConfig?.aiStream && message.aiConfig?.aiStatus === V2NIMMessageAIStatus.V2NIM_MESSAGE_AI_STATUS_RESPONSE) {
        this.onModifyFunStream(message)
      } else {
        this.onModifyFunNormal(message)
      }
    }
  }

  private onModifyFunNormal = (message: V2NIMMessage) => {
    if (this.hasNew) {
      return
    }
    let hasNew = false
    let receiveMsgs: NIMMessageInfo[] = [];
    if (message.conversationId == this.conversationId) {
      let msgInfo = this.chatInfo?.pushModifyMessage(message);
      if (msgInfo !== undefined) {
        receiveMsgs.push(msgInfo)
      }
      hasNew = true;
    }
    if (hasNew) {
      this.toHandleReceiveMessage(receiveMsgs)
      this.loadQuickComments(receiveMsgs)
      // this.clearUnreadCount() // 更新消息不做 clear 动作
      this.chatInfo?.setReceiveMsg(true, receiveMsgs.map((receiveMsg: NIMMessageInfo) => { return receiveMsg.message}));
    }
  }

  private onModifyFunStream = async (message: V2NIMMessage) => {
    if (message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING) {
      // 检查新老情况
      const messageClientId: string = message.messageClientId
      const oldStreamMessage: StreamMessage | undefined = this.streamingMessageMap.get(messageClientId) // 老的
      const newStreamMessage: StreamMessage = new StreamMessage(message) // 新的
      this.streamingMessageMap.set(messageClientId, newStreamMessage) // 替换成新的

      // 准备裁切 message.text
      const oldLen = oldStreamMessage?.message?.text?.length ?? 0
      const newLen = newStreamMessage.message?.text?.length ?? 0
      const newStr: string = newStreamMessage.message?.text ?? ''
      const currentIndex: number = newStreamMessage.index

      // 开始裁切
      for (let i = oldLen; i < newLen; i++) {
        const latestStreaming: StreamMessage | undefined = this.streamingMessageMap.get(messageClientId)
        if (latestStreaming.finish || currentIndex !== latestStreaming.index) {
          break; // finish or index 已经发生了变化，不再更新
        }
        const tmpMessage: V2NIMMessage = message
        const tmpStr: string = newStr.substring(0, i + 1);
        tmpMessage.text = tmpStr
        this.onModifyFunNormal(tmpMessage) // 循环 modify
        // 阻塞 20ms，避免循环过快而回调过快
        await new Promise<void>(resolve => {
          setTimeout(resolve, 20); // 例如，这里设置一个 20 毫秒的延迟。还有优化空间
        });
      }
    } else {
      if (message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STOPPED ||
        message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_UPDATED ||
        message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_GENERATED ||
        message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_ABORTED) {
        // finish
        const oldStreaming = this.streamingMessageMap.get(message.messageClientId)
        if (oldStreaming) {
          oldStreaming.finish = true
        } else {
          this.streamingMessageMap.set(message.messageClientId, new StreamMessage(message)) // finished message
        }
      }
      this.onModifyFunNormal(message) // 直接 modify
    }
  }

  // 删除消息
  onDeleteFun = (messages: V2NIMMessageDeletedNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId === this.conversationId) {
        this.removeReplyInfo(msg.messageRefer.messageClientId)
        this.chatInfo?.deleteMessage(msg.messageRefer.messageClientId)
        this.onOperateMessageInvalid?.(msg.messageRefer.messageClientId)
        if (this.selectMsgMap.has(msg.messageRefer.messageClientId)) {
          this.selectMsgMap.delete(msg.messageRefer.messageClientId)
          this.selectMsgCount = this.selectMsgMap.size
        }
      }
    })
    // 等待 1 秒，然后重新拉取一次消息
    if ((this.chatInfo?.msgList.totalCount() ?? 0) <= 0) {
      setTimeout(() => {
        this.getMessageList() // 被删完了消息之后，防止消息空了，重新拉取
      },  1000)
    }
  }
  // 撤回消息
  onRevokeFun = (messages: V2NIMMessageRevokeNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId === this.conversationId) {
        let revokeMsg = this.chatInfo?.getMessage(msg.messageRefer.messageClientId)
        this.removeReplyInfo(msg.messageRefer.messageClientId)
        this.chatInfo?.revokeMessage(msg.messageRefer.messageClientId, msg.messageRefer as V2NIMMessage)
        this.onOperateMessageInvalid?.(msg.messageRefer.messageClientId)
        if (this.selectMsgMap.has(msg.messageRefer.messageClientId)) {
          this.selectMsgMap.delete(msg.messageRefer.messageClientId)
          this.selectMsgCount = this.selectMsgMap.size
        }
        if (this.saveRevokeClientId == revokeMsg?.message.messageServerId) {
          return
        }
        this.saveRevokeClientId = revokeMsg?.message.messageServerId ?? ''
        Logger.debug('ChatKitUI', 'netease viewmodel onRevokeFun revoke message', msg.revokeAccountId,
          msg.messageRefer.messageClientId)
        if (revokeMsg !== undefined && msg.messageRefer.senderId == ChatKitClient.getLoginUserId()) {
          // 文本消息和多行消息（type=102）都支持撤回重编辑
          let canEdit =
            !revokeMsg.isReceiveMsg && (revokeMsg.message.messageType == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT ||
              revokeMsg.isMultiLineMsg)
          saveLocalRevokeMessage(msg.messageRefer.conversationId, revokeMsg.message, canEdit)
        } else {
          saveLocalRevokeMessageFormOther(msg.messageRefer.conversationId, msg, false)
        }
      }
    })
  }
  // 置顶消息
  onPinFun = ((notification: V2NIMMessagePinNotification) => {
    if (notification.pinState == V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_PINNED) {
      this.chatInfo?.addPinMessage([notification.pin])
      this.needScrollToBottom = true

    } else if (notification.pinState == V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_UPDATED) {
      this.chatInfo?.addPinMessage([notification.pin])
      this.needScrollToBottom = true

    } else if (notification.pinState == V2NIMMessagePinState.V2NIM_MESSAGE_PIN_STATE_NOT_PINNED) {
      this.chatInfo?.removePinMessage([notification.pin])
    }

  })

  onQuickCommentFun = (notification: V2NIMMessageQuickCommentNotification): void => {
    if (!this.isMessageReactionEnabled()) {
      return
    }
    const quickComment = notification.quickComment
    if (quickComment.messageRefer.conversationId !== this.conversationId) {
      return
    }
    const messageInfo = this.chatInfo?.getMessage(quickComment.messageRefer.messageClientId)
    if (messageInfo === undefined) {
      return
    }
    messageInfo.setQuickComments(applyQuickCommentNotification(messageInfo.quickComments, notification))
    if (this.inFlightQuickCommentMessageIds.has(messageInfo.getMessageClientId())) {
      const notifications = this.quickCommentNotificationsDuringQuery.get(messageInfo.getMessageClientId()) ?? []
      notifications.push(notification)
      this.quickCommentNotificationsDuringQuery.set(messageInfo.getMessageClientId(), notifications)
    }
    if (quickComment.operatorId === ChatKitClient.getLoginUserId()) {
      this.pendingQuickCommentKeys.delete(this.buildQuickCommentOperationKey(messageInfo, quickComment.index))
    }
    this.chatInfo?.notifyMessageChange(messageInfo.getMessageClientId())
    // Reaction 高度变化后，保持底部用户能看到最新内容
    this.needScrollToBottom = true
  }

  supportsMessageReaction(): boolean {
    return false
  }

  isMessageReactionEnabled(): boolean {
    return isMessageReactionEnabled(ChatKitConfig.enableEmojiReaction, this.supportsMessageReaction())
  }

  /** 同步全局开关变化到当前会话的 QuickComment 监听和缓存。 */
  refreshMessageReactionState(): void {
    if (this.isMessageReactionEnabled()) {
      if (!this.messageReactionListenerRegistered) {
        ChatRepo.onMessageQuickCommentNotification(this.onQuickCommentFun)
        this.messageReactionListenerRegistered = true
      }
      this.loadVisibleQuickComments()
      return
    }
    if (this.messageReactionListenerRegistered) {
      ChatRepo.offMessageQuickCommentNotification(this.onQuickCommentFun)
      this.messageReactionListenerRegistered = false
    }
    this.resetQuickCommentQueryState()
    const messages = this.chatInfo?.msgList.getMessageList() ?? []
    messages.forEach((messageInfo: NIMMessageInfo): void => {
      if (messageInfo.quickComments.length > 0) {
        messageInfo.setQuickComments([])
        this.chatInfo?.notifyMessageChange(messageInfo.getMessageClientId())
      }
    })
  }

  private buildQuickCommentOperationKey(messageInfo: NIMMessageInfo, index: number): string {
    return `${messageInfo.getMessageClientId()}:${index}`
  }

  async toggleQuickComment(messageInfo: NIMMessageInfo, index: number): Promise<boolean> {
    if (!this.isMessageReactionEnabled() || !canShowMessageReaction(messageInfo.message, messageInfo.isRevokeMsg)) {
      return false
    }
    const operationKey = this.buildQuickCommentOperationKey(messageInfo, index)
    if (this.pendingQuickCommentKeys.has(operationKey)) {
      return false
    }
    this.pendingQuickCommentKeys.add(operationKey)
    const lifecycleVersion = this.conversationLifecycleVersion
    const hasSelf = messageInfo.quickComments.some((comment: V2NIMMessageQuickComment): boolean => {
      return comment.index === index && comment.operatorId === ChatKitClient.getLoginUserId()
    })
    try {
      if (hasSelf) {
        await ChatRepo.removeQuickComment(messageInfo.message, index)
      } else {
        await ChatRepo.addQuickComment(messageInfo.message, index)
      }
      return true
    } catch (err) {
      if (!this.isCurrentConversationLifecycle(lifecycleVersion)) {
        return false
      }
      this.pendingQuickCommentKeys.delete(operationKey)
      Logger.error('ChatKitUI', '[MessageReaction] toggle failed', messageInfo.getMessageClientId(), index, `${err}`)
      const errorCode = (err as V2NIMError).code
      NECommonUtils.showToast(isQuickCommentLimitErrorCode(errorCode) ?
        $r('app.string.chat_message_reaction_limit') : $r('app.string.chat_message_reaction_failed'))
      return false
    }
  }

  private loadQuickComments(messages: NIMMessageInfo[]): void {
    if (!this.isMessageReactionEnabled()) {
      return
    }
    const lifecycleVersion = this.conversationLifecycleVersion
    const queryGeneration = this.quickCommentQueryGeneration
    const queryMessages: NIMMessageInfo[] = messages.filter((messageInfo: NIMMessageInfo): boolean => {
      const messageClientId = messageInfo.getMessageClientId()
      if (this.queriedQuickCommentMessageIds.has(messageClientId) ||
        !canShowMessageReaction(messageInfo.message, messageInfo.isRevokeMsg)) {
        return false
      }
      this.queriedQuickCommentMessageIds.add(messageClientId)
      return true
    })
    if (queryMessages.length === 0) {
      return
    }
    queryMessages.forEach((messageInfo: NIMMessageInfo): void => {
      this.inFlightQuickCommentMessageIds.add(messageInfo.getMessageClientId())
      this.quickCommentNotificationsDuringQuery.delete(messageInfo.getMessageClientId())
    })
    const messageInfoMap: Map<string, NIMMessageInfo> = new Map<string, NIMMessageInfo>()
    queryMessages.forEach((messageInfo: NIMMessageInfo): void => {
      messageInfoMap.set(messageInfo.getMessageClientId(), messageInfo)
    })
    const batches: V2NIMMessage[][] = buildQuickCommentBatches(queryMessages.map(
      (messageInfo: NIMMessageInfo): V2NIMMessage => {
        return messageInfo.message
      }))
    this.queryQuickCommentBatches(batches, messageInfoMap, lifecycleVersion, queryGeneration)
  }

  private loadVisibleQuickComments(): void {
    this.loadQuickComments(this.chatInfo?.msgList.getMessageList() ?? [])
  }

  private async queryQuickCommentBatches(
    batches: V2NIMMessage[][],
    messageInfoMap: Map<string, NIMMessageInfo>,
    lifecycleVersion: number,
    queryGeneration: number
  ): Promise<void> {
    for (const batch of batches) {
      try {
        const result: Map<string, V2NIMMessageQuickComment[]> = quickCommentResultToMap(await ChatRepo.getQuickCommentList(batch) ?? {})
        if (!this.isCurrentConversationLifecycle(lifecycleVersion) ||
          queryGeneration !== this.quickCommentQueryGeneration) {
          return
        }
        batch.forEach((message: V2NIMMessage): void => {
          const messageInfo = messageInfoMap.get(message.messageClientId)
          if (messageInfo === undefined) {
            return
          }
          const current = this.chatInfo?.getMessage(messageInfo.getMessageClientId())
          if (current === undefined) {
            return
          }
          let comments = result.get(current.getMessageClientId()) ?? []
          const notifications = this.quickCommentNotificationsDuringQuery.get(current.getMessageClientId()) ?? []
          notifications.forEach((notification: V2NIMMessageQuickCommentNotification): void => {
            comments = applyQuickCommentNotification(comments, notification)
          })
          current.setQuickComments(comments)
          this.inFlightQuickCommentMessageIds.delete(current.getMessageClientId())
          this.quickCommentNotificationsDuringQuery.delete(current.getMessageClientId())
          this.quickCommentRetryConnectionVersions.delete(current.getMessageClientId())
          this.chatInfo?.notifyMessageChange(current.getMessageClientId())
        })
        this.needScrollToBottom = true
      } catch (err) {
        if (!this.isCurrentConversationLifecycle(lifecycleVersion) ||
          queryGeneration !== this.quickCommentQueryGeneration) {
          return
        }
        const retryMessages: NIMMessageInfo[] = []
        batch.forEach((message: V2NIMMessage): void => {
          this.queriedQuickCommentMessageIds.delete(message.messageClientId)
          this.inFlightQuickCommentMessageIds.delete(message.messageClientId)
          this.quickCommentNotificationsDuringQuery.delete(message.messageClientId)
          const lastRetryVersion = this.quickCommentRetryConnectionVersions.get(message.messageClientId) ?? -1
          const current = this.chatInfo?.getMessage(message.messageClientId)
          if (!this.networkBroken && current !== undefined && lastRetryVersion !== this.quickCommentConnectionVersion) {
            this.quickCommentRetryConnectionVersions.set(message.messageClientId, this.quickCommentConnectionVersion)
            retryMessages.push(current)
          }
        })
        Logger.error('ChatKitUI', '[MessageReaction] getQuickCommentList failed', `${err}`)
        this.loadQuickComments(retryMessages)
      }
    }
  }

  private resetQuickCommentQueryState(): void {
    this.quickCommentQueryGeneration++
    this.queriedQuickCommentMessageIds.clear()
    this.inFlightQuickCommentMessageIds.clear()
    this.quickCommentNotificationsDuringQuery.clear()
    this.quickCommentRetryConnectionVersions.clear()
  }

  loadAnchorMsg(msg: NIMMessageInfo) {
    this.loadMessageListWithAnchor(msg)
  }

  // 拉取历史消息
  async getMessageList(): Promise<NIMMessageInfo[]> {
    let hasError = false
    const messageList: V2NIMMessage[] = await ChatRepo.getMessageList({
      'conversationId': this.conversationId,
      'limit': ChatConst.chatMessagePageSize,
      'direction': this.msgDirection,
      'onlyQueryLocal': false,
      'strictMode': false // 非严格模式，允许无网络时回退到本地消息查询
    }).catch((err: BusinessError) => {
      hasError = true
      return []
    })
    let result: NIMMessageInfo[] = [];
    if (hasError) {
      return result
    }
    // 拉回的消息数据存在误差
    if (messageList.length >= ChatConst.chatMessagePageSize - 10) {
      this.hasMore = true;
    } else {
      this.hasMore = false;
    }
    this.resetQuickCommentQueryState()
    this.chatInfo?.cleanMessage()
    this.setAnchorMessage(undefined)
    for (let index = messageList.length - 1; index >= 0; index--) {
      let msgInfo = this.chatInfo?.pushMessage(messageList[index]);
      if (msgInfo != undefined) {
        result.push(msgInfo);
      }
    }
    // 修改接受消息标志，如果有新消息则更新接受消息标志，否则列表滚动到底部
    this.chatInfo?.setReceiveMsg(true, result.map((receiveMsg: NIMMessageInfo) => { return receiveMsg.message}));
    this.toHandleQueryMessage(result, messageList)
    this.loadQuickComments(result)
    this.hasLoadData = true
    return result;
  }

  async loadMessageListWithAnchor(anchorMsg: NIMMessageInfo,
    preserveHistoryOnReceive: boolean = false,
    scrollIndexAlignStart: boolean = false): Promise<NIMMessageInfo[]> {
    if (preserveHistoryOnReceive) {
      // Keep incoming messages outside the anchored history window.
      this.hasNew = true
    }
    let errorCount = 0
    let result: NIMMessageInfo[] = [];
    const messageBeforList: V2NIMMessage[] = await ChatRepo.getMessageList({
      'conversationId': this.conversationId,
      'anchorMessage': anchorMsg.message,
      'limit': ChatConst.chatMessagePageSize,
      'direction': V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_DESC
    }).catch((err: BusinessError) => {
      errorCount++
      return []
    })
    const messageAfterList: V2NIMMessage[] = await ChatRepo.getMessageList({
      'conversationId': this.conversationId,
      'anchorMessage': anchorMsg.message,
      'limit': ChatConst.chatMessagePageSize,
      'direction': V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
    }).catch((err: BusinessError) => {
      errorCount++
      return []
    })
    if (errorCount > 1) {
      this.appendPendingReceivedMessages(result)
      return result
    }
    // clear
    this.resetQuickCommentQueryState()
    this.chatInfo?.cleanMessage()

    // push before message
    if (messageBeforList.length > 0) {
      for (let index = messageBeforList.length - 1; index >= 0; index--) {
        let msgInfo = this.chatInfo?.pushMessage(messageBeforList[index])
        if (msgInfo != undefined) {
          result.push(msgInfo);
        }
      }
    }

    // push current message
    const currentMsgInfo = this.chatInfo?.pushMessage(anchorMsg.message)
    if (currentMsgInfo != undefined) {
      result.push(currentMsgInfo);
      // 设置 anchor 高亮状态，用于 UI 显示高亮动画
      // currentMsgInfo.isAnchorHighlight = true // 测试使用
    }

    // push after message
    const anchorIndex = (this.chatInfo?.msgList.totalCount() || 1) - 1
    if (messageAfterList.length > 0) {
      for (let index = 0; index < messageAfterList.length; index++) {
        let msgInfo = this.chatInfo?.pushMessage(messageAfterList[index])
        if (msgInfo != undefined) {
          result.push(msgInfo);
        }
      }
    }
    this.appendPendingReceivedMessages(result)
    if (preserveHistoryOnReceive || messageAfterList.length > ChatConst.chatMessagePageSize - 5 || this.networkBroken) {
      this.hasNew = true
    } else if (!this.networkBroken) {
      this.hasNew = false;
    }
    // // 修改接受消息标志，如果有新消息则更新接受消息标志，否则列表滚动到底部
    // this.chatInfo?.setReceiveMsg(true)
    this.toHandleQueryMessage(result, messageAfterList)
    this.loadQuickComments(result)
    if (anchorIndex >= 0) {
      this.chatInfo?.setScrollIndex(anchorIndex, scrollIndexAlignStart)
    }
    this.hasLoadData = true
    return result;
  }

  private appendPendingReceivedMessages(result: NIMMessageInfo[]): void {
    const pendingMessages = this.pendingReceivedMessages
    this.pendingReceivedMessages = []
    pendingMessages.forEach((message: V2NIMMessage): void => {
      if (message.conversationId !== this.conversationId || this.chatInfo?.getMessage(message.messageClientId) !== undefined) {
        return
      }
      const messageInfo = this.chatInfo?.pushMessage(message)
      if (messageInfo !== undefined) {
        result.push(messageInfo)
      }
    })
  }

  /**
   * 消息发送成功后的钩子方法，子类可以重写以实现自定义逻辑
   * @param message 发送成功的消息
   */
  toHandleSendMessageSuccess(message: V2NIMMessage): void {
    // 默认实现为空，子类可以重写
  }

  // 处理接受消息，用于子类进行特殊业务处理
  toHandleReceiveMessage(messages: NIMMessageInfo[]) {

  }

  // 处理查询消息，用于子类进行特殊业务处理
  toHandleQueryMessage(messages: NIMMessageInfo[], originMsg: V2NIMMessage[]) {

  }

  toHandleDataSyncFinished() {

  }

  // 是否有更多消息，分页加载
  canLoadMore(): boolean {
    return this.hasMore && !this.isLoading;
  }

  // 是否有更多新消息加载，分页加载
  canLoadNext(end: number): boolean {
    return this.hasNew && !this.isLoading && this.chatInfo !== undefined &&
      this.chatInfo.msgList.totalCount() - end < ChatConst.chatMessagePageSize
  }

  // 拉取历史消息
  async getMoreMessageList(): Promise<NIMMessageInfo[]> {
    let anchorMsg = this.chatInfo?.msgList.getData(0)
    if (this.isLoading || anchorMsg == undefined) {
      return []
    }
    this.isLoading = true;
    let result: NIMMessageInfo[] = [];
    await ChatRepo.getMessageList({
      'anchorMessage': anchorMsg.message,
      'conversationId': this.conversationId,
      'limit': ChatConst.chatMessagePageSize,
      'direction': this.msgDirection,
    }).then((messageList: V2NIMMessage[]) => {
      // SDK 返回消息不太稳定，所以按照更小的值判断是否有下一页
      if (messageList.length >= ChatConst.chatMessagePageSize - 5 || this.networkBroken) {
        this.hasMore = true
      } else {
        this.hasMore = false
      }
      if (this.chatInfo) {
        result = this.chatInfo.unshiftMessage(messageList)
      }
      this.toHandleQueryMessage(result, messageList)
      this.loadVisibleQuickComments()
      this.isLoading = false
    }).catch((err: BusinessError) => {
      this.isLoading = false
      if (this.networkBroken) {
        this.hasMore = true
      }
    })
    return result
  }

  // 拉取历史消息
  async getNewMessageList(): Promise<NIMMessageInfo[]> {
    if (this.isLoading || !this.hasNew) {
      return []
    }
    let anchorMsg = this.chatInfo?.msgList.getData(this.chatInfo?.msgList.totalCount() - 1)
    if (anchorMsg == undefined) {
      return []
    }
    this.isLoading = true;
    let result: NIMMessageInfo[] = [];
    await ChatRepo.getMessageList({
      'anchorMessage': anchorMsg.message,
      'conversationId': this.conversationId,
      'limit': ChatConst.chatMessagePageSize,
      'direction': V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC,
    }).then((messageList: V2NIMMessage[]) => {
      // SDK 返回消息不太稳定，所以按照更小的值判断是否有下一页
      if (messageList.length >= ChatConst.chatMessagePageSize - 10 || this.networkBroken) {
        this.hasNew = true
      } else {
        this.hasNew = false
      }
      Logger.debug('ChatKitUI', 'netease getNewMessageList,lenght:', messageList.length, 'hasNew:', this.hasNew)

      if (this.chatInfo) {
        for (let index = 0; index < messageList.length; index++) {
          let msgInfo = this.chatInfo.pushMessage(messageList[index])
          result.push(msgInfo)
        }
      }
      this.toHandleQueryMessage(result, messageList)
      this.loadVisibleQuickComments()
      this.isLoading = false
    }).catch((err: BusinessError) => {
      this.isLoading = false
      if (this.networkBroken) {
        this.hasNew = true
      } else {
        this.hasNew = false
      }
    })
    return result
  }

  // 拉取PIN信息
  getPinList() {
    ChatRepo.getPinnedMessageList(this.conversationId).then((pinMessageList) => {
      this.chatInfo?.resetPinMessage(pinMessageList)
      this.needScrollToBottom = true
    })
  }

  // 删除消息
  deleteMessage(messages: NIMMessageInfo[]) {
    for (const message of messages) {
      ChatRepo.deleteMessage(message.message, undefined, false).then(() => {
        this.removeReplyInfo(message.message.messageClientId)
      }).catch((err: BusinessError) => {
        ErrorUtils.handleErrorToast(err.code)
      });
    }
  }

  // 批量删除消息
  deleteMessageList(messages: NIMMessageInfo[]) {
    let msgList: V2NIMMessage[] = []
    messages.forEach((msg, index, messages) => {
      msgList.push(msg.message)
    })

    ChatRepo.deleteMessages(msgList, undefined, false).then(() => {
      messages.forEach((msg) => {
        this.removeReplyInfo(msg.message.messageClientId)
      })
    }).catch((err: BusinessError) => {
      ErrorUtils.handleErrorToast(err.code)
    });
  }

  // 撤回消息
  revokeMessage(msg: NIMMessageInfo) {
    ChatRepo.revokeMessage(msg.message).then(() => {
      if (msg.isPinMsg && msg.pinInfo) {
        ChatRepo.unpinMessage(msg.pinInfo?.messageRefer)
      }
      this.removeReplyInfo(msg.message.messageClientId)
    }).catch((err: BusinessError) => {
      ErrorUtils.handleErrorToast(err.code)
      Logger.error('ChatKitUI', `netease Invoke startAbility failed, code is ${err.code}, message is ${err.message}`);
    });
  }

  /// 移除被回复信息
  removeReplyInfo(invalidMessageClientId: string) {
    const invalidMessage = this.chatInfo?.getMessage(invalidMessageClientId)
    if (invalidMessage) {
      const invalidIndex = this.chatInfo?.msgList.getMessageList().indexOf(invalidMessage)
      if (invalidIndex) {
        for (let index = invalidIndex; index < (this.chatInfo?.msgList.totalCount() ?? invalidIndex); index++) {
          let message = this.chatInfo?.msgList.getMessageList()[index]
          if (message && message.replyMsg?.message.messageClientId === invalidMessage.message.messageClientId) {
            message.replyMsg = undefined
          }
        }
      }
    }
  }

  // 收藏消息
  collectionMessage(msg: NIMMessageInfo) {
    if (ErrorUtils.checkNetworkAndToast()) {
      let collectionDic: Record<string, Object> = {}
      let message = msg.message
      clearForwardAtMark(message)
      const messageString = ChatKitClient.nim.messageConverter.messageSerialization(message)
      if (messageString) {
        collectionDic['message'] = messageString
      }

      collectionDic['conversationName'] = this.chatInfo?.conversationName ?? ''
      collectionDic['senderName'] = this.chatInfo?.getChatUserShowName(message) ?? ''
      collectionDic['avatar'] = this.chatInfo?.getChatUserAvatarUrl(message) ?? ''

      const collectionData = JSON.stringify(collectionDic)

      ChatRepo.addCollection({
        collectionType: message.messageType.valueOf() + collectionTypeOffset,
        collectionData: collectionData,
        uniqueId: message.messageServerId
      }).catch((err: BusinessError) => {
        ErrorUtils.handleErrorToast(err.code)
      }).finally(() => {
        NECommonUtils.showToast($r('app.string.chat_collection_success'))
      })
    }
  }

  // PIN消息
  pinMessage(msg: NIMMessageInfo) {
    if (ErrorUtils.checkNetworkAndToast()) {
      ChatRepo.pinMessage(msg.message).catch((err: BusinessError) => {
        if (err.code == V2NIMErrorCode.V2NIM_ERROR_CODE_PIN_ALREADY_EXIST) {
          return
        }
        ErrorUtils.handleErrorToast(err.code)
      })
    }
  }

  unpinMessage(msg: NIMMessageInfo) {
    if (ErrorUtils.checkNetworkAndToast()) {
      if (msg.isPinMsg) {
        if (msg.pinInfo?.messageRefer !== undefined) {
          ChatRepo.unpinMessage(msg.pinInfo?.messageRefer).catch((err: BusinessError) => {
            if (err.code == V2NIMErrorCode.V2NIM_ERROR_CODE_PIN_NOT_EXIST) {
              return
            }
            ErrorUtils.handleErrorToast(err.code)
          })
        }
      }
    }
  }

  @Computed
  get shouldShowLastReadPosition(): boolean {
    return this.enableLastReadPosition() &&
      canShowLastReadPosition(this.lastReadPositionStatus, this.lastReadUnreadCount,
        this.lastReadVisibleStateReady)
  }

  updateLastReadPosition(topVisibleIndex: number): void {
    if (!this.enableLastReadPosition() || topVisibleIndex < 0 || this.lastReadTargetMessageCreateTime <= 0) {
      return
    }
    const topVisibleMessage = this.chatInfo?.msgList.getData(topVisibleIndex)
    if (!topVisibleMessage) {
      return
    }
    this.lastReadVisibleStateReady = true
    const targetIndex = this.lastReadTargetMessageClientId.length > 0 ?
      this.chatInfo?.msgList.searchPosition(this.lastReadTargetMessageClientId) ?? -1 : -1
    const targetAtOrBelowTop = targetIndex >= 0 ? targetIndex >= topVisibleIndex : undefined
    this.lastReadPositionStatus = updateLastReadPositionStatus(
      this.lastReadPositionStatus,
      this.lastReadTargetMessageCreateTime,
      topVisibleMessage.getCreateTime(),
      targetAtOrBelowTop
    )
  }

  @Computed
  get isLastReadPositionLocating(): boolean {
    return this.lastReadPositionStatus === LastReadPositionStatus.LOCATING
  }

  async jumpToLastReadPosition(): Promise<boolean> {
    if (!this.enableLastReadPosition() || this.lastReadPositionStatus !== LastReadPositionStatus.VISIBLE) {
      return false
    }
    const lifecycleVersion = this.conversationLifecycleVersion
    this.lastReadPositionStatus = startLastReadPositionJump(this.lastReadPositionStatus)
    // Keep incoming messages outside the anchored history window while locating.
    this.hasNew = true
    try {
      const queryResult = await ChatRepo.getMessageListEx(
        buildLastReadMessageQueryOption(this.conversationId, this.lastReadTime)
      )
      if (!this.isCurrentConversationLifecycle(lifecycleVersion)) {
        return false
      }
      const targetMessage = queryResult.messages.find((message: V2NIMMessage) => {
        return message.createTime > this.lastReadTime
      })
      if (!targetMessage) {
        this.lastReadPositionStatus = finishLastReadPositionJump(this.lastReadPositionStatus, false)
        this.hasNew = false
        this.pendingReceivedMessages = []
        NECommonUtils.showToast($r('app.string.chat_last_read_position_load_failed'))
        return false
      }
      Logger.debug('ChatKitUI', '[LastReadPosition] target message found', this.conversationId,
        targetMessage.messageClientId, targetMessage.createTime)

      const loadedMessages = await this.loadMessageListWithAnchor(new NIMMessageInfo(targetMessage), true, true)
      if (!this.isCurrentConversationLifecycle(lifecycleVersion)) {
        return false
      }
      const success = loadedMessages.length > 0
      this.lastReadPositionStatus = finishLastReadPositionJump(this.lastReadPositionStatus, success)
      if (!success) {
        this.hasNew = false
        NECommonUtils.showToast($r('app.string.chat_last_read_position_load_failed'))
      }
      return success
    } catch (err) {
      if (this.isCurrentConversationLifecycle(lifecycleVersion)) {
        this.lastReadPositionStatus = finishLastReadPositionJump(this.lastReadPositionStatus, false)
        this.hasNew = false
        this.pendingReceivedMessages = []
        Logger.error('ChatKitUI', '[LastReadPosition] jump failed', `${err}`)
        NECommonUtils.showToast($r('app.string.chat_last_read_position_load_failed'))
      }
      return false
    }
  }

  private async clearUnread(): Promise<void> {
    try {
      await this.conversationStrategy.clearUnreadCountById(this.conversationId)
      Logger.debug('ChatKitUI', '[LastReadPosition] clear completed', this.conversationId,
        this.useLocalConversation)
    } catch (err) {
      Logger.error('ChatKitUI', '[LastReadPosition] clear unread failed', `${err}`)
      return
    }

  }

  // 清理未读数并推进会话已读时间。调用方无需处理异常。
  clearUnreadCount(): void {
    this.conversationReadReadyPromise.then(async () => {
      await this.clearUnread()
    }).catch((err: BusinessError) => {
      Logger.error('ChatKitUI', '[LastReadPosition] clear unread queue failed', `${err}`)
    })
  }

  /**
   * 消息发送之前调用，用于配置消息通用参数
   * @param params 原始发送参数（如调用方设置的 pushConfig 等）
   * @returns 合并后的 V2NIMSendMessageParams，beforeSendMessage 的配置优先；如果没有任何配置则返回 undefined
   */
  beforeSendMessage(params?: V2NIMSendMessageParams): V2NIMSendMessageParams | undefined {
    return buildSendMessageParams(params)
  }

  // 发送消息并设置发送进度
  sendMessageAndSetProgress(message: V2NIMMessage, params?: V2NIMSendMessageParams) {
    this.sendMessage(message, params, (percentage: number) => {
      let msgInfo = this.chatInfo?.getMessage(message.messageClientId)
      if (msgInfo) {
        let progress = percentage * 100
        msgInfo.setDownloadProgress(progress)
        if (progress >= 100) {
          msgInfo.setDownloadProgress(-1)
        }
      }
    });
  }

  // 发送文本消息
  async sendTextMessage(text: string, replyMsg?: NIMMessageInfo, aitModel?: AitModel, pushList?: string[],
    aiAgentAccountId?: string) {
    const message = ChatRepo.createTextMessage(text)
    //设置Ait
    if (aitModel && aitModel.aitBlocks.size > 0) {
      let extensionMap: YxAitMsg = {
        yxAitMsg: aitModel.aitBlocks
      }
      let extension = JSON.stringify(instanceToPlain(extensionMap))
      message.serverExtension = extension
    }

    //设置推送
    let params: V2NIMSendMessageParams | undefined = undefined
    if (pushList) {
      params = {
        pushConfig: {
          forcePush: true,
          forcePushAccountIds: pushList.length >= 0 ? pushList : undefined
        }
      }
    }

    params = this.buildAIConfigForReplyContext(message, params, aiAgentAccountId, replyMsg) ??
      this.appendAIConfig(message, params, aiAgentAccountId)

    // 回复
    if (replyMsg) {
      this.replyMessage(message, replyMsg.message, params)
      return
    }
    this.sendMessage(message, params)
  }

  // 发送位置消息
  async sendLocationMessage(data: sceneMap.LocationChoosingResult) {
    const message = ChatRepo.createLocationMessage(data.location.latitude, data.location.longitude, data.address)
    message.text = data.name
    const params = this.buildAIConfigForCurrentConversation(message)
    this.sendMessage(message, params)
  }

  /**
   * 发送富文本消息（换行消息）
   * @param title 标题
   * @param body 正文
   * @param replyMsg 回复消息（可选）
   * @param aitModel @ 信息（可选）
   * @param pushList 推送列表（可选）
   */
  async sendMultiLineMessage(title: string, body: string, replyMsg?: NIMMessageInfo, aitModel?: AitModel,
    pushList?: string[], aiAgentAccountId?: string) {
    const normalizedTitle = normalizeMultiLineTitle(title)
    const attachment = createMultiLineAttachment(normalizedTitle, body)
    // 将标题和正文拼接为 text 字段，用于 FTS 全文搜索
    // 格式：标题在前，正文在后，中间用空格分隔
    const searchText = `${normalizedTitle}\n${body}`
    const message = ChatRepo.createCustomMessage(searchText, attachment)

    // 设置 Ait
    if (aitModel && aitModel.aitBlocks.size > 0) {
      let extensionMap: YxAitMsg = {
        yxAitMsg: aitModel.aitBlocks
      }
      let extension = JSON.stringify(instanceToPlain(extensionMap))
      message.serverExtension = extension
    }

    // 设置推送
    let params: V2NIMSendMessageParams | undefined = undefined
    if (pushList) {
      params = {
        pushConfig: {
          forcePush: true,
          forcePushAccountIds: pushList.length >= 0 ? pushList : undefined
        }
      }
    }

    params = this.buildAIConfigForReplyContext(message, params, aiAgentAccountId, replyMsg, getAIMessageContent(message)) ??
      this.appendAIConfig(message, params, aiAgentAccountId, getAIMessageContent(message))

    // 回复
    if (replyMsg) {
      this.replyMessage(message, replyMsg.message, params)
      return
    }

    this.sendMessage(message, params)
  }

  private appendAIConfig(message: V2NIMMessage, params?: V2NIMSendMessageParams,
    aiAgentAccountId?: string, content?: string, includeContext: boolean = true,
    resolveContent: boolean = true): V2NIMSendMessageParams | undefined {
    const accountId = aiAgentAccountId ?? this.targetId
    const aiUser: V2NIMAIUser | undefined = NEAIUserCache.getAIUser(accountId)
    if (!aiUser) {
      return params
    }

    const aiParams: V2NIMMessageAIConfigParams = {
      accountId: aiUser.accountId,
      aiStream: IMKitConfigCenter.enableAIStream
    }
    const aiContent = resolveContent ? resolveAIMessageContentForSend(message, content) : content
    if (aiContent !== undefined) {
      aiParams.content = {
        msg: aiContent,
        type: 0
      }
    }
    if (includeContext && aiContent !== undefined) {
      const contextMessages = buildAIContextMessages(
        this.chatInfo?.msgList.getMessageList().map((messageInfo: NIMMessageInfo) => messageInfo.message) ?? []
      )
      if (contextMessages.length > 0) {
        aiParams.messages = contextMessages
      }
    }
    if (!params) {
      params = {}
    }
    params.aiConfig = aiParams
    return params
  }

  private buildAIConfigForReplyContext(message: V2NIMMessage, params: V2NIMSendMessageParams | undefined,
    aiAgentAccountId: string | undefined, replyMsg: NIMMessageInfo | undefined,
    content?: string): V2NIMSendMessageParams | undefined {
    if (!replyMsg) {
      return undefined
    }
    const result = this.appendAIConfig(message, params, aiAgentAccountId, content, false)
    const replyContext = buildAIReplyContextMessage(replyMsg.message)
    if (result?.aiConfig && replyContext) {
      result.aiConfig.messages = [replyContext]
    }
    return result
  }

  private isAIConversationByConversationId(conversationId: string): boolean {
    const targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    return NEAIUserCache.getAIUser(targetId) !== undefined
  }

  /**
   * 发送图片消息
   * @param uri 本地图片地址
   */
  async sendImageMessage(uri: string) {
    try {
      if (uri.length > 0) {
        let fileType = ''
        const subStrings = uri.split('.');
        if (subStrings.length > 0) {
          fileType = subStrings[subStrings.length - 1];
        }
        // 将文件 拷贝到 临时目录
        const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
        // （以时间戳）生成一个新的文件名
        const fileName = Date.now() + '.' + fileType
        // 通过缓存路径+文件名 拼接出完整的路径
        let fileDir = DeviceUtils.rootDirPath + '/temp/'
        const copyFilePath = fileDir + fileName
        if (!fs.accessSync(fileDir)) {
          await fs.mkdir(fileDir)
        }
        await fs.copyFile(file.fd, copyFilePath)
        const imageSource = image.createImageSource(file.fd);
        let imageInfo = imageSource.getImageInfoSync()
        const message = await ChatRepo.createImageMessage(copyFilePath, file.name, undefined, imageInfo?.size.width,
          imageInfo?.size.height);
        this.sendMessageAndSetProgress(message, this.buildAIConfigForCurrentConversation(message))

        await fs.close(file)
      }
    } catch (err) {
      Logger.info('ChatKitUI', 'net ease send image error', err);
    }
  }

  /**
   * 发送应用资源中的 Sticker 图片消息
   */
  async sendImageResourceMessage(resource: Resource, fileName: string): Promise<void> {
    let file: fs.File | undefined = undefined
    let filePath: string = ''
    let messageCreated: boolean = false
    try {
      const context = getContext(this)
      const data = await context.resourceManager.getMediaContent(resource)
      const imageBuffer = toExactArrayBuffer(data)
      const fileDir = DeviceUtils.rootDirPath + '/temp/'
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      const tempFileName = buildStickerTempFileName(fileName)
      filePath = fileDir + tempFileName
      file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      writeStickerBufferSync(file.fd, imageBuffer, (fd: number, buffer: ArrayBuffer): number => {
        return fs.writeSync(fd, buffer)
      })
      fs.closeSync(file)
      file = undefined

      const imageSource = image.createImageSource(imageBuffer)
      let imageInfo: image.ImageInfo
      try {
        imageInfo = imageSource.getImageInfoSync()
      } finally {
        await imageSource.release()
      }
      const message = await ChatRepo.createImageMessage(filePath, fileName, undefined, imageInfo?.size.width,
        imageInfo?.size.height)
      messageCreated = true
      this.sendMessageAndSetProgress(message, this.buildAIConfigForCurrentConversation(message))
    } catch (err) {
      Logger.error('ChatKitUI', 'net ease send sticker image error', err)
      try {
        if (!messageCreated && filePath.length > 0 && fs.accessSync(filePath)) {
          fs.unlinkSync(filePath)
        }
      } catch (cleanupErr) {
        Logger.error('ChatKitUI', 'net ease cleanup sticker image error', cleanupErr)
      }
    } finally {
      if (file !== undefined) {
        fs.closeSync(file)
      }
    }
  }

  /**
   * 发送视频消息
   * @param uri 本地视频地址
   * @param duration 视频时长
   * @param width 视频宽度
   * @param height 视频高度
   */
  async sendVideoMessage(uri: string, duration?: number, width?: number, height?: number, thumbnail?: PixelMap) {
    try {
      let fileType = ''
      const subStrings = uri.split('.');
      if (subStrings.length > 0) {
        fileType = subStrings[subStrings.length - 1];
      }
      // 将文件 拷贝到 临时目录
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      // （以时间戳）生成一个新的文件名
      const fileName = Date.now() + '.' + fileType
      // 通过缓存路径+文件名 拼接出完整的路径
      let fileDir = DeviceUtils.rootDirPath + '/temp/'
      const copyFilePath = fileDir + fileName
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      await fs.copyFile(file.fd, copyFilePath)
      const message = await ChatRepo.createVideoMessage(copyFilePath, file.name, undefined, duration, width, height);
      this.sendMessageAndSetProgress(message, this.buildAIConfigForCurrentConversation(message))

      await fs.close(file)
    } catch (err) {
      Logger.info('ChatKitUI', 'net ease send video error', err);
    }
  }

  /**
   * 发送文件消息
   * @param uri 文件地址
   */
  async sendFileMessage(uri: string) {
    try {
      let fileType = ''
      const subStrings = uri.split('.');
      if (subStrings.length > 0) {
        fileType = subStrings[subStrings.length - 1];
      }
      // 将文件 拷贝到 临时目录
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      // （以时间戳）生成一个新的文件名
      const fileName = Date.now() + '.' + fileType
      // 通过缓存路径+文件名 拼接出完整的路径
      let fileDir = DeviceUtils.rootDirPath + '/temp/'
      const copyFilePath = fileDir + fileName
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      await fs.copyFile(file.fd, copyFilePath)
      const message = await ChatRepo.createFileMessage(copyFilePath, file.name);
      const params = this.buildAIConfigForCurrentConversation(message)
      this.sendMessage(message, params, (percentage: number) => {
        let msgInfo = this.chatInfo?.getMessage(message.messageClientId)
        if (msgInfo !== undefined) {
          let progress = percentage * 100
          msgInfo.setDownloadProgress(progress)
          if (progress >= 100) {
            msgInfo.setDownloadProgress(-1)
          }
        }
      });

      await fs.close(file)
    } catch (err) {
      Logger.info('ChatKitUI', 'net ease send file error', err);
    }
  }

  /**
   * 发送语音消息
   * @param uri
   * @param duration 单位 s
   */
  async sendAudioMessage(uri: string, duration: number) {
    try {
      const message = await ChatRepo.createAudioMessage(uri, undefined, undefined, duration * 1000);
      const params = this.buildAIConfigForCurrentConversation(message)
      this.sendMessage(message, params)
    } catch (err) {
      Logger.error('ChatKitUI', 'net ease send audio message error', err.code, err.message)
    }
  }

  /**
   * 发送消息
   * @param msg 消息
   * @param params 消息配置参数
   * @param progress 消息发送进度
   */
  async sendMessage(msg: V2NIMMessage, params?: V2NIMSendMessageParams, progress?: (percentage: number) => void): Promise<void> {
    try {
      const mergedParams = this.beforeSendMessage(params)
      const result: V2NIMSendMessageResult | undefined = await ChatRepo.sendMessage(msg, this.conversationId!, mergedParams, progress)

      // 命中反垃圾的需要进行更新消息 & 添加反垃圾 TIP
      if (result && result.antispamResult) {
        this.modifyAndSendTip(result)
      }

      // AI 消息发送成功后提示
      if (result && result.message.aiConfig) {
        NECommonUtils.showToast($r('app.string.chat_ai_message_progressing'))
      }

    } catch (err) {
      Logger.error('ChatKitUI', 'netease send message error', err.code, err.message);
      sendMessageFailedTips(msg, err, this.conversationId!)
    }
  }

  /**
   * 回复消息
   * @param msg 消息
   * @param replyMsg 被回复的消息
   * @param params 消息配置参数
   * @param progress 消息发送进度
   */
  async replyMessage(msg: V2NIMMessage, replyMsg: V2NIMMessage, params?: V2NIMSendMessageParams,
    progress?: (percentage: number) => void) {
    const mergedParams = this.beforeSendMessage(params)
    ChatRepo.replyMessage(msg, replyMsg, mergedParams, progress)
      .catch((err: BusinessError) => {
        Logger.error('ChatKitUI', 'net ease reply message error', err.code, err.message);
        sendMessageFailedTips(msg, err, this.conversationId!)
      })
  }

  /**
   * 停止 AI 流式消息输出
   *
   * @param messageInfo 需要停止的 AI 消息
   */
  public async stopAIStream(messageInfo: NIMMessageInfo): Promise<void> {
    if (!messageInfo.canOperateAIResponse()) {
      return
    }
    const params: V2NIMMessageAIStreamStopParams = {
      operationType: V2NIMMessageAIStreamStopOpType.V2NIM_MESSAGE_AI_STREAM_STOP_OP_DEFAULT
    }
    try {
      await ChatRepo.stopAIStreamMessage(messageInfo.message, params)
    } catch (err) {
      Logger.error('ChatKitUI', 'netease stopAIStream error', err.code, err.message)
      NECommonUtils.showToast($r('app.string.chat_ai_search_error'))
    }
  }

  /**
   * 重新生成 AI 消息回答
   *
   * @param messageInfo 需要重新生成的 AI 消息
   */
  public async regenAIMessage(messageInfo: NIMMessageInfo): Promise<void> {
    if (!messageInfo.canOperateAIResponse()) {
      return
    }
    const params: V2NIMMessageAIRegenParams = {
      operationType: V2NIMMessageAIRegenOpType.V2NIM_MESSAGE_AI_REGEN_OP_NEW
    }
    try {
      await ChatRepo.regenAIMessage(messageInfo.message, params)
      NECommonUtils.showToast($r('app.string.chat_ai_message_progressing'))
    } catch (err) {
      Logger.error('ChatKitUI', 'netease regenAIMessage error', err.code, err.message)
      if (err.code === V2NIMErrorMap.V2NIM_ERROR_CODE_MESSAGE_NOT_EXIST.code) {
        NECommonUtils.showToast($r('app.string.chat_message_removed_tip'))
      } else {
        NECommonUtils.showToast($r('app.string.chat_ai_search_error'))
      }
    }
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
    const mergedParams = this.beforeSendMessage(params)
    ChatRepo.sendMessage(msg, conversationId, mergedParams, progress)
      .catch((err: BusinessError) => {
        Logger.error('ChatKitUI', 'net ease send message error', err.code, err.message);
        sendMessageFailedTips(msg, err, conversationId)
      })
  }

  private buildAIConfigForConversation(message: V2NIMMessage, conversationId: string, content?: string,
    includeContext: boolean = false, resolveContent: boolean = true): V2NIMSendMessageParams | undefined {
    if (!this.isAIConversationByConversationId(conversationId)) {
      return undefined
    }
    const targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    return this.appendAIConfig(message, undefined, targetId, content, includeContext, resolveContent)
  }

  private buildAIConfigForCurrentConversation(message: V2NIMMessage,
    includeContext: boolean = true): V2NIMSendMessageParams | undefined {
    return this.buildAIConfigForConversation(message, this.conversationId, getAIMessageContent(message), includeContext)
  }

  // 消息附件下载
  async downloadAttachment(msg: NIMMessageInfo, path: string) {
    if (msg.message.attachment as V2NIMMessageFileAttachment) {
      let fileAttachment = msg.message.attachment as V2NIMMessageFileAttachment;
      if (fileAttachment.url !== undefined) {
        msg.setDownloadProgress(1)
        try {
          await StorageRepo.downloadFile(fileAttachment.url, path, (progress: number) => {
            if (progress < 100) {
              this.chatInfo?.downloadProgressMap.set(msg.message.messageClientId, progress)
              msg.setDownloadProgress(progress)
            } else {
              if (progress == 100) {
                msg.setDownloadProgress(100)
              }
              msg.setDownloadProgress(-1)
              this.chatInfo?.downloadProgressMap.delete(msg.message.messageClientId)
            }
          }
          )
        } catch (err) {
          Logger.info('ChatKitUI', 'netease downloadAttachment', err)
          msg.setDownloadProgress(-1)
        }
      }
    }
  }

  /**
   * 【逐条转发】将多个消息转发到多个会话中，并将留言发送到多个会话中
   * @param messages 待转发的消息
   * @param conversationIds 待转发的会话
   * @param leaveText 留言
   */
  forwardMessage(messages: V2NIMMessage[], conversationIds: ConversationSelectModel[],
    leaveText: string | undefined) {

    if (ErrorUtils.checkNetworkAndToast()) {
      conversationIds.forEach((conversation) => {
        messages.forEach((message) => {
          const forwardMsg = ChatRepo.createForwardMessage(message)
          try {
            if (forwardMsg && conversation.conversationId) {
              clearForwardAtMark(forwardMsg)
              const aiParams = this.buildAIConfigForConversation(
                forwardMsg,
                conversation.conversationId,
                resolveAIMessageContentForForward(forwardMsg),
                false,
                false
              )
              this.sendForwardMessage(forwardMsg, conversation.conversationId, aiParams)
            }
          } catch (err) {
            Logger.error('ChatKitUI', err)
          }
        })

        // 发送留言
        if (leaveText && leaveText.length > 0) {
          const leaveMsg = ChatRepo.createTextMessage(leaveText)
          if (leaveMsg && conversation.conversationId) {
            setTimeout(() => {
              const aiParams = this.buildAIConfigForConversation(leaveMsg, conversation.conversationId!, leaveText, false,
                false)
              const mergedParams = this.beforeSendMessage(aiParams)
              ChatRepo.sendMessage(leaveMsg, conversation.conversationId!, mergedParams)
                .catch((err: BusinessError) => {
                  Logger.error('ChatKitUI', 'net ease send message error', err.code, err.message);
                  sendMessageFailedTips(leaveMsg, err, conversation.conversationId!)
                })
            }, 200)
          }
        }
      })
    }
  }

  /**
   * 将多个消息合并为一条自定义消息
   * @param messages 待合并的消息
   * @param depth 合并转发消息的深度
   */
  async mergeForwardMessage(messages: NIMMessageInfo[], depth: number): Promise<V2NIMMessage | undefined> {
    // 校验网络
    if (ErrorUtils.checkNetworkAndToast()) {
      // 排序（发送时间正序）
      let sortMessages = messages.sort((m1, m2) => {
        if (m1.message.createTime < m2.message.createTime) {
          return -1
        }
        if (m1.message.createTime > m2.message.createTime) {
          return 1
        }
        return 0
      })

      let rawMessages = sortMessages.map(msg => msg.message)
      if (this.chatInfo) {
        try {
          return await createForwardMessageListFileDetail(rawMessages, this.chatInfo, depth)
        } catch (err) {
          Logger.error('ChatKitUI', err)
        }
      }
    }

    return undefined
  }

  resendMessage(msgInfo: NIMMessageInfo) {
    //设置推送
    let params: V2NIMSendMessageParams | undefined = undefined
    let pushList = msgInfo.message.pushConfig?.forcePushAccountIds
    if (pushList) {
      params = {
        pushConfig: {
          forcePush: true,
          forcePushAccountIds: pushList.length >= 0 ? pushList : undefined
        }
      }
    }
    if (msgInfo.isReplyMsg && msgInfo.replyMsg && msgInfo.replyMsg.message) {
      this.replyMessage(msgInfo.message,msgInfo.replyMsg?.message,params)
    }else {
      this.sendMessage(msgInfo.message,params)
    }
  }

  // 多选数据，添加新的选中消息
  addSelectMessage(msg: NIMMessageInfo) {
    if (!msg.canOperateInMultiSelect()) {
      return
    }
    this.selectMsgMap.set(msg.getMessageClientId(), msg)
    this.chatInfo?.getMessage(msg.getMessageClientId())?.setSelected(true)
    this.selectMsgCount = this.selectMsgMap.size
  }

  // 多选数据，移除选中消息
  removeSelectMessage(msg: NIMMessageInfo) {
    this.selectMsgMap.delete(msg.getMessageClientId())
    this.chatInfo?.getMessage(msg.getMessageClientId())?.setSelected(false)
    this.selectMsgCount = this.selectMsgMap.size
  }

  // 多选数据，清空所有选中消息
  clearSelectMessage() {
    this.selectMsgMap.forEach((msg) => {
      this.chatInfo?.getMessage(msg.getMessageClientId())?.setSelected(false)
    })
    this.selectMsgMap.clear()
    this.selectMsgCount = this.selectMsgMap.size
  }

  // 获取多选数据
  getSelectMessageList(): NIMMessageInfo[] {
    return Array.from(this.selectMsgMap.values());
  }

  // 获取多选数据数量
  getSelectMessageSize(): number {
    return this.selectMsgMap.size;
  }

  isSelect(msgClientId: string) {
    let result = this.selectMsgMap.has(msgClientId)
    let msg = this.chatInfo?.getMessage(msgClientId)
    Logger.debug('ChatKitUI', 'netease isSelect', msgClientId, result, ',content:', msg?.message.text)
    return result
  }

  private async modifyAndSendTip(result: V2NIMSendMessageResult): Promise<void> {
    if (!result) {
      return; // ignore
    }
    // 是否命中反垃圾，并且开启反垃圾 TIP 提示
    if (result.antispamResult) {
      const getMsg: NIMMessageInfo | undefined = this.chatInfo?.msgMap.get(result.message.messageClientId)
      if (getMsg) {
        getMsg.isServerAntiSpam = true
        await this.modifyMessageLocalExtensionAntispam(getMsg.message)
      }

      if (IMKitConfigCenter.enableAntiSpamTipMessage) {
        this.sendAntispamTipMessage(result)
      }
    }
  }

  private sendAntispamTipMessage(result: V2NIMSendMessageResult): void {
    let label: number = 900; // unknown
    try {
      const antispamResultJSON: NIMEStrAnyObj | null = JSON.parse(result.antispamResult)
      if (!antispamResultJSON) {
        return; // skip
      }
      const extJSON: NIMEStrAnyObj | null = JSON.parse(antispamResultJSON.ext) as NIMEStrAnyObj
      if (!extJSON) {
        return; // skip
      }
      if (Array.isArray(extJSON) && extJSON.length > 0) {
        label = extJSON[0].antispam.label
      } else {
        label = extJSON.antispam.label
      }
    } catch (e) {
      // 如果还出错的话，就使用正则的方式找
      try {
        if (result.antispamResult) {
          // 去除字符串中的转义符 \
          const jsonResultReplace = result.antispamResult.replace(/\\/g, '');
          // 全局匹配所有label数字，取第一个
          const pattern = /"label":(\d+)/g;
          const matches = jsonResultReplace.matchAll(pattern);
          const matchList = Array.from(matches);
          if (matchList.length > 0) {
            const lastMatch = matchList[0];
            const matchedLabel = Number(lastMatch[1]);
            if (!isNaN(matchedLabel)) {
              label = matchedLabel;
            }
          }
        }
      } catch (e) {
        // 放弃，使用默认值
      }
    }

    Logger.error('ChatKitUI', 'netease send message antispam label', label)

    // 分类信息，100：色情，200：广告，260：广告法，300：暴恐，400：违禁，500：涉政，600：谩骂，700：灌水，900：其他，1100：涉价值观
    let labelResource: Resource = $r('app.string.chat_message_other_tip_label')
    switch (label) {
      case 100:
        labelResource = $r('app.string.chat_message_pornography_tip_label')
        break
      case 200:
        labelResource = $r('app.string.chat_message_ads_tip_label')
        break
      case 260:
        labelResource = $r('app.string.chat_message_ad_law_tip_label')
        break
      case 300:
        labelResource = $r('app.string.chat_message_terror_and_violence_law_tip_label')
        break
      case 400:
        labelResource = $r('app.string.chat_message_prohibited_tip_label')
        break
      case 500:
        labelResource = $r('app.string.chat_message_politics_tip_label')
        break
      case 600:
        labelResource = $r('app.string.chat_message_abusive_tip_label')
        break
      case 700:
        labelResource = $r('app.string.chat_message_spam_tip_label')
        break
      case 900:
        labelResource = $r('app.string.chat_message_other_tip_label')
        break
      case 1100:
        labelResource = $r('app.string.chat_message_values_issue_tip_label')
        break
      default:
        labelResource = $r('app.string.chat_message_other_tip_label')
        break
    }
    const tipLabel: string = getContext(this).resourceManager.getStringSync(labelResource.id)
    const tipFormat: string = getContext(this).resourceManager.getStringSync($r('app.string.chat_message_antispam_tip_format').id)
    // 把 %s 替换成 labelName
    const tipText: string = tipFormat.replace('%s', tipLabel)
    const antispamTipMessage: V2NIMMessage = ChatRepo.createTipsMessage(tipText)
    antispamTipMessage.createTime += 1 // 延迟 1ms
    ChatRepo.insertMessageToLocal(antispamTipMessage, result.message.conversationId)
  }

  private async modifyMessageLocalExtensionAntispam(message: V2NIMMessage): Promise<void> {
    // 修改本地扩展字段，加入 isServerAntispam 的描述
    const oldLocalExtension: string | undefined = message.localExtension
    // try catch 是不是 json，如果是 json 就加一个 isServerAntispam = true，如果不是的话，就放一个 { isServerAntispam: true } 进去覆盖
    let newLocalExtension: string = JSON.stringify({ isServerAntispam: true })
    try {
      const localExtensionJSON: NIMEStrAnyObj | null = JSON.parse(oldLocalExtension)
      if (localExtensionJSON) {
        localExtensionJSON.isServerAntispam = true
      }
      newLocalExtension = JSON.stringify(localExtensionJSON)
    } catch (e) {
      // use { isServerAntispam: true }
    }
    const updatedMessage: V2NIMMessage | undefined = await ChatRepo.updateMessageLocalExtension(message, newLocalExtension)

    if (!updatedMessage) {
      // 更新失败，不管
      return
    }
    this.chatInfo?.pushModifyMessage(updatedMessage)
  }

  /**
   * 语音转文字
   * @param msg 语音消息
   */
  async voiceToText(msg: NIMMessageInfo): Promise<void> {
    if (!msg || msg.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      return
    }

    // 如果正在加载中，不重复请求
    if (msg.voiceToTextLoading) {
      return
    }

    const audioAttachment = msg.message.attachment as V2NIMMessageAudioAttachment
    if (!audioAttachment) {
      return
    }

    // 检查语音时长是否超过 60 秒限制
    const duration = audioAttachment.duration ?? 0
    if (duration > 60000) {
      NECommonUtils.showToast($r('app.string.chat_message_voice_too_long'))
      return
    }

    // 构造语音转文字参数
    const params: V2NIMVoiceToTextParams = {
      duration: duration
    }

    // 优先使用 URL，其次使用本地路径
    if (audioAttachment.url && audioAttachment.url.length > 0) {
      params.voiceUrl = audioAttachment.url
    } else if (audioAttachment.path && audioAttachment.path.length > 0) {
      params.voicePath = audioAttachment.path
    } else {
      NECommonUtils.showToast($r('app.string.chat_message_voice_to_text_failed'))
      return
    }

    // 设置场景名
    if (audioAttachment.sceneName) {
      params.sceneName = audioAttachment.sceneName
    }

    // 设置加载状态
    msg.voiceToTextLoading = true

    try {
      const result = await ChatRepo.voiceToText(params)
      if (result && result.length > 0) {
        // 更新消息的转文字结果
        msg.voiceToText = result
        // 缓存转文字结果，用于从历史记录/标记列表回来时恢复
        this.chatInfo?.cacheVoiceToText(msg.message.messageClientId, result)
        
        // 转文字成功后，自动定位到该消息（让用户能看到完整的转文字结果）
        setTimeout(() => {
          this.setAnchorMessage(msg)
        }, 100)
      } else {
        NECommonUtils.showToast($r('app.string.chat_message_voice_to_text_failed'))
      }
      // SDK 返回空字符串时不做任何处理（实际场景中 SDK 会返回失败而非空字符串）
    } catch (err) {
      Logger.error('ChatKitUI', 'netease voiceToText error', err.code, err.message)
      // 网络错误显示特定提示
      if (err.code === V2NIMErrorCode.V2NIM_ERROR_CODE_ILLEGAL_STATE) {
        NECommonUtils.showToast($r('app.string.chat_network_error_tips'))
      } else {
        NECommonUtils.showToast($r('app.string.chat_message_voice_to_text_failed'))
      }
    } finally {
      // 无论成功失败，都结束加载状态
      msg.voiceToTextLoading = false
    }
  }

  /**
   * 销毁
   */
  onDestroy(): void {
    this.conversationLifecycleVersion++
    this.lastReadConfigVersion++
    if (ChatBaseViewModel.currentViewModel === this) {
      ChatBaseViewModel.currentViewModel = undefined
    }
    this.lastReadPositionStatus = LastReadPositionStatus.DISABLED
    this.lastReadVisibleStateReady = false
    ChatRepo.offReceiverMessage(this.onReceiveFun)
    ChatRepo.offReceiveMessagesModified(this.onModifyFun)
    ChatRepo.offSendMessage(this.onSendFun)
    ChatRepo.offDeleteMessage(this.onDeleteFun)
    ChatRepo.offRevokeMessage(this.onRevokeFun)
    ChatRepo.offMessagePinNotification(this.onPinFun)
    if (this.messageReactionListenerRegistered) {
      ChatRepo.offMessageQuickCommentNotification(this.onQuickCommentFun)
      this.messageReactionListenerRegistered = false
    }
    this.queriedQuickCommentMessageIds.clear()
    this.inFlightQuickCommentMessageIds.clear()
    this.quickCommentNotificationsDuringQuery.clear()
    this.quickCommentRetryConnectionVersions.clear()
    this.pendingQuickCommentKeys.clear()
    this.quickCommentQueryGeneration++
    this.loginEventDisposers.dispose()
    this.onLastReadTimeReady = undefined
    // 清理未读数
    this.clearUnreadCount()
    // 设置当前聊天账号
    if (ChatKitClient.getCurrentConversationId() === this.conversationId) {
      ChatKitClient.clearCurrentConversationId()
    }
  }
}


class StreamMessage {
  public message: V2NIMMessage
  public streamingArr: string[]
  public index: number
  public finish: boolean

  constructor(message: V2NIMMessage) {
    this.message = message
    this.streamingArr = []
    this.index = message.aiConfig?.aiStreamLastChunk?.index ?? 0
    if (message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING ||
      message.aiConfig?.aiStreamStatus === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_PLACEHOLDER) {
      this.finish = false // streaming / placeholder 认为还没结束
    } else {
      this.finish = true
    }
  }
}
