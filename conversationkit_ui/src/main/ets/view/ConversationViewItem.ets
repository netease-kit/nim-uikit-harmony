/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, CustomMessageUtils, getMultiLinePreviewFromAttachment, IMKitConfigCenter, mergedMessageCustomType, multiLineMessageCustomType } from '@nimkit/chatkit';
import { AvatarColorUntil, AvatarItem, CommonAvatar, shouldOpenContextAction } from '@nimkit/common';
import { DateUtil } from '@nimkit/common';
import { V2NIMConversationType, V2NIMMessageCallAttachment, V2NIMMessageType } from '@nimsdk/base';
import { ConversationItem } from '../strategy/ConversationStrategy';


// 会话行内同步读取的资源字符串缓存（键为 resourceId），避免滚动时每行都走一次同步资源读取
const BOT_PREFIX_STRING_CACHE: Map<number, string> = new Map<number, string>()

export enum ConversationContextAction {
  STICK_TOP = 'stickTop',
  UNSTICK_TOP = 'unstickTop',
  MUTE = 'mute',
  UNMUTE = 'unmute',
  DELETE = 'delete'
}

export function resolveConversationContextActions(stickTop: boolean, mute: boolean): ConversationContextAction[] {
  return [stickTop ? ConversationContextAction.UNSTICK_TOP : ConversationContextAction.STICK_TOP,
    mute ? ConversationContextAction.UNMUTE : ConversationContextAction.MUTE,
    ConversationContextAction.DELETE]
}

export function resolveConversationItemBackground(isSelected: boolean, stickTop: boolean,
  isHovered: boolean = false): string {
  if (isSelected || isHovered) {
    return '#E6F0FF'
  }
  return stickTop ? '#ffF3F5F7' : '#ffffffff'
}

@ComponentV2
export struct ConversationViewItem {
  @Param conversationInfo: ConversationItem | null = null
  @Param avatarName: string = ''
  @Param haveBeanAit: boolean = false
  @Param isUserAIBot: boolean = false
  @Param isAIUser: boolean = false
  @Param onItemClick?: () => void | undefined = undefined
  @Param onlineState: boolean = false
  @Param isSelected: boolean = false
  @Param onContextAction?: (action: string) => void = undefined
  @Local isHovered: boolean = false
  @Local menuVisible: boolean = false
  /**
   * 头像数据保持同一个实例：列表项因选中态/悬停态重渲染时，如果这里每次都 new 一个 AvatarItem，
   * CommonAvatar 的 @Param item 引用就会变化，触发头像子树重建（Image 重新挂载、首帧空白），
   * 表现为切换会话时头像闪烁。这里只在会话数据或显示名真正变化时重建。
   */
  @Local avatarItem: AvatarItem = new AvatarItem('', '', Color.Transparent)

  @Builder
  private contextMenuBuilder() {
    Column({ space: 16 }) {
      Row() {
        Image($r('app.media.ic_conversation_pin'))
          .width(14)
          .height(14)
        Text(this.conversationInfo?.stickTop ? $r('app.string.unstick_top_conversation') :
          $r('app.string.stick_top_conversation'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }
      .width('100%')
      .onClick(() => {
        this.closeContextMenu()
        this.onContextAction?.(this.conversationInfo?.stickTop ?
          ConversationContextAction.UNSTICK_TOP : ConversationContextAction.STICK_TOP)
      })

      Row() {
        Image(this.conversationInfo?.mute ? $r('app.media.ic_conversation_unmute') :
          $r('app.media.ic_conversation_mute'))
          .width(14)
          .height(14)
        Text(this.conversationInfo?.mute ? $r('app.string.cancel_mute_conversation') :
          $r('app.string.start_mute_conversation'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }
      .width('100%')
      .onClick(() => {
        this.closeContextMenu()
        this.onContextAction?.(this.conversationInfo?.mute ?
          ConversationContextAction.UNMUTE : ConversationContextAction.MUTE)
      })

      Row() {
        Image($r('app.media.ic_conversation_delete'))
          .width(14)
          .height(14)
        Text($r('app.string.delete_conversation'))
          .fontSize(14)
          .fontColor('#ff333333')
          .margin({ left: 6 })
      }
      .width('100%')
      .onClick(() => {
        this.closeContextMenu()
        this.onContextAction?.(ConversationContextAction.DELETE)
      })
    }
    .width(122)
    .padding({
      top: 16,
      left: 16,
      bottom: 16
    })
    .alignItems(HorizontalAlign.Start)
    .borderRadius(8)
    .backgroundColor('#ffFFFFFF')
  }

  private closeContextMenu(): void {
    this.menuVisible = false
    this.isHovered = false
  }

  build() {
    if (this.conversationInfo !== null) {
      Row() {
        //头像
        Stack({
          alignContent: Alignment.TopEnd
        }) {
          CommonAvatar({
            item: this.avatarItem
          })

          //未读数显示
          RelativeContainer() {
            //未读数显示
            if (this.conversationInfo.unreadCount > 0) {
              if (this.conversationInfo.mute === true) {
                Column()
                  .width(8)
                  .height(8)
                  .borderRadius(4)
                  .backgroundColor('#ffF24957')
                  .alignRules({
                    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
                    'right': { 'anchor': '__container__', 'align': HorizontalAlign.End }
                  })
                  .offset({ x: 1, y: 1 })
              } else {
                Text(this.getUnreadCountStr(this.conversationInfo.unreadCount))
                  .fontSize(12)
                  .fontColor('#ffFFFFFF')
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#ffF24957')
                  .alignRules({
                    'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
                    'right': { 'anchor': '__container__', 'align': HorizontalAlign.End }
                  })
                  .borderRadius(20)
                  .height(18)
                  .width(18 +
                    (this.getUnreadCountStr(this.conversationInfo.unreadCount).length - 1) * 4)
                  .offset({ x: 1, y: 1 })
              }
            }
            //在线状态
            if (this.conversationInfo.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P &&
              !this.isUserAIBot &&
              !this.isAIUser &&
              IMKitConfigCenter.enableShownOnlineState) {
              Column()
                .width(8)
                .height(8)
                .borderRadius(4)
                .backgroundColor(this.onlineState ? '#84ED85' : '#D4D9DA')
                .alignRules({
                  'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
                  'right': { 'anchor': '__container__', 'align': HorizontalAlign.End }
                })
                .offset({ x: -1, y: -1 })
            }
          }
        }
        .width(42)
        .height(42)

        Column() {
          //item 显示名称
          Row() {
            Text(this.conversationInfo.name)
              .fontSize(16)
              .fontColor("#ff333333")
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
              .flexShrink(1)

            if (this.isUserAIBot) {
              Text($r('app.string.conversation_ai_badge'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .textAlign(TextAlign.Center)
                .height(16)
                .width(22)
                .linearGradient({
                  angle: 90,
                  colors: [['#FF9EFD', 0.0], ['#65ADFF', 1.0]]
                })
                .borderRadius(4)
                .margin({ left: 4 })
                .flexShrink(0)
            }
          }
          .width('100%')
          .margin({
            bottom: 8
          })

          Row() {
            if (this.haveBeanAit && this.conversationInfo.unreadCount > 0) {
              Text($r('app.string.conversation_have_ait'))
                .fontSize(13)
                .maxLines(1)
                .fontColor("#fff24957")
            }
            //item 最后一条消息显示
            Text(this.getConversationContent(this.conversationInfo))
              .fontSize(13)
              .maxLines(1)
              .fontColor("#ff999999")
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }.width(this.conversationInfo.mute ? '80%' : '100%')

        }
        // 中间列让出 4%：时间列需要 24% 才放得下最长的一行时间（三折窄栏下最紧）
        .width('56%')
        .margin({
          left: 12,
          right: 12
        }).alignItems(HorizontalAlign.Start)

        //时间戳和mute
        Column() {
          Text(DateUtil.formatTimestamp(this.conversationInfo.lastMessage?.messageRefer?.createTime ??
          this.conversationInfo.updateTime))
            .fontColor('#ffCCCCCC')
            .fontSize(12)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .alignSelf(ItemAlign.End)
            .margin({
              bottom: 8
            })

          //mute 状态显示
          if (this.conversationInfo.mute) {

            Image($r('app.media.conversation_mute'))
              .width(14)
              .height(14)
          }
        }
        // 时间列固定占 24% 且不参与压缩：一行完整时间最长形如「10-10 14:47」（12fp 约 75vp），
        // 三折会话栏只有约 333vp，24% 约 80vp 才够；之前占 20% 又可被压缩，窄窗口会把时间挤成两行。
        .width('24%')
        .flexShrink(0)
        .margin({
          right: 12
        }).alignItems(HorizontalAlign.End)

      }
      .width('100%')
      .height(62)
      .onClick(() => {
        // this.goToChatPage()
        if (this.onItemClick !== undefined) {
          this.onItemClick()
        }
      })
      .backgroundColor(resolveConversationItemBackground(this.isSelected, this.conversationInfo.stickTop,
        this.isHovered))
      .onHover((isHover: boolean) => {
        // 菜单弹出后指针会离开条目，这里保留高亮，保证能看出右键的是哪一个会话
        if (isHover || !this.menuVisible) {
          this.isHovered = isHover
        }
      })
      .onMouse((event: MouseEvent) => {
        if (shouldOpenContextAction(event.button, event.action)) {
          this.menuVisible = true
        }
      })
      .bindPopup(this.menuVisible, {
        builder: this.contextMenuBuilder,
        placement: Placement.Bottom,
        popupColor: Color.White,
        enableArrow: false,
        showInSubWindow: false,
        mask: true,
        autoCancel: true,
        onStateChange: (e) => {
          if (!e.isVisible) {
            this.closeContextMenu()
          }
        }
      })
      .padding({
        left: 20,
        top: 10,
        bottom: 10,
        right: 20
      })
    }

  }

  /**
   * 获取未读数展示
   * @param unreadCount
   * @returns
   */
  getUnreadCountStr(unreadCount: number): string {
    if (unreadCount < 100) {
      return unreadCount + ''
    } else {
      return '99+'
    }
  }

  /**
   * 头像只显示后两位
   * @param sourceName
   * @returns
   */
  aboutToAppear(): void {
    this.refreshAvatarItem()
  }

  @Monitor('conversationInfo', 'avatarName')
  onAvatarSourceChange(): void {
    this.refreshAvatarItem()
  }

  private refreshAvatarItem(): void {
    const conversation = this.conversationInfo
    const conversationId = conversation?.conversationId ?? ''
    const nextAvatar = conversation?.avatar
    const nextName = this.getAvatarShowName(this.avatarName || conversation?.name || '')
    // 头像地址与显示名都没变时保持原实例，避免会话列表刷新（未读数、置顶等）也触发头像重建
    if (this.avatarItem.avatarUrl?.toString() === nextAvatar?.toString() && this.avatarItem.name === nextName) {
      return
    }
    this.avatarItem = new AvatarItem(
      nextAvatar,
      nextName,
      AvatarColorUntil.getBackgroundColorById(
        conversationId.length > 0 ?
          ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId) : ''
      )
    )
  }

  getAvatarShowName(sourceName: string): string {
    let size = sourceName.length
    if (size <= 2) {
      return sourceName
    } else {
      return sourceName.substring(size - 2)
    }
  }

  /**
   * 获取会话列表展示的内容
   * @param item
   * @returns
   */
  getConversationContent(item: ConversationItem): string | Resource {
    if (!item.lastMessage) {
      return ''
    }
    const prefix = this.getBotSubSessionPrefix()

    switch (item.lastMessage?.messageType) {
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT:
        // 只返回第一行文本，避免多行文本导致会话列表显示省略号
        const text = item.lastMessage.text ?? ''
        const firstLineEnd = text.indexOf('\n')
        return prefix + (firstLineEnd === -1 ? text : text.substring(0, firstLineEnd))
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE:
        return this.withBotSubSessionPrefix($r('app.string.imageMessageType'))
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO:
        return this.withBotSubSessionPrefix($r('app.string.audioMessageType'))
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO:
        return this.withBotSubSessionPrefix($r('app.string.videoMessageType'))
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION:
        return this.withBotSubSessionPrefix($r('app.string.locationMessageType'))
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE:
        return this.withBotSubSessionPrefix($r('app.string.fileMessageType'))
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_NOTIFICATION:
        return this.withBotSubSessionPrefix($r('app.string.notificationMessageType'))
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_TIPS:
        return this.withBotSubSessionPrefix($r('app.string.tipMessageType'))
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL:
        if (item.lastMessage?.attachment) {
          const messageAttachment = item.lastMessage.attachment as V2NIMMessageCallAttachment
          if (messageAttachment.type == 1) {
            return this.withBotSubSessionPrefix($r('app.string.msg_type_rtc_audio'))
          } else {
            return this.withBotSubSessionPrefix($r('app.string.msg_type_rtc_video'))
          }
        }
        break
      case V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM:
        if (item.lastMessage?.attachment) {
          const customType = CustomMessageUtils.typeOfCustomMessage(item.lastMessage.attachment)
          if (customType === mergedMessageCustomType) {
            return this.withBotSubSessionPrefix($r('app.string.chat_merge_history'))
          }
          if (customType === multiLineMessageCustomType) {
            return prefix + getMultiLinePreviewFromAttachment(item.lastMessage?.attachment)
          }
        }
        break
    }
    return item.lastMessage?.text ? prefix + item.lastMessage.text : this.withBotSubSessionPrefix($r('app.string.chatMessageNonsupportType'))
  }

  private withBotSubSessionPrefix(resource: Resource): string | Resource {
    if (!this.isUserAIBot) {
      return resource
    }
    return this.getBotSubSessionPrefix() + this.getResourceStringCached(resource.id)
  }

  private getBotSubSessionPrefix(): string {
    if (!this.isUserAIBot) {
      return ''
    }
    return this.getResourceStringCached($r('app.string.conversation_bot_sub_session_prefix').id)
  }

  /**
   * 资源字符串缓存：getStringSync 是同步调用（每次都要走一次资源管理器），
   * 会话行滚动时会逐行触发，缓存后只在首次读取，避免首屏滑动卡顿。
   */
  private getResourceStringCached(resourceId: number): string {
    const cached = BOT_PREFIX_STRING_CACHE.get(resourceId)
    if (cached !== undefined) {
      return cached
    }
    const value = getContext().resourceManager.getStringSync(resourceId)
    BOT_PREFIX_STRING_CACHE.set(resourceId, value)
    return value
  }
}
