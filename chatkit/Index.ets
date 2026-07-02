/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export { ChatKitClient, currentConversationChanged } from './src/main/ets/ChatKitClient'

export { ChatRepo } from './src/main/ets/repo/ChatRepo'

export { TopicRepo } from './src/main/ets/repo/TopicRepo'

export { ContactRepo } from './src/main/ets/repo/ContactRepo'

export { TeamRepo } from './src/main/ets/repo/TeamRepo'

export { TeamEventRepo } from './src/main/ets/repo/TeamEventRepo'

export type { TeamEventDisposer } from './src/main/ets/repo/TeamEventRepo'

export { FriendEventRepo } from './src/main/ets/repo/FriendEventRepo'

export type { FriendEventDisposer } from './src/main/ets/repo/FriendEventRepo'

export { UserEventRepo } from './src/main/ets/repo/UserEventRepo'

export type { UserEventDisposer } from './src/main/ets/repo/UserEventRepo'

export { LoginEventRepo } from './src/main/ets/repo/LoginEventRepo'

export type { LoginEventDisposer } from './src/main/ets/repo/LoginEventRepo'

export { ConversationEventRepo } from './src/main/ets/repo/ConversationEventRepo'

export {
  CloudConversationStrategy,
  ConversationMode,
  LocalConversationStrategy
} from './src/main/ets/strategy/ConversationStrategy'

export type {
  ConversationItem,
  ConversationResult,
  ConversationStrategy
} from './src/main/ets/strategy/ConversationStrategy'

export { DisposableBag } from './src/main/ets/utils/DisposableBag'

export type { EventDisposer } from './src/main/ets/utils/DisposableBag'

export { SettingRepo } from './src/main/ets/repo/SettingRepo'

export { SubscriptionRepo } from './src/main/ets/repo/SubscriptionRepo'

export { StorageRepo } from './src/main/ets/repo/StorageRepo'

export { NEUserWithFriend } from './src/main/ets/model/NEUserWithFriend'

export { NEFriendUserCache } from './src/main/ets/NEFriendUserCache'

export { NEAIUserCache } from './src/main/ets/NEAIUserCache'

export { ConversationRepo } from './src/main/ets/repo/ConversationRepo'

export { ConversationIdUtilRepo } from './src/main/ets/repo/ConversationIdUtilRepo'

export { AIRepo } from './src/main/ets/repo/AIRepo'

export { UserAIBotManager } from './src/main/ets/manager/UserAIBotManager'

export { LocalConversationRepo } from './src/main/ets/repo/LocalConversationRepo'

export { IsDiscussion } from './src/main/ets/utils/Utils'

export { ErrorUtils } from './src/main/ets/utils/ErrorUtils'

export { NotificationHelper, NotificationWantParams } from './src/main/ets/utils/NotificationHelper'

export { TeamMemberWithUser, TeamMemberResult } from './src/main/ets/model/TeamMemberWithUser'

export {
  getTopStickyPermissionMode,
  hasTopStickyPermission,
  isDiscussionTeamByServerExtension
} from './src/main/ets/utils/TopStickyPermissionUtils'

export {
  buildMineServerExtensionWithAIUserPin,
  canShowAIUserPinSwitch,
  filterPinnedAIUsers,
  getUnpinAIUserList,
  isAIUserPinnedByMine,
  isPinDefaultAIUser
} from './src/main/ets/utils/AIUserExtensionUtils'

export { PersonSelectParam } from './src/main/ets/model/PersonSelectParam'

export { ConversationSelectParam } from './src/main/ets/model/ConversationSelectParam'

export { ConversationSelectModel } from './src/main/ets/model/ConversationSelectModel'

export { ConversationSelectedParam } from './src/main/ets/model/ConversationSelectedParam'

export { CustomMessageUtils } from './src/main/ets/utils/CustomMessageUtils'

export { MergedMessageAttachment,
  MergeMessageAbstract,
  MessageUploadInfo } from './src/main/ets/model/CustomMessageAttachment'

export { mergedMessageNickKey,
  mergedMessageAvatarKey,
  multiForwardFileName,
  mergedMessageMaxDepth,
  mergedMessageLimitCount,
  singleMessageLimitCount,
  deleteMessagesLimitCount,
  mergedMessageCustomType,
  mergedMessageCellHeight,
  conversationSelectLimitCount,
  keyExtensionLastOptType,
  keyExtensionAtAll,
  typeExtensionAllowAll,
  typeExtensionAllowManager,
  collectionTypeOffset,
  keyReplyMsgKey,
  multiLineMessageCustomType,
  keyExtensionTopSticky,
  keyExtensionSticky,
  keyStickyMessageClientId,
  keyStickyMessageScene,
  keyStickyMessageFrom,
  keyStickyMessageTo,
  keyStickyMessageServerId,
  keyStickyMessageTime,
  keyStickyMessageOperator,
  keyStickyMessageOperation,
  keyStickyMessageReceiverId,
  typeExtensionStickyAdd,
  typeExtensionStickyRemove
} from './src/main/ets/constant/Constant'
// 换行消息（多行消息）相关导出 - 新命名
export {
  MultiLineAttachment,
  MultiLineAttachmentData,
  MULTI_LINE_TITLE_MAX_LENGTH,
  parseMultiLineAttachment,
  createMultiLineAttachment,
  normalizeMultiLineTitle,
  isMultiLineMessage,
  getMultiLineTitle,
  getMultiLineBody,
  getMultiLinePreview,
  getMultiLinePreviewFromAttachment
} from './src/main/ets/model/MultiLineAttachment'

export { TeamMemberCache } from './src/main/ets/cache/TeamMemberCache'

export { AitModel, accountAll, aitKey, getAitModelFromJson, YxAitMsg } from './src/main/ets/model/ait/AitModel'

export { AitMessage } from './src/main/ets/model/ait/AitMessage'

export { AitSegment } from './src/main/ets/model/ait/AitSegment'

export { AitAllPermission } from './src/main/ets/model/ait/AitAllPermission'

export { AIUserAgentProvider, AIUserManager } from './src/main/ets/manager/AIUserManager'

export { KitLogger as Logger } from './src/main/ets/logger/AppLogger'

export { AIErrorCode } from './src/main/ets/utils/AIErrorCode'

export { IMKitConfigCenter } from './src/main/ets/IMKitConfigCenter'

export { PushConfigManager } from './src/main/ets/PushConfigManager'

export { TeamSettingParam } from './src/main/ets/model/TeamSettingParam'

export { ManagerSelectorParams, TeamMemberSelectorMode } from './src/main/ets/model/TeamMemberSelector'

export { MessageCallback, MessageSendParams } from './src/main/ets/listener/MessageCallback'

export {
  saveLocalRevokeMessage,
  saveLocalRevokeMessageFormOther
} from './src/main/ets/utils/MessageUtils'

export { IMKitCustomFactory } from './src/main/ets/IMKitCustomFactory'

export {
  buildTeamCreateInviteLocalExtension,
  isLocalTeamCreateInviteMessage,
  isTeamCreateInviteNotification,
  shouldCollapseTeamCreateInviteNotifications,
  teamCreateInviteLocalKey
} from './src/main/ets/utils/TeamInviteNotificationUtils'
