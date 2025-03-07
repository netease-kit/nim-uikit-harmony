/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export { ChatKitClient, currentConversationChanged } from './src/main/ets/ChatKitClient'

export { ChatRepo } from './src/main/ets/repo/ChatRepo'

export { ContactRepo } from './src/main/ets/repo/ContactRepo'

export { TeamRepo } from './src/main/ets/repo/TeamRepo'

export { SettingRepo } from './src/main/ets/repo/SettingRepo'

export { StorageRepo } from './src/main/ets/repo/StorageRepo'

export { NEUserWithFriend } from './src/main/ets/model/NEUserWithFriend'

export { NEFriendUserCache } from './src/main/ets/NEFriendUserCache'

export { ConversationRepo } from './src/main/ets/repo/ConversationRepo'

export { LocalConversationRepo } from './src/main/ets/repo/LocalConversationRepo'

export { IsDiscussion } from './src/main/ets/utils/Utils'

export { ErrorUtils } from './src/main/ets/utils/ErrorUtils'

export { TeamMemberWithUser, TeamMemberResult } from './src/main/ets/model/TeamMemberWithUser'

export { PersonSelectParam } from './src/main/ets/model/PersonSelectParam'

export { ConversationSelectParam } from './src/main/ets/model/ConversationSelectParam'

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
  keyReplyMsgKey
} from './src/main/ets/constant/Constant'

export { TeamMemberCache } from './src/main/ets/cache/TeamMemberCache'

export { AitModel, accountAll, aitKey, getAitModelFromJson, YxAitMsg } from './src/main/ets/model/ait/AitModel'

export { AitMessage } from './src/main/ets/model/ait/AitMessage'

export { AitSegment } from './src/main/ets/model/ait/AitSegment'

export { AitAllPermission } from './src/main/ets/model/ait/AitAllPermission'

export { KitLogger as Logger } from './src/main/ets/logger/AppLogger'

export {IMKitConfigCenter} from './src/main/ets/IMKitConfigCenter'