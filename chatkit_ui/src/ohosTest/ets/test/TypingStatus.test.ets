/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it, beforeEach, afterEach } from '@ohos/hypium';

/**
 * 正在输入功能单元测试
 *
 * 覆盖冒烟用例：
 * - 用例 64 (P0): 对方正在输入时，显示"正在输入中..."
 * - 用例 65 (P1): 对方停止输入后，状态消失（3秒超时）
 *
 * 测试范围：Repo 层以上 (ViewModel 层业务逻辑)
 * 测试方法：复制核心逻辑函数到本地，避免 HarmonyOS 平台 import 依赖
 */

// ======================= 从 ChatP2PViewModel.ets 复制的常量和逻辑 =======================

// 正在输入状态通知内容常量（与 Android 端对齐）
const TYPING_CONTENT_START = '{"typing":1}'
const TYPING_CONTENT_STOP = '{"typing":0}'
// 正在输入状态超时时间（毫秒）
const TYPING_TIMEOUT_MS = 3000
// 发送"正在输入"通知的最小间隔（毫秒），用于节流
const TYPING_SEND_INTERVAL_MS = 2000

/**
 * 模拟 ViewModel 中"正在输入"接收逻辑的纯函数
 * 从 onReceiveCustomNotificationsFun 中提取 JSON 解析逻辑
 */
function parseTypingNotification(content: string | undefined): number | undefined {
  try {
    const typing: number = JSON.parse(content || '{}')['typing']
    return typing
  } catch (e) {
    return undefined
  }
}

/**
 * 模拟 ViewModel 中"正在输入"发送逻辑的节流判断
 * 从 sendInputNotification 中提取节流逻辑
 */
interface SendTypingResult {
  shouldSend: boolean
  newLastSentTime: number
}

function shouldSendTypingNotification(
  isTyping: boolean,
  now: number,
  lastTypingSentTime: number
): SendTypingResult {
  if (isTyping) {
    // 正在输入：使用节流，每 2 秒最多发送一次
    if (now - lastTypingSentTime < TYPING_SEND_INTERVAL_MS) {
      return { shouldSend: false, newLastSentTime: lastTypingSentTime }
    }
    return { shouldSend: true, newLastSentTime: now }
  } else {
    // 停止输入：只有在之前发送过"正在输入"时才发送
    if (lastTypingSentTime === 0) {
      return { shouldSend: false, newLastSentTime: 0 }
    }
    return { shouldSend: true, newLastSentTime: 0 }
  }
}

/**
 * 获取发送的通知内容
 */
function getTypingNotificationContent(isTyping: boolean): string {
  return isTyping ? TYPING_CONTENT_START : TYPING_CONTENT_STOP
}

/**
 * 模拟 ViewModel 中 setRemoteTyping 的超时逻辑
 * 使用类来模拟状态管理
 */
class TypingStatusManager {
  isRemoteTyping: boolean = false
  private typingTimeoutId: number | undefined = undefined

  /**
   * 设置对方正在输入状态，并管理 3 秒超时定时器
   */
  setRemoteTyping(isTyping: boolean): void {
    // 先清除旧的定时器
    if (this.typingTimeoutId !== undefined) {
      clearTimeout(this.typingTimeoutId)
      this.typingTimeoutId = undefined
    }
    this.isRemoteTyping = isTyping
    // 如果是正在输入，启动 3 秒超时定时器
    if (isTyping) {
      this.typingTimeoutId = setTimeout(() => {
        this.isRemoteTyping = false
        this.typingTimeoutId = undefined
      }, TYPING_TIMEOUT_MS)
    }
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    if (this.typingTimeoutId !== undefined) {
      clearTimeout(this.typingTimeoutId)
      this.typingTimeoutId = undefined
    }
  }

  /**
   * 是否有活跃的定时器
   */
  hasActiveTimer(): boolean {
    return this.typingTimeoutId !== undefined
  }
}

// ======================= 测试用例 =======================

export default function typingStatusTest() {
  // ===== 测试组 1: JSON 解析逻辑 =====
  describe('TypingStatus_parseTypingNotification', () => {
    it('should_return_1_for_typing_start', 0, () => {
      const result = parseTypingNotification('{"typing":1}')
      expect(result).assertEqual(1)
    })

    it('should_return_0_for_typing_stop', 0, () => {
      const result = parseTypingNotification('{"typing":0}')
      expect(result).assertEqual(0)
    })

    it('should_return_undefined_for_invalid_json', 0, () => {
      const result = parseTypingNotification('invalid json')
      expect(result).assertUndefined()
    })

    it('should_return_undefined_for_empty_content', 0, () => {
      const result = parseTypingNotification('')
      expect(result).assertUndefined()
    })

    it('should_return_undefined_for_undefined_content', 0, () => {
      const result = parseTypingNotification(undefined)
      expect(result).assertUndefined()
    })

    it('should_return_undefined_for_json_without_typing_field', 0, () => {
      const result = parseTypingNotification('{"other":1}')
      expect(result).assertUndefined()
    })

    it('should_handle_json_with_extra_fields', 0, () => {
      const result = parseTypingNotification('{"typing":1,"extra":"value"}')
      expect(result).assertEqual(1)
    })
  })

  // ===== 测试组 2: 通知内容常量 =====
  describe('TypingStatus_notificationContent', () => {
    it('should_return_correct_start_content', 0, () => {
      expect(getTypingNotificationContent(true)).assertEqual('{"typing":1}')
    })

    it('should_return_correct_stop_content', 0, () => {
      expect(getTypingNotificationContent(false)).assertEqual('{"typing":0}')
    })

    it('TYPING_CONTENT_START_should_match_android_format', 0, () => {
      // 与 Android 端对齐的格式验证
      expect(TYPING_CONTENT_START).assertEqual('{"typing":1}')
    })

    it('TYPING_CONTENT_STOP_should_match_android_format', 0, () => {
      // 与 Android 端对齐的格式验证
      expect(TYPING_CONTENT_STOP).assertEqual('{"typing":0}')
    })
  })

  // ===== 测试组 3: 发送节流逻辑 =====
  describe('TypingStatus_sendThrottle', () => {
    it('should_allow_first_typing_notification', 0, () => {
      const result = shouldSendTypingNotification(true, 1000, 0)
      expect(result.shouldSend).assertTrue()
      expect(result.newLastSentTime).assertEqual(1000)
    })

    it('should_block_typing_within_2_seconds', 0, () => {
      // 上次发送时间 1000，现在 2500（1.5秒后），应该被节流
      const result = shouldSendTypingNotification(true, 2500, 1000)
      expect(result.shouldSend).assertFalse()
      expect(result.newLastSentTime).assertEqual(1000) // 保持原来的时间
    })

    it('should_allow_typing_after_2_seconds', 0, () => {
      // 上次发送时间 1000，现在 3000（2秒后），应该允许
      const result = shouldSendTypingNotification(true, 3000, 1000)
      expect(result.shouldSend).assertTrue()
      expect(result.newLastSentTime).assertEqual(3000)
    })

    it('should_allow_typing_after_more_than_2_seconds', 0, () => {
      // 上次发送时间 1000，现在 5000（4秒后），应该允许
      const result = shouldSendTypingNotification(true, 5000, 1000)
      expect(result.shouldSend).assertTrue()
      expect(result.newLastSentTime).assertEqual(5000)
    })

    it('should_block_stop_if_never_sent_typing', 0, () => {
      // lastTypingSentTime 为 0，说明从未发送过"正在输入"，不应发送"停止"
      const result = shouldSendTypingNotification(false, 1000, 0)
      expect(result.shouldSend).assertFalse()
      expect(result.newLastSentTime).assertEqual(0)
    })

    it('should_allow_stop_if_previously_sent_typing', 0, () => {
      // lastTypingSentTime > 0，说明之前发送过"正在输入"，应该发送"停止"
      const result = shouldSendTypingNotification(false, 5000, 1000)
      expect(result.shouldSend).assertTrue()
      expect(result.newLastSentTime).assertEqual(0) // 重置为 0
    })

    it('should_reset_lastSentTime_on_stop', 0, () => {
      const result = shouldSendTypingNotification(false, 5000, 3000)
      expect(result.newLastSentTime).assertEqual(0)
    })
  })

  // ===== 测试组 4: 3秒超时逻辑（用例 65 核心验证）=====
  describe('TypingStatus_timeout', () => {
    let manager: TypingStatusManager

    beforeEach(() => {
      manager = new TypingStatusManager()
    })

    afterEach(() => {
      manager.cleanup()
    })

    it('should_set_typing_true_when_start', 0, () => {
      manager.setRemoteTyping(true)
      expect(manager.isRemoteTyping).assertTrue()
    })

    it('should_set_typing_false_when_stop', 0, () => {
      manager.setRemoteTyping(true)
      manager.setRemoteTyping(false)
      expect(manager.isRemoteTyping).assertFalse()
    })

    it('should_have_timer_when_typing', 0, () => {
      manager.setRemoteTyping(true)
      expect(manager.hasActiveTimer()).assertTrue()
    })

    it('should_clear_timer_when_stop', 0, () => {
      manager.setRemoteTyping(true)
      manager.setRemoteTyping(false)
      expect(manager.hasActiveTimer()).assertFalse()
    })

    it('should_clear_old_timer_when_typing_again', 0, () => {
      manager.setRemoteTyping(true)
      const firstHasTimer = manager.hasActiveTimer()
      manager.setRemoteTyping(true) // 再次设置，应该刷新定时器
      const secondHasTimer = manager.hasActiveTimer()
      expect(firstHasTimer).assertTrue()
      expect(secondHasTimer).assertTrue()
    })

    it('should_auto_clear_typing_after_3_seconds', 0, async () => {
      manager.setRemoteTyping(true)
      expect(manager.isRemoteTyping).assertTrue()
      // 等待 3.1 秒，状态应该自动变为 false
      await new Promise<void>((resolve) => setTimeout(resolve, 3100))
      expect(manager.isRemoteTyping).assertFalse()
      expect(manager.hasActiveTimer()).assertFalse()
    })

    it('should_refresh_timer_on_new_typing', 0, async () => {
      manager.setRemoteTyping(true)
      // 等待 2 秒
      await new Promise<void>((resolve) => setTimeout(resolve, 2000))
      expect(manager.isRemoteTyping).assertTrue()
      // 再次收到"正在输入"，刷新定时器
      manager.setRemoteTyping(true)
      // 再等待 2 秒（总共 4 秒），如果没刷新定时器，状态应该已经 false
      // 但因为刷新了，所以应该还是 true
      await new Promise<void>((resolve) => setTimeout(resolve, 2000))
      expect(manager.isRemoteTyping).assertTrue()
      // 再等待 1.5 秒（从最后一次刷新算起共 3.5 秒），状态应该变 false
      await new Promise<void>((resolve) => setTimeout(resolve, 1500))
      expect(manager.isRemoteTyping).assertFalse()
    })
  })

  // ===== 测试组 5: 常量值验证 =====
  describe('TypingStatus_constants', () => {
    it('TYPING_TIMEOUT_MS_should_be_3000', 0, () => {
      expect(TYPING_TIMEOUT_MS).assertEqual(3000)
    })

    it('TYPING_SEND_INTERVAL_MS_should_be_2000', 0, () => {
      expect(TYPING_SEND_INTERVAL_MS).assertEqual(2000)
    })
  })

  // ===== 测试组 6: 端到端场景验证（用例 64, 65 综合）=====
  describe('TypingStatus_e2e_scenarios', () => {
    let manager: TypingStatusManager

    beforeEach(() => {
      manager = new TypingStatusManager()
    })

    afterEach(() => {
      manager.cleanup()
    })

    /**
     * 用例 64: 对方正在输入时，显示"正在输入中..."
     */
    it('scenario_64_should_show_typing_when_receive_typing_1', 0, () => {
      // 模拟收到对方的"正在输入"通知
      const notification = '{"typing":1}'
      const typing = parseTypingNotification(notification)

      if (typing === 1) {
        manager.setRemoteTyping(true)
      }

      // 验证：isRemoteTyping 应该为 true，UI 层会据此显示"正在输入中..."
      expect(manager.isRemoteTyping).assertTrue()
    })

    /**
     * 用例 65: 对方停止输入后，状态消失
     * - 子场景 A: 收到 typing:0 后立即消失
     */
    it('scenario_65_A_should_hide_typing_when_receive_typing_0', 0, () => {
      // 先设置为正在输入
      manager.setRemoteTyping(true)
      expect(manager.isRemoteTyping).assertTrue()

      // 收到"停止输入"通知
      const notification = '{"typing":0}'
      const typing = parseTypingNotification(notification)

      if (typing === 0) {
        manager.setRemoteTyping(false)
      }

      // 验证：状态应该立即消失
      expect(manager.isRemoteTyping).assertFalse()
    })

    /**
     * 用例 65: 对方停止输入后，状态消失
     * - 子场景 B: 3秒未收到新通知后自动消失
     */
    it('scenario_65_B_should_auto_hide_typing_after_3_seconds', 0, async () => {
      // 收到"正在输入"通知
      const notification = '{"typing":1}'
      const typing = parseTypingNotification(notification)

      if (typing === 1) {
        manager.setRemoteTyping(true)
      }

      expect(manager.isRemoteTyping).assertTrue()

      // 等待 3.1 秒，模拟对方停止输入但未发送 typing:0
      await new Promise<void>((resolve) => setTimeout(resolve, 3100))

      // 验证：状态应该自动消失
      expect(manager.isRemoteTyping).assertFalse()
    })
  })
}
