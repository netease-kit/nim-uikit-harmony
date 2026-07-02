/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatInfo } from '../model/ChatInfo'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { getVideoMessageThumbnail } from '../common/MessageHelper'
import { image } from '@kit.ImageKit'
import {
  getTopMessageSenderName,
  getTopMessageSummary,
  getTopMessageVideoPreviewUrl,
  isTopMessageImage,
  isTopMessageVideo
} from '../utils/TopMessageBarUtils'

/**
 * 置顶消息横幅组件
 * 显示在群聊消息列表上方，展示置顶消息摘要
 */
@ComponentV2
export struct TopMessageBar {
  /** 置顶消息 */
  @Param topMessage: NIMMessageInfo | undefined = undefined
  /** 聊天对象信息，用于展示发送者昵称 */
  @Param chatInfo: ChatInfo | undefined = undefined
  /** 是否有置顶操作权限（控制关闭按钮可见性） */
  @Param hasTopPermission: boolean = false
  /** 点击横幅回调（滚动到置顶消息位置） */
  @Param onBarClick: () => void = () => {}
  /** 点击关闭按钮回调（移除置顶） */
  @Param onBarClose: () => void = () => {}
  /** 图片消息缩略图 */
  @Local imageThumbUrl: string = ''
  /** 视频消息缩略图 */
  @Local videoMessageThumbnail?: image.PixelMap
  /** 视频消息远端首帧 */
  @Local videoPreviewUrl: string = ''

  /**
   * 获取消息摘要文本
   */
  private getMessageSummary(): string {
    return getTopMessageSummary(this.topMessage)
  }

  /**
   * 获取发送者显示名称
   */
  private getSenderName(): string {
    const senderId = this.topMessage?.message.senderId ?? ''
    const senderName = senderId.length > 0 ? this.chatInfo?.getChatUserShowName(senderId) : ''
    return getTopMessageSenderName(senderId, senderName)
  }

  aboutToAppear(): void {
    this.loadPreview()
  }

  @Monitor('topMessage')
  onTopMessageChange() {
    this.loadPreview()
  }

  private loadPreview() {
    this.imageThumbUrl = ''
    this.videoMessageThumbnail = undefined
    this.videoPreviewUrl = ''

    const currentMessage = this.topMessage
    if (!currentMessage) {
      return
    }

    if (isTopMessageImage(currentMessage)) {
      currentMessage.getImageThumbUrl().then((thumbUrl) => {
        if (this.topMessage?.message.messageClientId === currentMessage.message.messageClientId) {
          this.imageThumbUrl = thumbUrl
        }
      }).catch((err: Error) => {
        Logger.debug('ChatKitUI', 'netease top message image thumb failed:', err.message)
      })
      return
    }

    if (isTopMessageVideo(currentMessage)) {
      this.videoPreviewUrl = getTopMessageVideoPreviewUrl(currentMessage)
      getVideoMessageThumbnail(currentMessage).then((thumbnail) => {
        if (this.topMessage?.message.messageClientId === currentMessage.message.messageClientId) {
          this.videoMessageThumbnail = thumbnail
        }
      }).catch((err: Error) => {
        Logger.debug('ChatKitUI', 'netease top message video thumb failed:', err.message)
      })
    }
  }

  @Builder
  private previewBuilder() {
    if (this.imageThumbUrl.length > 0) {
      Image(this.imageThumbUrl)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Cover)
        .borderRadius(4)
        .margin({ right: 6 })
    } else if (this.videoMessageThumbnail !== undefined) {
      Image(this.videoMessageThumbnail)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Cover)
        .borderRadius(4)
        .margin({ right: 6 })
    } else if (this.videoPreviewUrl.length > 0) {
      Image(this.videoPreviewUrl)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Cover)
        .borderRadius(4)
        .margin({ right: 6 })
    }
  }

  build() {
    if (this.topMessage) {
      Row() {
        // 置顶图标
        Image($r('app.media.ic_chat_top_sticky'))
          .width(12)
          .height(12)
          .margin({ right: 6 })

        this.previewBuilder()

        // 发送者昵称
        Text(this.getSenderName())
          .fontSize(12)
          .fontColor('#ff333333')
          .maxLines(1)
          .constraintSize({ maxWidth: 96 })
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(EllipsisMode.END)

        Text(': ')
          .fontSize(12)
          .fontColor('#ff333333')
          .margin({ right: 2 })

        // 消息内容摘要
        Text(this.getMessageSummary())
          .fontSize(12)
          .fontColor('#ff333333')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 关闭按钮（受权限控制）
        if (this.hasTopPermission) {
          Image($r('app.media.ic_chat_close'))
            .width(18)
            .height(18)
            .margin({ left: 6 })
            .fillColor('#ff999999')
            .onClick(() => {
              this.onBarClose()
            })
        }
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .margin({ left: 12, right: 12, top: 4, bottom: 4 })
      .borderRadius(8)
      .backgroundColor('#ffF5F8FC')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onBarClick()
      })
    }
  }
}
