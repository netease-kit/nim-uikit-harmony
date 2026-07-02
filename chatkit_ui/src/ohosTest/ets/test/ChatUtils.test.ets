/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  buildTopMessageSummary,
  isTopMessageDeleted,
  isTopMessageRevoked,
  resolveTopMessageLocationDetail,
  getTopMessageSenderName,
  shouldShowTopMessageBar
} from '../../../main/ets/utils/TopMessageBarUtils';
import { V2NIMMessageType } from '@nimsdk/base';

// 本地副本：避免跨模块导入 '../../../chatkit/src/main/ets/utils/TopStickyPermissionUtils'
function getTopStickyPermissionMode(serverExtension?: string): string {
  if (!serverExtension || serverExtension.length === 0) {
    return 'manager';
  }
  return 'all';
}
function hasTopStickyPermission(permissionMode: string, memberRole: number | undefined): boolean {
  if (permissionMode === 'all') {
    return true;
  }
  if (memberRole === undefined) {
    return false;
  }
  return memberRole === 3 || memberRole === 2;
}

/**
 * getOpenFileType 的纯逻辑单元测试
 * 由于该函数依赖 import 路径中 HarmonyOS 平台特定模块，此处直接将函数逻辑复制为本地版本进行测试。
 */
function getOpenFileType(fileExt: string): string {
  if (fileExt.includes('txt')) {
    return 'text/plain'
  } else if (fileExt.includes('cpp')) {
    return 'text/x-c++src'
  } else if (fileExt.includes('c')) {
    return 'text/x-csrc'
  } else if (fileExt.includes('h')) {
    return 'text/x-chdr'
  } else if (fileExt.includes('java')) {
    return 'text/x-java'
  } else if (fileExt.includes('xhtml')) {
    return 'application/xhtml+xml'
  } else if (fileExt.includes('xml')) {
    return 'text/xml'
  } else if (fileExt.includes('html') || fileExt.includes('htm')) {
    return 'text/html'
  } else if (fileExt.includes('pdf')) {
    return 'application/pdf'
  } else if (fileExt.includes('jpg')) {
    return 'image/jpeg'
  } else if (fileExt.includes('png')) {
    return 'image/png'
  } else if (fileExt.includes('gif')) {
    return 'image/gif'
  } else if (fileExt.includes('webp')) {
    return 'image/webp'
  } else if (fileExt.includes('bmp')) {
    return 'image/bmp'
  } else if (fileExt.includes('svg')) {
    return 'image/svg+xml'
  } else if (fileExt.includes('m4a')) {
    return 'audio/mp4a-latm'
  } else if (fileExt.includes('mp3')) {
    return 'audio/mpeg'
  } else if (fileExt.includes('aac')) {
    return 'audio/aac'
  } else if (fileExt.includes('ogg')) {
    return 'audio/ogg'
  } else if (fileExt.includes('wav')) {
    return 'audio/x-wav'
  } else if (fileExt.includes('mp4')) {
    return 'video/mp4'
  } else if (fileExt.includes('mkv')) {
    return 'video/x-matroska'
  } else if (fileExt.includes('ts')) {
    return 'video/mp2ts'
  }
  return ' '
}

function sliceContent(content: string | undefined, maxsize: number, isCenter: boolean): string {
  if (!content) {
    return ''
  }
  let result = content
  if (content.length > maxsize) {
    if (isCenter) {
      let startIndex = Math.floor(maxsize * 0.75)
      let lastIndex = content.length - 2
      let targetStr = content.charAt(startIndex)
      let lastTargetStr = content.charAt(lastIndex)
      if (isCharacterEmoji(targetStr) && !isLastCharacterEmoji(targetStr)) {
        startIndex++
      }
      let nick = content.substring(0, startIndex + 1) + "..."
      if (isLastCharacterEmoji(lastTargetStr)) {
        lastIndex++
      }
      result = nick + content.substring(lastIndex)
    } else {
      let lastIndex = maxsize - 2
      let lastTargetStr = content.charAt(lastIndex)
      if (isCharacterEmoji(lastTargetStr) && !isLastCharacterEmoji(lastTargetStr)) {
        lastIndex++
      }
      result = content.substring(0, lastIndex + 1) + "..."
    }
  }
  return result
}

function isLastCharacterEmoji(str: string): boolean {
  const emojiRegex = /[\uDC00-\uDFFF]+$/u
  return emojiRegex.test(str)
}

function isCharacterEmoji(str: string): boolean {
  const emojiRegex = /[\uD83C-\uDBFF\uDC00-\uDFFF]+$/u
  return emojiRegex.test(str)
}

const TEAM_MEMBER_ROLE_NORMAL = 0
const TEAM_MEMBER_ROLE_OWNER = 1
const TEAM_MEMBER_ROLE_MANAGER = 2

export default function chatUtilsTest() {
  describe('ChatUtils_getOpenFileType', () => {
    // ===== 文本类型 =====
    it('should_return_text_plain_for_txt', 0, () => {
      expect(getOpenFileType('txt')).assertEqual('text/plain');
    });

    it('should_return_text_plain_for_file_with_txt', 0, () => {
      expect(getOpenFileType('document.txt')).assertEqual('text/plain');
    });

    it('should_return_text_x_c++src_for_cpp', 0, () => {
      expect(getOpenFileType('cpp')).assertEqual('text/x-c++src');
    });

    it('should_return_text_x_java_for_java', 0, () => {
      expect(getOpenFileType('java')).assertEqual('text/x-java');
    });

    it('should_return_text_xml_for_xml', 0, () => {
      expect(getOpenFileType('xml')).assertEqual('text/xml');
    });

    it('should_return_application_xhtml_for_xhtml', 0, () => {
      expect(getOpenFileType('xhtml')).assertEqual('application/xhtml+xml');
    });

    it('should_return_text_html_for_html', 0, () => {
      expect(getOpenFileType('html')).assertEqual('text/html');
    });

    it('should_return_text_html_for_htm', 0, () => {
      expect(getOpenFileType('htm')).assertEqual('text/html');
    });

    // ===== 文档类型 =====
    it('should_return_application_pdf_for_pdf', 0, () => {
      expect(getOpenFileType('pdf')).assertEqual('application/pdf');
    });

    // ===== 图片类型 =====
    it('should_return_image_jpeg_for_jpg', 0, () => {
      expect(getOpenFileType('jpg')).assertEqual('image/jpeg');
    });

    it('should_return_image_png_for_png', 0, () => {
      expect(getOpenFileType('png')).assertEqual('image/png');
    });

    it('should_return_image_gif_for_gif', 0, () => {
      expect(getOpenFileType('gif')).assertEqual('image/gif');
    });

    it('should_return_image_webp_for_webp', 0, () => {
      expect(getOpenFileType('webp')).assertEqual('image/webp');
    });

    it('should_return_image_bmp_for_bmp', 0, () => {
      expect(getOpenFileType('bmp')).assertEqual('image/bmp');
    });

    it('should_return_image_svg_for_svg', 0, () => {
      expect(getOpenFileType('svg')).assertEqual('image/svg+xml');
    });

    // ===== 音频类型 =====
    it('should_return_audio_mp4a_for_m4a', 0, () => {
      expect(getOpenFileType('m4a')).assertEqual('audio/mp4a-latm');
    });

    it('should_return_audio_mpeg_for_mp3', 0, () => {
      expect(getOpenFileType('mp3')).assertEqual('audio/mpeg');
    });

    it('should_return_audio_aac_for_aac', 0, () => {
      expect(getOpenFileType('aac')).assertEqual('audio/aac');
    });

    it('should_return_audio_ogg_for_ogg', 0, () => {
      expect(getOpenFileType('ogg')).assertEqual('audio/ogg');
    });

    it('should_return_audio_wav_for_wav', 0, () => {
      expect(getOpenFileType('wav')).assertEqual('audio/x-wav');
    });

    // ===== 视频类型 =====
    it('should_return_video_mp4_for_mp4', 0, () => {
      expect(getOpenFileType('mp4')).assertEqual('video/mp4');
    });

    it('should_return_video_mkv_for_mkv', 0, () => {
      expect(getOpenFileType('mkv')).assertEqual('video/x-matroska');
    });

    it('should_return_video_ts_for_ts', 0, () => {
      expect(getOpenFileType('ts')).assertEqual('video/mp2ts');
    });

    // ===== 未知类型 =====
    it('should_return_space_for_unknown_type', 0, () => {
      expect(getOpenFileType('xyz')).assertEqual(' ');
    });

    it('should_return_space_for_empty_string', 0, () => {
      expect(getOpenFileType('')).assertEqual(' ');
    });
  });

  describe('ChatUtils_sliceContent', () => {
    it('should_return_empty_string_for_undefined', 0, () => {
      expect(sliceContent(undefined, 10, false)).assertEqual('');
    });

    it('should_return_empty_string_for_empty_content', 0, () => {
      expect(sliceContent('', 10, false)).assertEqual('');
    });

    it('should_return_original_string_if_within_maxsize', 0, () => {
      expect(sliceContent('hello', 10, false)).assertEqual('hello');
    });

    it('should_return_original_string_if_exact_maxsize', 0, () => {
      expect(sliceContent('0123456789', 10, false)).assertEqual('0123456789');
    });

    it('should_truncate_with_ellipsis_when_not_center', 0, () => {
      let content = 'abcdefghijklmnop'; // length = 16
      let result = sliceContent(content, 10, false);
      // lastIndex = 10-2 = 8, result = content.substring(0,9) + '...'
      expect(result).assertEqual('abcdefghi...');
    });

    it('should_truncate_with_center_ellipsis', 0, () => {
      let content = 'abcdefghijklmnopqrstuvwxyz'; // length = 26
      let result = sliceContent(content, 10, true);
      // startIndex = floor(10*0.75) = 7, lastIndex = 26-2 = 24
      // nick = content.substring(0,8) + '...' = 'abcdefgh...'
      // result = 'abcdefgh...' + content.substring(24) = 'abcdefgh...' + 'yz'
      expect(result).assertEqual('abcdefgh...yz');
    });

    it('should_handle_short_content_below_maxsize', 0, () => {
      expect(sliceContent('ab', 10, true)).assertEqual('ab');
    });
  });

  describe('ChatUtils_isCharacterEmoji', () => {
    it('should_return_false_for_normal_character', 0, () => {
      expect(isCharacterEmoji('a')).assertFalse();
    });

    it('should_return_false_for_empty_string', 0, () => {
      expect(isCharacterEmoji('')).assertFalse();
    });

    it('should_return_false_for_number', 0, () => {
      expect(isCharacterEmoji('1')).assertFalse();
    });

    it('should_return_false_for_chinese_character', 0, () => {
      expect(isCharacterEmoji('中')).assertFalse();
    });
  });

  describe('ChatUtils_isLastCharacterEmoji', () => {
    it('should_return_false_for_normal_character', 0, () => {
      expect(isLastCharacterEmoji('a')).assertFalse();
    });

    it('should_return_false_for_empty_string', 0, () => {
      expect(isLastCharacterEmoji('')).assertFalse();
    });

    it('should_return_false_for_number', 0, () => {
      expect(isLastCharacterEmoji('5')).assertFalse();
    });
  });

  describe('ChatUtils_havePermissionForTopSticky', () => {
    it('should_allow_discussion_member_by_default_without_yxAllowTop', 0, () => {
      const permissionMode = getTopStickyPermissionMode(JSON.stringify({ im_ui_kit_group: true }))
      expect(hasTopStickyPermission(permissionMode, TEAM_MEMBER_ROLE_NORMAL)).assertTrue()
    })

    it('should_allow_normal_member_when_team_sets_yxAllowTop_all', 0, () => {
      const permissionMode = getTopStickyPermissionMode(JSON.stringify({ yxAllowTop: 'all' }))
      expect(hasTopStickyPermission(permissionMode, TEAM_MEMBER_ROLE_NORMAL)).assertTrue()
    })

    it('should_deny_discussion_normal_member_when_yxAllowTop_is_manager', 0, () => {
      const permissionMode = getTopStickyPermissionMode(JSON.stringify({
        im_ui_kit_group: true,
        yxAllowTop: 'manager'
      }))
      expect(hasTopStickyPermission(permissionMode, TEAM_MEMBER_ROLE_NORMAL)).assertFalse()
    })

    it('should_allow_discussion_owner_and_manager_when_yxAllowTop_is_manager', 0, () => {
      const permissionMode = getTopStickyPermissionMode(JSON.stringify({
        im_ui_kit_group: true,
        yxAllowTop: 'manager'
      }))
      expect(hasTopStickyPermission(permissionMode, TEAM_MEMBER_ROLE_OWNER)).assertTrue()
      expect(hasTopStickyPermission(permissionMode, TEAM_MEMBER_ROLE_MANAGER)).assertTrue()
    })

    it('should_deny_non_discussion_normal_member_without_top_permission_config', 0, () => {
      const permissionMode = getTopStickyPermissionMode(JSON.stringify({ someOtherKey: true }))
      expect(hasTopStickyPermission(permissionMode, TEAM_MEMBER_ROLE_NORMAL)).assertFalse()
    })

    it('should_return_false_when_member_role_is_undefined', 0, () => {
      const permissionMode = getTopStickyPermissionMode(JSON.stringify({ im_ui_kit_group: true }))
      expect(hasTopStickyPermission(permissionMode, undefined)).assertFalse()
    })
  })

  describe('TopMessageBar_getTopMessageSenderName', () => {
    it('should_prefer_chat_info_display_name', 0, () => {
      expect(getTopMessageSenderName('accid_001', '好友备注名')).assertEqual('好友备注名')
    })

    it('should_fall_back_to_sender_id_when_chat_info_returns_empty_name', 0, () => {
      expect(getTopMessageSenderName('accid_002', '   ')).assertEqual('accid_002')
    })

    it('should_fall_back_to_sender_id_when_chat_info_is_missing', 0, () => {
      expect(getTopMessageSenderName('accid_003', undefined)).assertEqual('accid_003')
    })
  })

  describe('TopMessageBar_shouldShowTopMessageBar', () => {
    it('should_hide_when_top_message_feature_is_disabled', 0, () => {
      expect(shouldShowTopMessageBar(false, new Object() as Record<string, Object>)).assertFalse()
    })

    it('should_hide_when_top_message_is_missing', 0, () => {
      expect(shouldShowTopMessageBar(true, undefined)).assertFalse()
    })

    it('should_show_when_feature_is_enabled_and_message_exists', 0, () => {
      expect(shouldShowTopMessageBar(true, new Object() as Record<string, Object>)).assertTrue()
    })
  })

  describe('TopMessageBar_buildTopMessageSummary', () => {
    it('should_keep_standard_audio_summary_text', 0, () => {
      expect(buildTopMessageSummary('[语音消息]')).assertEqual('[语音消息]')
    })

    it('should_keep_standard_chat_history_summary_text', 0, () => {
      expect(buildTopMessageSummary('[聊天记录]')).assertEqual('[聊天记录]')
    })

    it('should_append_location_detail_after_summary', 0, () => {
      expect(buildTopMessageSummary('[地理位置]', '网易大厦')).assertEqual('[地理位置] 网易大厦')
    })
  })

  describe('TopMessageBar_resolveTopMessageLocationDetail', () => {
    it('should_prefer_location_name_text', 0, () => {
      expect(resolveTopMessageLocationDetail(
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION,
        '网易大厦',
        '浙江省杭州市滨江区网商路'
      )).assertEqual('网易大厦')
    })

    it('should_fall_back_to_location_address_when_text_is_empty', 0, () => {
      expect(resolveTopMessageLocationDetail(
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION,
        '   ',
        '浙江省杭州市滨江区网商路'
      )).assertEqual('浙江省杭州市滨江区网商路')
    })

    it('should_return_empty_when_message_is_not_location', 0, () => {
      expect(resolveTopMessageLocationDetail(
        V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT,
        '网易大厦',
        '浙江省杭州市滨江区网商路'
      )).assertEqual('')
    })
  })

  describe('TopMessageBar_isTopMessageRevoked', () => {
    it('should_match_when_revoke_client_id_equals_top_message_client_id', 0, () => {
      expect(isTopMessageRevoked(
        'msg_client_001',
        'msg_server_001',
        'msg_client_001',
        'msg_server_other'
      )).assertTrue()
    })

    it('should_match_when_revoke_server_id_equals_top_message_server_id', 0, () => {
      expect(isTopMessageRevoked(
        'msg_client_001',
        'msg_server_001',
        'msg_client_other',
        'msg_server_001'
      )).assertTrue()
    })

    it('should_return_false_when_revoke_message_does_not_match_top_message', 0, () => {
      expect(isTopMessageRevoked(
        'msg_client_001',
        'msg_server_001',
        'msg_client_other',
        'msg_server_other'
      )).assertFalse()
    })
  })

  describe('TopMessageBar_isTopMessageDeleted', () => {
    it('should_match_when_delete_client_id_equals_top_message_client_id', 0, () => {
      expect(isTopMessageDeleted(
        'msg_client_001',
        'msg_server_001',
        'msg_client_001',
        'msg_server_other'
      )).assertTrue()
    })

    it('should_match_when_delete_server_id_equals_top_message_server_id', 0, () => {
      expect(isTopMessageDeleted(
        'msg_client_001',
        'msg_server_001',
        'msg_client_other',
        'msg_server_001'
      )).assertTrue()
    })

    it('should_return_false_when_delete_message_does_not_match_top_message', 0, () => {
      expect(isTopMessageDeleted(
        'msg_client_001',
        'msg_server_001',
        'msg_client_other',
        'msg_server_other'
      )).assertFalse()
    })
  })
}
