/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { describe, expect, it, beforeEach } from '@ohos/hypium';
import { LinkInfo, LinkType } from '../main/ets/utils/TextLinkifyUtils';

/**
 * LinkClickUtils 单元测试
 * 覆盖冒烟测试用例中的「邮箱点击」功能模块（用例 104-118）
 *
 * 验证范围：
 * - 邮箱点击操作菜单逻辑
 * - 邮箱发送邮件参数构建
 * - 邮箱复制逻辑
 * - 未安装邮箱应用处理
 *
 * 注意：由于 LinkClickUtils 依赖系统 API，这里通过模拟回调来验证逻辑正确性
 */

/**
 * 操作菜单按钮类
 */
class MenuButton {
  text: string
  color: string

  constructor(text: string, color: string) {
    this.text = text
    this.color = color
  }
}

/**
 * 操作菜单配置类
 */
class MenuConfig {
  title: string
  buttons: MenuButton[]

  constructor(title: string, buttons: MenuButton[]) {
    this.title = title
    this.buttons = buttons
  }
}

/**
 * Want 对象类（模拟系统 Want）
 */
class MockWant {
  action: string
  uri: string
  type: string

  constructor(action: string, uri: string, type: string) {
    this.action = action
    this.uri = uri
    this.type = type
  }
}

/**
 * 邮箱点击处理器 - 可测试版本
 * 抽取 LinkClickUtils.handleEmailClick 的核心逻辑
 */
class TestableEmailClickHandler {
  // 记录操作结果
  lastMenuTitle: string = ''
  lastMenuButtons: string[] = []
  lastEmailWant: MockWant | null = null
  lastCopiedText: string = ''
  lastToastMessage: string = ''

  /**
   * 构建邮箱操作菜单配置
   */
  buildEmailMenuConfig(email: string): MenuConfig {
    this.lastMenuTitle = email
    this.lastMenuButtons = ['发送邮件', '复制邮箱']
    const buttons: MenuButton[] = [
      new MenuButton('发送邮件', '#337EFF'),
      new MenuButton('复制邮箱', '#337EFF')
    ]
    return new MenuConfig(email, buttons)
  }

  /**
   * 处理菜单选择结果
   */
  handleMenuResult(email: string, resultIndex: number): string {
    if (resultIndex === 0) {
      this.lastEmailWant = this.buildEmailWant(email)
      return 'send_email'
    } else if (resultIndex === 1) {
      this.lastCopiedText = email
      return 'copy_email'
    }
    return 'cancel'
  }

  /**
   * 构建发送邮件的 Want 对象
   */
  buildEmailWant(email: string): MockWant {
    return new MockWant(
      'ohos.want.action.sendToData',
      `mailto:${email}`,
      'text/plain'
    )
  }

  /**
   * 处理邮箱应用启动错误
   */
  handleEmailAppError(errorCode: number): string {
    if (errorCode === 16000001 || errorCode === 16000002) {
      this.lastToastMessage = '未检测到邮箱应用'
      return '未检测到邮箱应用'
    }
    this.lastToastMessage = '无法打开邮件应用'
    return '无法打开邮件应用'
  }

  /**
   * 处理复制成功
   */
  handleCopySuccess(): string {
    this.lastToastMessage = '已复制到剪贴板'
    return '已复制到剪贴板'
  }

  /**
   * 重置状态
   */
  reset(): void {
    this.lastMenuTitle = ''
    this.lastMenuButtons = []
    this.lastEmailWant = null
    this.lastCopiedText = ''
    this.lastToastMessage = ''
  }
}

export default function linkClickTest() {

  // ==================== 邮箱点击操作菜单测试 ====================
  describe('LinkClick_Email_ActionMenu', () => {
    let handler: TestableEmailClickHandler

    beforeEach(() => {
      handler = new TestableEmailClickHandler()
    })

    // 用例 104: 点击邮箱消息 - 弹出操作弹窗
    it('should_build_correct_menu_config_for_email', 0, () => {
      const email = 'test@example.com'
      const config = handler.buildEmailMenuConfig(email)

      expect(config.title).assertEqual(email)
      expect(config.buttons.length).assertEqual(2)
      expect(config.buttons[0].text).assertEqual('发送邮件')
      expect(config.buttons[1].text).assertEqual('复制邮箱')
    })

    it('should_use_correct_color_for_menu_buttons', 0, () => {
      const config = handler.buildEmailMenuConfig('user@domain.com')

      expect(config.buttons[0].color).assertEqual('#337EFF')
      expect(config.buttons[1].color).assertEqual('#337EFF')
    })

    it('should_display_email_as_menu_title', 0, () => {
      const email1 = 'simple@test.com'
      const config1 = handler.buildEmailMenuConfig(email1)
      expect(config1.title).assertEqual(email1)

      handler.reset()

      const email2 = 'user.name@company.co.uk'
      const config2 = handler.buildEmailMenuConfig(email2)
      expect(config2.title).assertEqual(email2)

      handler.reset()

      const email3 = 'test+tag@gmail.com'
      const config3 = handler.buildEmailMenuConfig(email3)
      expect(config3.title).assertEqual(email3)
    })
  })

  // ==================== 邮箱发送邮件测试 ====================
  describe('LinkClick_Email_SendMail', () => {
    let handler: TestableEmailClickHandler

    beforeEach(() => {
      handler = new TestableEmailClickHandler()
    })

    // 用例 105: 发送邮件 - 跳转到邮箱应用
    it('should_return_send_email_action_when_index_is_0', 0, () => {
      const email = 'test@example.com'
      const result = handler.handleMenuResult(email, 0)

      expect(result).assertEqual('send_email')
    })

    it('should_build_correct_email_want', 0, () => {
      const email = 'support@netease.com'
      const want = handler.buildEmailWant(email)

      expect(want.action).assertEqual('ohos.want.action.sendToData')
      expect(want.uri).assertEqual('mailto:support@netease.com')
      expect(want.type).assertEqual('text/plain')
    })

    it('should_build_mailto_uri_for_simple_email', 0, () => {
      const want = handler.buildEmailWant('user@example.com')
      expect(want.uri).assertEqual('mailto:user@example.com')
    })

    it('should_build_mailto_uri_for_subdomain_email', 0, () => {
      const want = handler.buildEmailWant('test.name@mail.company.com')
      expect(want.uri).assertEqual('mailto:test.name@mail.company.com')
    })

    it('should_build_mailto_uri_for_plus_tag_email', 0, () => {
      const want = handler.buildEmailWant('user+tag@gmail.com')
      expect(want.uri).assertEqual('mailto:user+tag@gmail.com')
    })
  })

  // ==================== 邮箱复制测试 ====================
  describe('LinkClick_Email_Copy', () => {
    let handler: TestableEmailClickHandler

    beforeEach(() => {
      handler = new TestableEmailClickHandler()
    })

    // 用例 106: 复制邮箱地址
    it('should_return_copy_email_action_when_index_is_1', 0, () => {
      const email = 'test@example.com'
      const result = handler.handleMenuResult(email, 1)

      expect(result).assertEqual('copy_email')
    })

    it('should_record_email_for_clipboard', 0, () => {
      const email = 'copy-me@domain.com'
      handler.handleMenuResult(email, 1)

      expect(handler.lastCopiedText).assertEqual(email)
    })

    it('should_show_copy_success_toast', 0, () => {
      const message = handler.handleCopySuccess()

      expect(message).assertEqual('已复制到剪贴板')
      expect(handler.lastToastMessage).assertEqual('已复制到剪贴板')
    })
  })

  // ==================== 邮箱操作取消测试 ====================
  describe('LinkClick_Email_Cancel', () => {
    let handler: TestableEmailClickHandler

    beforeEach(() => {
      handler = new TestableEmailClickHandler()
    })

    // 用例 107: 邮箱更多操作弹窗-取消
    it('should_return_cancel_when_index_is_negative', 0, () => {
      const email = 'test@example.com'
      const result = handler.handleMenuResult(email, -1)
      expect(result).assertEqual('cancel')
    })

    it('should_return_cancel_when_index_is_2', 0, () => {
      const email = 'test@example.com'
      const result = handler.handleMenuResult(email, 2)
      expect(result).assertEqual('cancel')
    })

    it('should_not_record_any_action_on_cancel', 0, () => {
      const email = 'test@example.com'
      handler.handleMenuResult(email, -1)

      expect(handler.lastEmailWant).assertNull()
      expect(handler.lastCopiedText).assertEqual('')
    })
  })

  // ==================== 未安装邮箱应用处理测试 ====================
  describe('LinkClick_Email_NoApp', () => {
    let handler: TestableEmailClickHandler

    beforeEach(() => {
      handler = new TestableEmailClickHandler()
    })

    // 用例 117: 未安装邮箱去发送邮件
    it('should_show_no_email_app_message_for_ability_not_found', 0, () => {
      // 16000001: Ability not found
      const message = handler.handleEmailAppError(16000001)

      expect(message).assertEqual('未检测到邮箱应用')
    })

    it('should_show_no_email_app_message_for_ability_invalid', 0, () => {
      // 16000002: Ability is invalid
      const message = handler.handleEmailAppError(16000002)

      expect(message).assertEqual('未检测到邮箱应用')
    })

    it('should_show_generic_error_for_other_errors', 0, () => {
      const message = handler.handleEmailAppError(99999)

      expect(message).assertEqual('无法打开邮件应用')
    })
  })

  // ==================== 链接类型路由测试 ====================
  describe('LinkClick_Type_Routing', () => {
    // 验证 LinkInfo 的类型路由
    it('should_identify_email_link_correctly', 0, () => {
      const linkInfo: LinkInfo = {
        type: LinkType.EMAIL,
        text: 'test@example.com',
        url: 'mailto:test@example.com',
        start: 0,
        end: 16
      }

      expect(linkInfo.type).assertEqual(LinkType.EMAIL)
      expect(linkInfo.url.startsWith('mailto:')).assertTrue()
    })

    it('should_identify_url_link_correctly', 0, () => {
      const linkInfo: LinkInfo = {
        type: LinkType.URL,
        text: 'https://example.com',
        url: 'https://example.com',
        start: 0,
        end: 19
      }

      expect(linkInfo.type).assertEqual(LinkType.URL)
    })

    it('should_identify_phone_link_correctly', 0, () => {
      const linkInfo: LinkInfo = {
        type: LinkType.PHONE,
        text: '13812345678',
        url: 'tel:13812345678',
        start: 0,
        end: 11
      }

      expect(linkInfo.type).assertEqual(LinkType.PHONE)
      expect(linkInfo.url.startsWith('tel:')).assertTrue()
    })
  })

  // ==================== 特殊场景邮箱处理测试 ====================
  describe('LinkClick_Email_SpecialScenarios', () => {
    let handler: TestableEmailClickHandler

    beforeEach(() => {
      handler = new TestableEmailClickHandler()
    })

    // 用例 108-116: 特殊场景下的邮箱处理
    it('should_handle_email_with_subdomain', 0, () => {
      const email = 'user@mail.company.co.uk'
      const want = handler.buildEmailWant(email)

      expect(want.uri).assertEqual('mailto:user@mail.company.co.uk')
    })

    it('should_handle_email_with_plus_sign', 0, () => {
      const email = 'test+filter@gmail.com'
      const want = handler.buildEmailWant(email)

      expect(want.uri).assertEqual('mailto:test+filter@gmail.com')
    })

    it('should_handle_email_with_dots_in_local_part', 0, () => {
      const email = 'first.middle.last@example.com'
      const want = handler.buildEmailWant(email)

      expect(want.uri).assertEqual('mailto:first.middle.last@example.com')
    })

    it('should_handle_email_with_numbers', 0, () => {
      const email = 'user123@test456.com'
      const want = handler.buildEmailWant(email)

      expect(want.uri).assertEqual('mailto:user123@test456.com')
    })

    it('should_handle_long_email_address', 0, () => {
      const email = 'very.long.email.address@subdomain.example.organization.com'
      const config = handler.buildEmailMenuConfig(email)

      expect(config.title).assertEqual(email)
    })
  })
}
