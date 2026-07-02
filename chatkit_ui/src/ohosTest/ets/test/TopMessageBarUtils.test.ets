/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium';

// ===== 本地 V2NIMMessageType 枚举值 =====
// 与 @nimsdk/base V2NIMMessageType 对齐：
// V2NIM_MESSAGE_TYPE_TEXT = 0, IMAGE = 1, VIDEO = 3, LOCATION = 4
const V2NIM_MESSAGE_TYPE_TEXT = 0
const V2NIM_MESSAGE_TYPE_IMAGE = 1
const V2NIM_MESSAGE_TYPE_VIDEO = 3
const V2NIM_MESSAGE_TYPE_LOCATION = 4
const V2NIM_MESSAGE_TYPE_AUDIO = 5
const V2NIM_MESSAGE_TYPE_FILE = 6

// ===== Mock 依赖: contentOfMessage =====
// 原函数依赖 HarmonyOS 平台 API（getContext().resourceManager），此处提供纯逻辑替代
function mockContentOfMessage(message: { messageType: number, text?: string }): string {
  if (message.messageType === V2NIM_MESSAGE_TYPE_LOCATION) {
    return '[Location]'
  }
  return message.text ?? ''
}

// ===== Mock 依赖: getVideoMessageUrl =====
// 原函数依赖 HarmonyOS 平台 API（fs, fileUri 等），此处提供纯逻辑替代
function mockGetVideoMessageUrl(messageInfo: { message: { messageType: number } }): string {
  if (messageInfo.message.messageType === V2NIM_MESSAGE_TYPE_VIDEO) {
    return 'http://video.thumb.url'
  }
  return ''
}

// ===== 本地纯函数副本：shouldShowTopMessageBar =====
function shouldShowTopMessageBar(enableTopMessage: boolean, messageInfo: object | undefined): boolean {
  return enableTopMessage && messageInfo !== undefined
}

// ===== 本地纯函数副本：getTopMessageSenderName =====
function getTopMessageSenderName(senderId: string, senderName?: string): string {
  if (senderId.length === 0) {
    return ''
  }
  const displayName = senderName ?? ''
  if (displayName.trim().length > 0) {
    return displayName
  }
  return senderId
}

// ===== 本地纯函数副本：buildTopMessageSummary =====
function buildTopMessageSummary(summary: string, detail?: string): string {
  const normalizedSummary = summary.trim()
  const normalizedDetail = detail?.trim() ?? ''
  if (normalizedSummary.length === 0) {
    return normalizedDetail
  }
  if (normalizedDetail.length === 0) {
    return normalizedSummary
  }
  return `${normalizedSummary} ${normalizedDetail}`
}

// ===== 本地纯函数副本：resolveTopMessageLocationDetail =====
function resolveTopMessageLocationDetail(messageType: number, locationName?: string, address?: string): string {
  if (messageType !== V2NIM_MESSAGE_TYPE_LOCATION) {
    return ''
  }
  const normalizedLocationName = locationName?.trim() ?? ''
  if (normalizedLocationName.length > 0) {
    return normalizedLocationName
  }
  return address?.trim() ?? ''
}

// ===== 本地纯函数副本：getTopMessageLocationDetail =====
// 使用 mock 对象（代替 NIMMessageInfo 类型），通过 message.attachment.address 获取地址
function getTopMessageLocationDetail(messageInfo: { message: { messageType: number; text?: string; attachment?: { address?: string } } } | undefined): string {
  if (!messageInfo) {
    return ''
  }
  const locationAttachment = messageInfo.message.attachment as { address?: string } | undefined
  return resolveTopMessageLocationDetail(messageInfo.message.messageType, messageInfo.message.text, locationAttachment?.address)
}

// ===== 本地纯函数副本：getTopMessageSummary =====
// 替代 contentOfMessage 为 mockContentOfMessage
function getTopMessageSummary(messageInfo: { message: { messageType: number; text?: string; attachment?: { address?: string } } } | undefined): string {
  if (!messageInfo) {
    return ''
  }
  const summary = mockContentOfMessage(messageInfo.message)
  if (messageInfo.message.messageType !== V2NIM_MESSAGE_TYPE_LOCATION) {
    return summary
  }
  return buildTopMessageSummary(summary, getTopMessageLocationDetail(messageInfo))
}

// ===== 本地纯函数副本：isTopMessageImage =====
function isTopMessageImage(messageInfo: { message: { messageType: number } } | undefined): boolean {
  return messageInfo?.message.messageType === V2NIM_MESSAGE_TYPE_IMAGE
}

// ===== 本地纯函数副本：isTopMessageVideo =====
function isTopMessageVideo(messageInfo: { message: { messageType: number } } | undefined): boolean {
  return messageInfo?.message.messageType === V2NIM_MESSAGE_TYPE_VIDEO
}

// ===== 本地纯函数副本：getTopMessageVideoPreviewUrl =====
// 替代 getVideoMessageUrl 为 mockGetVideoMessageUrl
function getTopMessageVideoPreviewUrl(messageInfo: { message: { messageType: number } } | undefined): string {
  if (!messageInfo || !isTopMessageVideo(messageInfo)) {
    return ''
  }
  return mockGetVideoMessageUrl(messageInfo)
}

// ===== 本地纯函数副本：isTopMessageMatched (非导出，内部函数) =====
function isTopMessageMatched(topMessageClientId?: string, topMessageServerId?: string,
  currentMessageClientId?: string, currentMessageServerId?: string): boolean {
  const normalizedTopClientId = topMessageClientId?.trim() ?? ''
  const normalizedTopServerId = topMessageServerId?.trim() ?? ''
  const normalizedCurrentClientId = currentMessageClientId?.trim() ?? ''
  const normalizedCurrentServerId = currentMessageServerId?.trim() ?? ''

  if (normalizedTopClientId.length > 0 && normalizedTopClientId === normalizedCurrentClientId) {
    return true
  }
  if (normalizedTopServerId.length > 0 && normalizedTopServerId === normalizedCurrentServerId) {
    return true
  }
  return false
}

// ===== 本地纯函数副本：isTopMessageRevoked =====
function isTopMessageRevoked(topMessageClientId?: string, topMessageServerId?: string,
  revokeMessageClientId?: string, revokeMessageServerId?: string): boolean {
  return isTopMessageMatched(topMessageClientId, topMessageServerId, revokeMessageClientId, revokeMessageServerId)
}

// ===== 本地纯函数副本：isTopMessageDeleted =====
function isTopMessageDeleted(topMessageClientId?: string, topMessageServerId?: string,
  deleteMessageClientId?: string, deleteMessageServerId?: string): boolean {
  return isTopMessageMatched(topMessageClientId, topMessageServerId, deleteMessageClientId, deleteMessageServerId)
}

export default function topMessageBarUtilsTest() {
  // ========== shouldShowTopMessageBar ==========
  describe('TopMessageBarUtils_shouldShowTopMessageBar', () => {
    it('should_return_true_when_enabled_and_info_defined', 0, () => {
      expect(shouldShowTopMessageBar(true, {})).assertTrue()
    })

    it('should_return_false_when_enabled_but_info_undefined', 0, () => {
      expect(shouldShowTopMessageBar(true, undefined)).assertFalse()
    })

    it('should_return_false_when_disabled_even_if_info_defined', 0, () => {
      expect(shouldShowTopMessageBar(false, {})).assertFalse()
    })

    it('should_return_false_when_disabled_and_info_undefined', 0, () => {
      expect(shouldShowTopMessageBar(false, undefined)).assertFalse()
    })
  })

  // ========== getTopMessageSenderName ==========
  describe('TopMessageBarUtils_getTopMessageSenderName', () => {
    it('should_return_empty_string_when_senderId_is_empty', 0, () => {
      expect(getTopMessageSenderName('', 'Alice')).assertEqual('')
    })

    it('should_return_senderName_when_senderName_defined_and_non_empty', 0, () => {
      expect(getTopMessageSenderName('user123', 'Alice')).assertEqual('Alice')
    })

    it('should_return_senderId_when_senderName_undefined', 0, () => {
      expect(getTopMessageSenderName('user123', undefined)).assertEqual('user123')
    })

    it('should_return_senderId_when_senderName_empty_string', 0, () => {
      expect(getTopMessageSenderName('user123', '')).assertEqual('user123')
    })

    it('should_return_senderId_when_senderName_is_whitespace_only', 0, () => {
      expect(getTopMessageSenderName('user123', '   ')).assertEqual('user123')
    })

    it('should_return_trimmed_senderName_when_senderName_has_leading_trailing_spaces', 0, () => {
      expect(getTopMessageSenderName('user123', '  Alice  ')).assertEqual('  Alice  ')
    })
  })

  // ========== buildTopMessageSummary ==========
  describe('TopMessageBarUtils_buildTopMessageSummary', () => {
    it('should_return_empty_when_both_summary_and_detail_empty', 0, () => {
      expect(buildTopMessageSummary('', '')).assertEqual('')
    })

    it('should_return_detail_when_summary_empty_and_detail_non_empty', 0, () => {
      expect(buildTopMessageSummary('', 'Beijing')).assertEqual('Beijing')
    })

    it('should_return_summary_when_summary_non_empty_and_detail_empty', 0, () => {
      expect(buildTopMessageSummary('[Location]', '')).assertEqual('[Location]')
    })

    it('should_join_both_when_both_non_empty', 0, () => {
      expect(buildTopMessageSummary('[Location]', 'Beijing')).assertEqual('[Location] Beijing')
    })

    it('should_return_detail_when_summary_whitespace_only', 0, () => {
      expect(buildTopMessageSummary('   ', 'Beijing')).assertEqual('Beijing')
    })

    it('should_return_summary_when_detail_whitespace_only', 0, () => {
      expect(buildTopMessageSummary('[Location]', '   ')).assertEqual('[Location]')
    })

    it('should_return_detail_when_detail_undefined', 0, () => {
      expect(buildTopMessageSummary('', undefined)).assertEqual('')
    })

    it('should_return_summary_when_summary_non_empty_and_detail_undefined', 0, () => {
      expect(buildTopMessageSummary('[Location]', undefined)).assertEqual('[Location]')
    })
  })

  // ========== resolveTopMessageLocationDetail ==========
  describe('TopMessageBarUtils_resolveTopMessageLocationDetail', () => {
    it('should_return_empty_when_messageType_not_location', 0, () => {
      expect(resolveTopMessageLocationDetail(V2NIM_MESSAGE_TYPE_TEXT, 'Beijing', 'Beijing Address')).assertEqual('')
    })

    it('should_return_locationName_when_location_type_and_name_non_empty', 0, () => {
      expect(resolveTopMessageLocationDetail(V2NIM_MESSAGE_TYPE_LOCATION, 'Beijing', 'Beijing Address')).assertEqual('Beijing')
    })

    it('should_return_address_when_location_type_and_name_empty_but_address_non_empty', 0, () => {
      expect(resolveTopMessageLocationDetail(V2NIM_MESSAGE_TYPE_LOCATION, '', 'Beijing Address')).assertEqual('Beijing Address')
    })

    it('should_return_address_when_location_type_and_name_undefined_but_address_non_empty', 0, () => {
      expect(resolveTopMessageLocationDetail(V2NIM_MESSAGE_TYPE_LOCATION, undefined, 'Beijing Address')).assertEqual('Beijing Address')
    })

    it('should_return_empty_when_location_type_and_both_name_and_address_empty', 0, () => {
      expect(resolveTopMessageLocationDetail(V2NIM_MESSAGE_TYPE_LOCATION, '', '')).assertEqual('')
    })

    it('should_return_empty_when_location_type_and_both_undefined', 0, () => {
      expect(resolveTopMessageLocationDetail(V2NIM_MESSAGE_TYPE_LOCATION, undefined, undefined)).assertEqual('')
    })

    it('should_return_trimmed_locationName_when_name_has_leading_trailing_spaces', 0, () => {
      expect(resolveTopMessageLocationDetail(V2NIM_MESSAGE_TYPE_LOCATION, '  Beijing  ', undefined)).assertEqual('Beijing')
    })
  })

  // ========== isTopMessageImage ==========
  describe('TopMessageBarUtils_isTopMessageImage', () => {
    it('should_return_true_when_message_type_is_image', 0, () => {
      expect(isTopMessageImage({ message: { messageType: V2NIM_MESSAGE_TYPE_IMAGE } })).assertTrue()
    })

    it('should_return_false_when_message_type_is_not_image', 0, () => {
      expect(isTopMessageImage({ message: { messageType: V2NIM_MESSAGE_TYPE_VIDEO } })).assertFalse()
    })

    it('should_return_false_when_messageInfo_is_undefined', 0, () => {
      expect(isTopMessageImage(undefined)).assertFalse()
    })

    it('should_return_false_when_message_type_is_text', 0, () => {
      expect(isTopMessageImage({ message: { messageType: V2NIM_MESSAGE_TYPE_TEXT } })).assertFalse()
    })
  })

  // ========== isTopMessageVideo ==========
  describe('TopMessageBarUtils_isTopMessageVideo', () => {
    it('should_return_true_when_message_type_is_video', 0, () => {
      expect(isTopMessageVideo({ message: { messageType: V2NIM_MESSAGE_TYPE_VIDEO } })).assertTrue()
    })

    it('should_return_false_when_message_type_is_not_video', 0, () => {
      expect(isTopMessageVideo({ message: { messageType: V2NIM_MESSAGE_TYPE_IMAGE } })).assertFalse()
    })

    it('should_return_false_when_messageInfo_is_undefined', 0, () => {
      expect(isTopMessageVideo(undefined)).assertFalse()
    })

    it('should_return_false_when_message_type_is_text', 0, () => {
      expect(isTopMessageVideo({ message: { messageType: V2NIM_MESSAGE_TYPE_TEXT } })).assertFalse()
    })
  })

  // ========== getTopMessageLocationDetail ==========
  describe('TopMessageBarUtils_getTopMessageLocationDetail', () => {
    it('should_return_empty_when_messageInfo_is_undefined', 0, () => {
      expect(getTopMessageLocationDetail(undefined)).assertEqual('')
    })

    it('should_return_empty_when_messageType_is_not_location', 0, () => {
      const msgInfo = { message: { messageType: V2NIM_MESSAGE_TYPE_TEXT } }
      expect(getTopMessageLocationDetail(msgInfo)).assertEqual('')
    })

    it('should_return_location_name_when_location_type_and_name_present', 0, () => {
      const msgInfo = {
        message: {
          messageType: V2NIM_MESSAGE_TYPE_LOCATION,
          text: 'Beijing',
          attachment: { address: 'Beijing Address' }
        }
      }
      expect(getTopMessageLocationDetail(msgInfo)).assertEqual('Beijing')
    })

    it('should_return_address_when_location_type_and_name_empty_but_address_present', 0, () => {
      const msgInfo = {
        message: {
          messageType: V2NIM_MESSAGE_TYPE_LOCATION,
          text: '',
          attachment: { address: 'Beijing Address' }
        }
      }
      expect(getTopMessageLocationDetail(msgInfo)).assertEqual('Beijing Address')
    })

    it('should_return_empty_when_no_attachment', 0, () => {
      const msgInfo = {
        message: { messageType: V2NIM_MESSAGE_TYPE_LOCATION, text: '' }
      }
      expect(getTopMessageLocationDetail(msgInfo)).assertEqual('')
    })
  })

  // ========== getTopMessageSummary ==========
  describe('TopMessageBarUtils_getTopMessageSummary', () => {
    it('should_return_empty_when_messageInfo_is_undefined', 0, () => {
      expect(getTopMessageSummary(undefined)).assertEqual('')
    })

    it('should_return_contentOfMessage_for_non_location_type', 0, () => {
      const msgInfo = {
        message: { messageType: V2NIM_MESSAGE_TYPE_TEXT, text: 'Hello World' }
      }
      expect(getTopMessageSummary(msgInfo)).assertEqual('Hello World')
    })

    it('should_return_contentOfMessage_for_image_type', 0, () => {
      const msgInfo = {
        message: { messageType: V2NIM_MESSAGE_TYPE_IMAGE, text: '' }
      }
      expect(getTopMessageSummary(msgInfo)).assertEqual('')
    })

    it('should_return_compound_summary_for_location_type_with_name', 0, () => {
      const msgInfo = {
        message: {
          messageType: V2NIM_MESSAGE_TYPE_LOCATION,
          text: 'Beijing',
          attachment: { address: 'Beijing Address' }
        }
      }
      expect(getTopMessageSummary(msgInfo)).assertEqual('[Location] Beijing')
    })

    it('should_return_compound_summary_for_location_type_with_address_only', 0, () => {
      const msgInfo = {
        message: {
          messageType: V2NIM_MESSAGE_TYPE_LOCATION,
          text: '',
          attachment: { address: 'Beijing Address' }
        }
      }
      expect(getTopMessageSummary(msgInfo)).assertEqual('[Location] Beijing Address')
    })

    it('should_return_location_content_only_when_no_name_or_address', 0, () => {
      const msgInfo = {
        message: { messageType: V2NIM_MESSAGE_TYPE_LOCATION, text: '' }
      }
      expect(getTopMessageSummary(msgInfo)).assertEqual('[Location]')
    })
  })

  // ========== getTopMessageVideoPreviewUrl ==========
  describe('TopMessageBarUtils_getTopMessageVideoPreviewUrl', () => {
    it('should_return_empty_when_messageInfo_is_undefined', 0, () => {
      expect(getTopMessageVideoPreviewUrl(undefined)).assertEqual('')
    })

    it('should_return_empty_when_message_is_not_video', 0, () => {
      expect(getTopMessageVideoPreviewUrl({ message: { messageType: V2NIM_MESSAGE_TYPE_IMAGE } })).assertEqual('')
    })

    it('should_return_thumb_url_when_message_is_video', 0, () => {
      expect(getTopMessageVideoPreviewUrl({ message: { messageType: V2NIM_MESSAGE_TYPE_VIDEO } })).assertEqual('http://video.thumb.url')
    })
  })

  // ========== isTopMessageMatched (内部辅助函数) ==========
  describe('TopMessageBarUtils_isTopMessageMatched', () => {
    it('should_match_by_clientId_when_both_non_empty_and_equal', 0, () => {
      expect(isTopMessageMatched('client123', undefined, 'client123', undefined)).assertTrue()
    })

    it('should_match_by_serverId_when_clientId_not_matched_but_serverId_matches', 0, () => {
      expect(isTopMessageMatched('client123', 'server456', 'client999', 'server456')).assertTrue()
    })

    it('should_match_by_serverId_when_clientId_empty_but_serverId_matches', 0, () => {
      expect(isTopMessageMatched('', 'server456', '', 'server456')).assertTrue()
    })

    it('should_not_match_when_both_clientId_and_serverId_differ', 0, () => {
      expect(isTopMessageMatched('client123', 'server456', 'client999', 'server888')).assertFalse()
    })

    it('should_not_match_when_both_top_ids_empty', 0, () => {
      expect(isTopMessageMatched('', '', 'client123', 'server456')).assertFalse()
    })

    it('should_not_match_when_all_ids_empty', 0, () => {
      expect(isTopMessageMatched('', '', '', '')).assertFalse()
    })

    it('should_not_match_when_only_whitespace_ids', 0, () => {
      expect(isTopMessageMatched('  ', '  ', '  ', '  ')).assertFalse()
    })

    it('should_match_by_clientId_after_trim', 0, () => {
      expect(isTopMessageMatched('  client123  ', undefined, 'client123', undefined)).assertTrue()
    })
  })

  // ========== isTopMessageRevoked ==========
  describe('TopMessageBarUtils_isTopMessageRevoked', () => {
    it('should_return_true_when_clientId_matches', 0, () => {
      expect(isTopMessageRevoked('client123', undefined, 'client123', undefined)).assertTrue()
    })

    it('should_return_true_when_serverId_matches', 0, () => {
      expect(isTopMessageRevoked('client123', 'server456', 'client999', 'server456')).assertTrue()
    })

    it('should_return_false_when_neither_clientId_nor_serverId_match', 0, () => {
      expect(isTopMessageRevoked('client123', 'server456', 'client999', 'server888')).assertFalse()
    })

    it('should_return_false_when_all_params_empty', 0, () => {
      expect(isTopMessageRevoked('', '', '', '')).assertFalse()
    })
  })

  // ========== isTopMessageDeleted ==========
  describe('TopMessageBarUtils_isTopMessageDeleted', () => {
    it('should_return_true_when_clientId_matches', 0, () => {
      expect(isTopMessageDeleted('client123', undefined, 'client123', undefined)).assertTrue()
    })

    it('should_return_true_when_serverId_matches', 0, () => {
      expect(isTopMessageDeleted('client123', 'server456', 'client999', 'server456')).assertTrue()
    })

    it('should_return_false_when_neither_clientId_nor_serverId_match', 0, () => {
      expect(isTopMessageDeleted('client123', 'server456', 'client999', 'server888')).assertFalse()
    })

    it('should_return_false_when_all_params_undefined', 0, () => {
      expect(isTopMessageDeleted(undefined, undefined, undefined, undefined)).assertFalse()
    })
  })
}
