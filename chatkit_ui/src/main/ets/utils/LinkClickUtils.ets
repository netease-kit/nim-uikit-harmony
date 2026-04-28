/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { call } from '@kit.TelephonyKit'
import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { LinkInfo, LinkType } from './TextLinkifyUtils'

/**
 * 链接点击处理工具类
 * 处理邮箱、URL、电话号码的点击事件
 * 对齐 Android chatkit-ui MessageClickUtils.java
 */
export class LinkClickUtils {
  /**
   * 处理链接点击
   * @param context 上下文
   * @param linkInfo 链接信息
   */
  static handleLinkClick(context: common.UIAbilityContext, linkInfo: LinkInfo): void {
    switch (linkInfo.type) {
      case LinkType.EMAIL:
        LinkClickUtils.handleEmailClick(context, linkInfo.text)
        break
      case LinkType.URL:
        LinkClickUtils.handleUrlClick(context, linkInfo.url)
        break
      case LinkType.PHONE:
        LinkClickUtils.handlePhoneClick(context, linkInfo.text.replace(/[\s-]/g, ''))
        break
    }
  }

  /**
   * 处理邮箱点击 - 显示操作菜单（发送邮件/复制邮箱/取消）
   * @param context 上下文
   * @param email 邮箱地址
   */
  static handleEmailClick(context: common.UIAbilityContext, email: string): void {
    promptAction.showActionMenu({
      title: `向"${email}"发送邮件`,
      buttons: [
        { text: '使用默认邮件账户', color: '#337EFF' },
        { text: '复制邮箱', color: '#337EFF' }
      ]
    }).then((result) => {
      if (result.index === 0) {
        // 发送邮件
        LinkClickUtils.openEmailApp(context, email)
      } else if (result.index === 1) {
        // 复制邮箱
        LinkClickUtils.copyToClipboard(email)
      }
      // 取消按钮由系统自动处理，无需额外代码
    }).catch((err: BusinessError) => {
      // 用户点击取消或空白区域关闭菜单，不需要报错
      if (err.code !== 100001) { // 100001 = 用户取消
        console.error(`[LinkClickUtils] Email action menu error: ${err.message}`)
      }
    })
  }

  /**
   * 打开邮件应用发送邮件
   * @param context 上下文
   * @param email 邮箱地址
   */
  static openEmailApp(context: common.UIAbilityContext, email: string): void {
    const want: Want = {
      action: 'ohos.want.action.sendToData',
      uri: `mailto:${email}`,
      type: 'text/plain'
    }

    try {
      context.startAbility(want).catch((err: BusinessError) => {
        // startAbility 返回 Promise，需要处理 catch
        console.error(`[LinkClickUtils] Failed to open email app: ${err.message}`)
        // 根据错误码判断是否未安装邮箱应用
        if (err.code === 16000001 || err.code === 16000002) {
          // 16000001: Ability not found, 16000002: Ability is invalid
          promptAction.showToast({
            message: '未检测到邮箱应用',
            duration: 2000
          })
        } else {
          promptAction.showToast({
            message: '无法打开邮件应用',
            duration: 2000
          })
        }
      })
    } catch (error) {
      const err = error as BusinessError
      console.error(`[LinkClickUtils] Failed to open email app: ${err.message}`)
      promptAction.showToast({
        message: '未检测到邮箱应用',
        duration: 2000
      })
    }
  }

  /**
   * 处理 URL 点击 - 打开浏览器
   * @param context 上下文
   * @param url URL 地址
   */
  static handleUrlClick(context: common.UIAbilityContext, url: string): void {
    // 如果 URL 以 www. 开头但没有协议，自动添加 https://
    let finalUrl = url
    if (url.toLowerCase().startsWith('www.')) {
      finalUrl = `https://${url}`
    }

    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: finalUrl
    }

    try {
      context.startAbility(want)
    } catch (error) {
      const err = error as BusinessError
      console.error(`[LinkClickUtils] Failed to open browser: ${err.message}`)
      promptAction.showToast({
        message: '无法打开浏览器',
        duration: 2000
      })
    }
  }

  /**
   * 处理电话号码点击 - 显示操作菜单
   * @param context 上下文
   * @param phoneNumber 电话号码
   */
  static handlePhoneClick(context: common.UIAbilityContext, phoneNumber: string): void {
    promptAction.showActionMenu({
      title: `"${phoneNumber}"可能是一个电话号码，你可以`,
      buttons: [
        { text: '呼叫', color: '#007AFF' },
        { text: '复制', color: '#007AFF' }
      ]
    }).then((result) => {
      if (result.index === 0) {
        // 拨打电话
        LinkClickUtils.dialPhone(context, phoneNumber)
      } else if (result.index === 1) {
        // 复制号码
        LinkClickUtils.copyToClipboard(phoneNumber)
      }
    }).catch((err: BusinessError) => {
      console.error(`[LinkClickUtils] Action menu error: ${err.message}`)
    })
  }

  /**
   * 拨打电话（打开拨号界面）
   * @param context 上下文
   * @param phoneNumber 电话号码
   */
  static dialPhone(context: common.UIAbilityContext, phoneNumber: string): void {
    call.makeCall(phoneNumber).then(() => {
      console.info('[LinkClickUtils] Make call success')
    }).catch((err: BusinessError) => {
      console.error(`[LinkClickUtils] Make call failed: ${err.message}`)
      // 如果 makeCall 失败，尝试使用 startAbility
      const want: Want = {
        action: 'ohos.want.action.dial',
        uri: `tel:${phoneNumber}`
      }
      try {
        context.startAbility(want)
      } catch (error) {
        const startErr = error as BusinessError
        console.error(`[LinkClickUtils] Start dial activity failed: ${startErr.message}`)
        promptAction.showToast({
          message: '无法拨打电话',
          duration: 2000
        })
      }
    })
  }

  /**
   * 复制文本到剪贴板
   * @param text 要复制的文本
   */
  static copyToClipboard(text: string): void {
    import('@ohos.pasteboard').then((pasteboard) => {
      const pasteData = pasteboard.default.createData(pasteboard.default.MIMETYPE_TEXT_PLAIN, text)
      const systemPasteboard = pasteboard.default.getSystemPasteboard()
      systemPasteboard.setData(pasteData).then(() => {
        promptAction.showToast({
          message: '已复制到剪贴板',
          duration: 2000
        })
      }).catch((err: BusinessError) => {
        console.error(`[LinkClickUtils] Copy to clipboard failed: ${err.message}`)
      })
    })
  }
}
