/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import { NEEmojiParseResult } from '../manager/NEEmojiManager'
import {
  V2NIMConversationType,
  V2NIMMessageFileAttachment,
  V2NIMMessageLocationAttachment,
  V2NIMMessageType
} from '@nimsdk/base'
import {
  formatVideoDuration,
  getAitNodes,
  getCallMessageIcon,
  getCallMessageText,
  getFileMessageIcon,
  getFileMessageName,
  getFileMessageSize,
  getImageHeight,
  getImageWidth,
  getReplyMessageText,
  getVideoDuration,
  getVideoMessageThumbnail,
  getVideoMessageUrl,
  parseMessageText,
  parseReplyMessageUserInfo,
  parseText,
  sliceMessageText
} from '../common/MessageHelper'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { MessageItemClick } from './MessageItemClick'
import { MessageAudioItemView } from '../view/MessageAudioItemView'
import { image } from '@kit.ImageKit'
import { staticMap } from '@kit.MapKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { ChatAitNode } from '../model/ChatAitNode'
import { ChatKitClient, getMultiLineBody, getMultiLineTitle, IMKitConfigCenter, MergedMessageAttachment, NEFriendUserCache } from '@nimkit/chatkit'
import { ChatInfo } from '../model/ChatInfo'
import { NECommonUtils } from '@nimkit/common'
import { Markdown } from '@nimkit/markdown'
import { markConfig } from '@nimkit/markdown'
import { get } from '@nimsdk/vendor'
import { ChatKitUIClient } from '../ChatKitUIClient'
import { http } from '@kit.NetworkKit'
import { common } from '@kit.AbilityKit'
import { parseTextWithLinks, TextNode, TextNodeType, LinkInfo, LinkType } from '../utils/TextNodeParser'
import { LinkClickUtils } from '../utils/LinkClickUtils'
import { linkifyExtension } from '../utils/MarkdownLinkifyExtension'
import { MessageTranslationService } from '../service/translation/MessageTranslationService'

/**
 * 初始化 Markdown 组件的 linkify 支持
 * 通过 marked 的 tokenizer 扩展机制，在解析阶段识别 URL/电话/邮箱
 */
function initMarkdownLinkify() {
  // 注册 linkify tokenizer 扩展
  markConfig.addPlugin([linkifyExtension])

  // 注册链接点击回调
  // Markdown 组件渲染 link token 时会调用这个回调
  markConfig.registerLinkClick = (url?: string) => {
    if (!url) return

    // 从 AppStorage 获取 context
    const context = AppStorage.get<common.UIAbilityContext>('currentUIAbilityContext')
    if (!context) return

    // 根据 URL 格式判断类型并处理
    if (url.startsWith('mailto:')) {
      // 邮箱
      const email = url.replace('mailto:', '')
      const linkInfo: LinkInfo = {
        type: LinkType.EMAIL,
        text: email,
        url: url,
        start: 0,
        end: email.length
      }
      LinkClickUtils.handleLinkClick(context, linkInfo)
    } else if (url.startsWith('tel:')) {
      // 电话
      const phone = url.replace('tel:', '')
      const linkInfo: LinkInfo = {
        type: LinkType.PHONE,
        text: phone,
        url: url,
        start: 0,
        end: phone.length
      }
      LinkClickUtils.handleLinkClick(context, linkInfo)
    } else {
      // URL
      const linkInfo: LinkInfo = {
        type: LinkType.URL,
        text: url,
        url: url,
        start: 0,
        end: url.length
      }
      LinkClickUtils.handleLinkClick(context, linkInfo)
    }
  }
}

// 初始化（模块加载时执行一次）
initMarkdownLinkify()

@ComponentV2
export struct messageContent {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @BuilderParam
  chatInfo: ChatInfo | undefined

  build() {
    if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      if (this.message.isAiStreamMessage() == false) {
        textBuilder({
          message: this.message,
          onMessageClick: this.onMessageClick,
          chatInfo: this.chatInfo
        });
      } else {
        richTextBuilder({
          message: this.message,
          onMessageClick: this.onMessageClick,
          chatInfo: this.chatInfo
        });
      }
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
      locationBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      imageBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
      videoBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
      fileBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      MessageAudioItemView({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
      callBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
      if (this.message.isMultiLineMsg) {
        multiLineMessageBuilder({ message: this.message, onMessageClick: this.onMessageClick, chatInfo: this.chatInfo })
      } else if (this.message.isMergeMsg) {
        mergedMessageBuilder({ message: this.message, onMessageClick: this.onMessageClick })
      } else {
        unknownBuilder({ message: this.message, onMessageClick: this.onMessageClick });
      }
    } else {
      unknownBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    }
  }
}


@ComponentV2
export struct pinMessageContent {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick?: MessageItemClick

  build() {
    if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      pinTextBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
      pinLocationBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      imageBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
      videoBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
      fileBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      MessageAudioItemView({ message: this.message, onMessageClick: this.onMessageClick, isReceiveStyle: true });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
      callBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
      if (this.message.isMultiLineMsg) {
        multiLineMessageBuilder({ message: this.message, onMessageClick: this.onMessageClick, isPinCollectionMode: true })
      } else if (this.message.isMergeMsg) {
        mergedMessageBuilder({ message: this.message, onMessageClick: this.onMessageClick }).width('80%')
      } else {
        unknownBuilder({ message: this.message, onMessageClick: this.onMessageClick });
      }
    } else {
      unknownBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    }
  }
}

@ComponentV2
export struct memberHistoryMessageContent {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick?: MessageItemClick

  build() {
    if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      historyTextBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
      pinLocationBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      imageBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
      videoBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
      fileBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      MessageAudioItemView({ message: this.message, onMessageClick: this.onMessageClick, isReceiveStyle: true });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
      callBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
      if (this.message.isMultiLineMsg) {
        multiLineMessageBuilder({ message: this.message, onMessageClick: this.onMessageClick })
      } else if (this.message.isMergeMsg) {
        mergedMessageBuilder({ message: this.message, onMessageClick: this.onMessageClick }).width('80%')
      } else {
        unknownBuilder({ message: this.message, onMessageClick: this.onMessageClick });
      }
    } else {
      unknownBuilder({ message: this.message, onMessageClick: this.onMessageClick });
    }
  }
}

/**
 * 富文本消息（换行消息）渲染组件
 * 消息类型为 type=102 的自定义消息
 *
 * 链接高亮规则（按冒烟用例 108/109）：
 * - 标题：不做链接高亮，作为普通文本显示（加粗）
 * - 正文：支持链接（邮箱、URL、电话）识别和高亮，可点击
 */
@ComponentV2
export struct multiLineMessageBuilder {
  @Require @Param
  message: NIMMessageInfo
  @Param
  onMessageClick: MessageItemClick | undefined = undefined
  @Param
  chatInfo: ChatInfo | undefined = undefined
  /**
   * 是否为列表模式（Pin/Collection 列表）
   * 列表模式下：标题最多 1 行，标题+正文一共最多 3 行
   */
  @Param
  isPinCollectionMode: boolean = false
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  /**
   * 处理链接点击
   */
  private onLinkClick(linkInfo: LinkInfo) {
    LinkClickUtils.handleLinkClick(this.context, linkInfo)
  }

  /**
   * 处理回复消息点击
   */
  private onReplyClick(event: ClickEvent) {
    this.onMessageClick?.onReplyClick?.(event, this.message.replyMsg)
  }

  @Builder
  private MultiLineTitleContent(title: string) {
    ForEach(parseMessageText(title) ?? [], (item: NEEmojiParseResult) => {
      if (item.text) {
        Span(item.text)
          .fontWeight(FontWeight.Bold)
          .fontSize($r('app.float.chat_message_text_font_size'))
          .fontColor($r('app.color.color_chat_title'))
      } else if (item.emoji) {
        ImageSpan($rawfile(`emoji/${item.emoji.file}`))
          .width(18)
          .height(18)
          .objectFit(ImageFit.Fill)
          .verticalAlign(ImageSpanAlignment.CENTER)
      }
    })
  }

  @Builder
  private MultiLineBodyContent(body: string) {
    ForEach(parseMessageText(body) ?? [], (item: NEEmojiParseResult) => {
      if (item.text) {
        ForEach(getAitNodes(item.startIndex, item.text, this.message.message.serverExtension),
          (node: ChatAitNode) => {
            if (node.segment) {
              Span(node.text)
                .fontSize($r('app.float.chat_message_text_font_size'))
                .fontColor('#337EFF')
            } else {
              ForEach(parseTextWithLinks(node.text), (textNode: TextNode) => {
                if (textNode.type === TextNodeType.LINK && textNode.linkInfo) {
                  Span(textNode.text)
                    .fontSize($r('app.float.chat_message_text_font_size'))
                    .fontColor('#337EFF')
                    .onClick(() => {
                      this.onLinkClick(textNode.linkInfo!)
                    })
                } else {
                  Span(textNode.text)
                    .fontSize($r('app.float.chat_message_text_font_size'))
                    .fontColor($r('app.color.color_chat_title'))
                }
              })
            }
          })
      } else if (item.emoji) {
        ImageSpan($rawfile(`emoji/${item.emoji.file}`))
          .width(18)
          .height(18)
          .objectFit(ImageFit.Fill)
          .verticalAlign(ImageSpanAlignment.CENTER)
      }
    })
  }

  aboutToAppear(): void {
    if (!this.isPinCollectionMode) {
      MessageTranslationService.instance.prepareMessage(this.message)
    }
  }

  build() {
    Column() {
      // 回复消息预览（如果有）
      if (!this.message.isRevokeMsg && this.message.isReplyMsg) {
        if (this.message.replyMsg) {
          Text() {
            if (this.chatInfo) {
              Span(' | ' + parseReplyMessageUserInfo(this.message.replyMsg, this.chatInfo))
                .fontSize($r('app.float.chat_desc_text_font_size'))
                .textCase(TextCase.Normal)
                .fontColor($r('app.color.color_chat_desc'))
            }
            ForEach(sliceMessageText(parseMessageText(getReplyMessageText(this.message.replyMsg)), 30),
              (item: NEEmojiParseResult) => {
                if (item.text) {
                  Span(item.text)
                    .fontSize($r('app.float.chat_desc_text_font_size'))
                    .textCase(TextCase.Normal)
                    .fontColor($r('app.color.color_chat_desc'))
                } else if (item.emoji) {
                  ImageSpan($rawfile(`emoji/${item.emoji.file}`)).width('16')
                    .height('16')
                    .objectFit(ImageFit.Fill)
                    .verticalAlign(ImageSpanAlignment.CENTER)
                }
              })
          }
          .fontColor($r('app.color.color_chat_desc'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .height(20)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(EllipsisMode.END)
          .margin({ bottom: 4 })
          .onClick((event) => this.onReplyClick(event))
        } else {
          Text(getContext().resourceManager.getStringSync($r('app.string.chat_reply_not_exist').id))
            .fontColor($r('app.color.color_chat_desc'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
            .height(20)
            .maxLines(1)
            .ellipsisMode(EllipsisMode.END)
            .margin({ bottom: 4 })
        }
      }

      if (!this.message.isReceiveMessage() || !this.message.translatedText || this.message.translationLoading || this.message.translationFailed ||
        this.isPinCollectionMode || this.message.showOriginalText) {
        // 标题：加粗显示，不做链接高亮和 @ 高亮（按冒烟用例 108 要求）
        // 列表模式下：最多 1 行，超长打点
        if (getMultiLineTitle(this.message.message).length > 0) {
          Text() {
            this.MultiLineTitleContent(getMultiLineTitle(this.message.message))
          }
            .fontWeight(FontWeight.Bold)
            .fontSize($r('app.float.chat_message_text_font_size'))
            .fontColor($r('app.color.color_chat_title'))
            .textAlign(TextAlign.Start)
            .maxLines(this.isPinCollectionMode ? 1 : undefined)
            .textOverflow(this.isPinCollectionMode ? { overflow: TextOverflow.Ellipsis } : undefined)
            .ellipsisMode(this.isPinCollectionMode ? EllipsisMode.END : undefined)
        }
        if (getMultiLineBody(this.message.message).length > 0) {
          Text() {
            this.MultiLineBodyContent(getMultiLineBody(this.message.message))
          }
          .textAlign(TextAlign.Start)
          .margin({ top: getMultiLineTitle(this.message.message).length > 0 ? 4 : 0 })
          .maxLines(this.isPinCollectionMode ? (getMultiLineTitle(this.message.message).length > 0 ? 2 : 3) : undefined)
          .textOverflow(this.isPinCollectionMode ? { overflow: TextOverflow.Ellipsis } : undefined)
          .ellipsisMode(this.isPinCollectionMode ? EllipsisMode.END : undefined)
        }
      }

      if (!this.isPinCollectionMode && this.message.isReceiveMessage() && this.message.translationLoading) {
        Row() {
          Image($r('app.media.ic_chat_menu_translate'))
            .width(12)
            .height(12)
            .opacity(0.5)
          Text($r('app.string.chat_translation_loading'))
            .fontSize(11)
            .fontColor('#98A2B3')
            .margin({ left: 4 })
        }
        .margin({ top: 8 })
      } else if (!this.isPinCollectionMode && this.message.isReceiveMessage() && this.message.translationFailed) {
        Row() {
          Image($r('app.media.ic_chat_message_status_fail'))
            .width(12)
            .height(12)
          Text($r('app.string.chat_translation_failed_retry'))
            .fontSize(11)
            .fontColor('#F24957')
            .margin({ left: 4 })
        }
        .margin({ top: 8 })
        .onClick(() => {
          MessageTranslationService.instance.retry(this.message)
        })
      } else if (!this.isPinCollectionMode && this.message.isReceiveMessage() &&
        this.message.showTranslatedText && this.message.translatedText) {
        Column() {
          if (this.message.showOriginalText) {
            Divider()
              .strokeWidth(1)
              .color('#D6DAE0')
              .width('100%')
              .margin({ top: 8, bottom: 8 })
          }
          if (this.message.translatedTitle && this.message.translatedTitle.length > 0) {
            Text(this.message.translatedTitle)
              .fontWeight(FontWeight.Bold)
              .fontSize($r('app.float.chat_message_text_font_size'))
              .fontColor($r('app.color.color_chat_title'))
              .textAlign(TextAlign.Start)
          }
          if (this.message.translatedBody && this.message.translatedBody.length > 0) {
            Text(this.message.translatedBody)
              .fontSize($r('app.float.chat_message_text_font_size'))
              .fontColor($r('app.color.color_chat_title'))
              .textAlign(TextAlign.Start)
              .margin({ top: this.message.translatedTitle && this.message.translatedTitle.length > 0 ? 4 : 0 })
          } else if ((!this.message.translatedTitle || this.message.translatedTitle.length === 0) &&
            this.message.translatedText.length > 0) {
            Text(this.message.translatedText)
              .fontSize($r('app.float.chat_message_text_font_size'))
              .fontColor($r('app.color.color_chat_title'))
              .textAlign(TextAlign.Start)
          }
          Row() {
            Image($r('app.media.ic_chat_menu_translate'))
              .width(12)
              .height(12)
              .opacity(0.5)
            Text($r('app.string.chat_translation_tag'))
              .fontSize(11)
              .fontColor('#98A2B3')
              .margin({ left: 4 })
          }
          .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .gesture(LongPressGesture().onAction((event: GestureEvent) => {
          this.onMessageClick?.onTranslatedAreaLongClick?.(event, this.message)
        }))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: 12,
      top: 12,
      bottom: 12,
      right: 12
    })
    .onClick((event: ClickEvent) => {
      this.onMessageClick?.onItemClick?.(event, this.message)
    })
  }
}

@ComponentV2
export struct richTextBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @BuilderParam
  chatInfo: ChatInfo | undefined
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    // 设置当前 context 到 AppStorage，供 linkify 点击回调使用
    const context = getContext(this) as common.UIAbilityContext
    AppStorage.setOrCreate('currentUIAbilityContext', context)
  }

  private onItemClick(event: ClickEvent) {
    this.onMessageClick?.onReplyClick?.(event, this.message.replyMsg)
  }

  private onRevokeEditClick(event: ClickEvent) {
    this.onMessageClick?.onRevokeEditClick?.(event, this.message)
  }

  /**
   * 处理链接点击
   */
  private onLinkClick(linkInfo: LinkInfo) {
    LinkClickUtils.handleLinkClick(this.context, linkInfo)
  }

  build() {
    Column() {
      if (!this.message.isRevokeMsg && this.message.isReplyMsg) {
        if (this.message.replyMsg) {
          Text() {
            if (this.chatInfo) {
              Span(' | ' + parseReplyMessageUserInfo(this.message.replyMsg, this.chatInfo))
                .fontSize($r('app.float.chat_desc_text_font_size'))
                .textCase(TextCase.Normal)
                .fontColor($r('app.color.color_chat_desc'))
            }
            ForEach(sliceMessageText(parseMessageText(getReplyMessageText(this.message.replyMsg)), 30),
              (item: NEEmojiParseResult) => {
                if (item.text) {
                  Span(item.text)
                    .fontSize($r('app.float.chat_desc_text_font_size'))
                    .textCase(TextCase.Normal)
                    .fontColor($r('app.color.color_chat_desc'))
                } else if (item.emoji) {
                  ImageSpan($rawfile(`emoji/${item.emoji.file}`)).width('16')
                    .height('16')
                    .objectFit(ImageFit.Fill)
                    .verticalAlign(ImageSpanAlignment.CENTER)
                }
              })
          }
          .fontColor($r('app.color.color_chat_desc'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .height(20)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(EllipsisMode.END)
          .margin({ bottom: 4 })
          .onClick((event) => this.onItemClick(event))
        } else {
          Text(getContext().resourceManager.getStringSync($r('app.string.chat_reply_not_exist').id))
            .fontColor($r('app.color.color_chat_desc'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
            .height(20)
            .maxLines(1)
            .ellipsisMode(EllipsisMode.END)
            .margin({ bottom: 4 })
        }

      }
      Column() {
        if (this.message.isRevokeMsg) {
          Span(this.message.message.text)
          if (this.message.revokeEditMsg) {
            Text($r('app.string.chat_msg_undo_edit_tips'))
              .fontColor($r('app.color.color_chat_send'))
              .onClick((event) => {
                this.onRevokeEditClick(event)
              })
          }
        } else {
          ForEach(parseMessageText(this.message.message.text?.trimStart()?.trimEnd()), (item: NEEmojiParseResult) => {
            if (item.text) {
              ForEach(getAitNodes(item.startIndex, item.text, this.message.message.serverExtension),
                (node: ChatAitNode) => {
                  if (node.segment) {
                    Span(node.text)
                      .fontSize($r('app.float.chat_message_text_font_size'))
                      .textCase(TextCase.Normal)
                      .fontColor('#337EFF')
                  } else {
                    // 使用 Markdown 组件渲染，linkify 扩展会在解析阶段识别 URL/电话/邮箱
                    Markdown({
                      content: node.text,
                      lineSpace: 0,
                      textLineSpace: 6,
                      fontStyle: {
                        fontColor: $r('app.color.color_chat_title'),
                        fontSize: $r('app.float.chat_message_text_font_size')
                      },
                    })
                  }
                })

            } else if (item.emoji) {
              ImageSpan($rawfile(`emoji/${item.emoji.file}`))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Fill)
                .verticalAlign(ImageSpanAlignment.CENTER)
            }
          })
        }
      }
    }.alignItems(HorizontalAlign.Start)
    .padding({
      left: 12,
      top: 12,
      bottom: 12,
      right: 12
    })
  }
}


@ComponentV2
export struct textBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @BuilderParam
  chatInfo: ChatInfo | undefined
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  private onItemClick(event: ClickEvent) {
    this.onMessageClick?.onReplyClick?.(event, this.message.replyMsg)
  }

  private onRevokeEditClick(event: ClickEvent) {
    this.onMessageClick?.onRevokeEditClick?.(event, this.message)
  }

  /**
   * 处理链接点击
   */
  private onLinkClick(linkInfo: LinkInfo) {
    LinkClickUtils.handleLinkClick(this.context, linkInfo)
  }

  aboutToAppear(): void {
    MessageTranslationService.instance.prepareMessage(this.message)
  }

  build() {
    Column() {
      if (!this.message.isRevokeMsg && this.message.isReplyMsg) {
        if (this.message.replyMsg) {
          Text() {
            if (this.chatInfo) {
              Span(' | ' + parseReplyMessageUserInfo(this.message.replyMsg, this.chatInfo))
                .fontSize($r('app.float.chat_desc_text_font_size'))
                .textCase(TextCase.Normal)
                .fontColor($r('app.color.color_chat_desc'))
            }
            ForEach(sliceMessageText(parseMessageText(getReplyMessageText(this.message.replyMsg)), 30),
              (item: NEEmojiParseResult) => {
                if (item.text) {
                  Span(item.text)
                    .fontSize($r('app.float.chat_desc_text_font_size'))
                    .textCase(TextCase.Normal)
                    .fontColor($r('app.color.color_chat_desc'))
                } else if (item.emoji) {
                  ImageSpan($rawfile(`emoji/${item.emoji.file}`)).width('16')
                    .height('16')
                    .objectFit(ImageFit.Fill)
                    .verticalAlign(ImageSpanAlignment.CENTER)
                }
              })
          }
          .fontColor($r('app.color.color_chat_desc'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .height(20)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(EllipsisMode.END)
          .margin({ bottom: 4 })
          .onClick((event) => this.onItemClick(event))
        } else {
          Text(getContext().resourceManager.getStringSync($r('app.string.chat_reply_not_exist').id))
            .fontColor($r('app.color.color_chat_desc'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
            .height(20)
            .maxLines(1)
            .ellipsisMode(EllipsisMode.END)
            .margin({ bottom: 4 })
        }

      }
      if (!this.message.isReceiveMessage() || !this.message.translatedText || this.message.translationLoading ||
        this.message.translationFailed ||
        this.message.showOriginalText) {
        Text() {
          if (this.message.isRevokeMsg) {
            Span(this.message.message.text)
            if (this.message.revokeEditMsg) {
              Span($r('app.string.chat_msg_undo_edit_tips'))
                .fontColor($r('app.color.color_chat_send'))
                .onClick((event) => {
                  this.onRevokeEditClick(event)
                })
            }
          } else {
            ForEach(parseMessageText(this.message.message.text?.trimStart()?.trimEnd()), (item: NEEmojiParseResult) => {
              if (item.text) {
                ForEach(getAitNodes(item.startIndex, item.text, this.message.message.serverExtension),
                  (node: ChatAitNode) => {
                    if (node.segment) {
                      Span(node.text)
                        .fontSize($r('app.float.chat_message_text_font_size'))
                        .textCase(TextCase.Normal)
                        .fontColor('#337EFF')
                    } else {
                      ForEach(parseTextWithLinks(node.text), (textNode: TextNode) => {
                        if (textNode.type === TextNodeType.LINK && textNode.linkInfo) {
                          Span(textNode.text)
                            .fontSize($r('app.float.chat_message_text_font_size'))
                            .textCase(TextCase.Normal)
                            .fontColor('#337EFF')
                            .onClick(() => {
                              this.onLinkClick(textNode.linkInfo!)
                            })
                        } else {
                          Span(textNode.text)
                            .fontSize($r('app.float.chat_message_text_font_size'))
                            .textCase(TextCase.Normal)
                            .fontColor($r('app.color.color_chat_title'))
                        }
                      })
                    }
                  })

              } else if (item.emoji) {
                ImageSpan($rawfile(`emoji/${item.emoji.file}`))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Fill)
                  .verticalAlign(ImageSpanAlignment.CENTER)
              }
            })
          }
        }
        .lineHeight(20)
        .fontSize($r('app.float.chat_subtitle_text_font_size'))
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .ellipsisMode(EllipsisMode.END)
      }

      if (this.message.isReceiveMessage() && this.message.translationLoading) {
        Row() {
          Image($r('app.media.ic_chat_menu_translate'))
            .width(12)
            .height(12)
            .opacity(0.5)
          Text($r('app.string.chat_translation_loading'))
            .fontSize(11)
            .fontColor('#98A2B3')
            .margin({ left: 4 })
        }
        .margin({ top: 8 })
      } else if (this.message.isReceiveMessage() && this.message.translationFailed) {
        Row() {
          Image($r('app.media.ic_chat_message_status_fail'))
            .width(12)
            .height(12)
          Text($r('app.string.chat_translation_failed_retry'))
            .fontSize(11)
            .fontColor('#F24957')
            .margin({ left: 4 })
        }
        .margin({ top: 8 })
        .onClick(() => {
          MessageTranslationService.instance.retry(this.message)
        })
      } else if (this.message.isReceiveMessage() && this.message.showTranslatedText && this.message.translatedText) {
        Column() {
          if (this.message.showOriginalText) {
            Divider()
              .strokeWidth(1)
              .color('#D6DAE0')
              .width('100%')
              .margin({ top: 8, bottom: 8 })
          }
          Text(this.message.translatedText)
            .lineHeight(20)
            .fontSize($r('app.float.chat_subtitle_text_font_size'))
            .fontColor($r('app.color.color_chat_title'))
            .textAlign(TextAlign.Start)
          Row() {
            Image($r('app.media.ic_chat_menu_translate'))
              .width(12)
              .height(12)
              .opacity(0.5)
            Text($r('app.string.chat_translation_tag'))
              .fontSize(11)
              .fontColor('#98A2B3')
              .margin({ left: 4 })
          }
          .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .gesture(LongPressGesture().onAction((event: GestureEvent) => {
          this.onMessageClick?.onTranslatedAreaLongClick?.(event, this.message)
        }))
      }
    }.alignItems(HorizontalAlign.Start)
    .padding({
      left: 12,
      top: 12,
      bottom: 12,
      right: 12
    })
  }
}


@ComponentV2
export struct pinTextBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  /**
   * 处理链接点击
   */
  private onLinkClick(linkInfo: LinkInfo) {
    LinkClickUtils.handleLinkClick(this.context, linkInfo)
  }

  build() {
    Column() {
      Text() {
        ForEach(parseMessageText(this.message.message.text?.trimStart()?.trimEnd()), (item: NEEmojiParseResult) => {
          if (item.text) {
            ForEach(parseTextWithLinks(item.text), (textNode: TextNode) => {
              if (textNode.type === TextNodeType.LINK && textNode.linkInfo) {
                Span(textNode.text)
                  .fontSize($r('app.float.chat_message_text_font_size'))
                  .textCase(TextCase.Normal)
                  .fontColor('#337EFF')
                  .onClick(() => {
                    this.onLinkClick(textNode.linkInfo!)
                  })
              } else {
                Span(textNode.text)
                  .fontSize($r('app.float.chat_message_text_font_size'))
                  .textCase(TextCase.Normal)
                  .fontColor($r('app.color.color_chat_title'))
              }
            })
          } else if (item.emoji) {
            ImageSpan($rawfile(`emoji/${item.emoji.file}`)).width('18')
              .height('18')
              .objectFit(ImageFit.Fill)
              .verticalAlign(ImageSpanAlignment.CENTER)
          }
        })
      }
      .fontColor($r('app.color.color_chat_title'))
      .lineHeight(20)
      .fontSize($r('app.float.chat_subtitle_text_font_size'))
      .maxLines(3)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .ellipsisMode(EllipsisMode.END)
    }
  }
}


@ComponentV2
export struct historyTextBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  /**
   * 处理链接点击
   */
  private onLinkClick(linkInfo: LinkInfo) {
    LinkClickUtils.handleLinkClick(this.context, linkInfo)
  }

  build() {
    Column() {
      Text() {
        ForEach(parseMessageText(this.message.message.text?.trimStart()?.trimEnd()), (item: NEEmojiParseResult) => {
          if (item.text) {
            ForEach(parseTextWithLinks(item.text), (textNode: TextNode) => {
              if (textNode.type === TextNodeType.LINK && textNode.linkInfo) {
                Span(textNode.text)
                  .fontSize($r('app.float.chat_message_text_font_size'))
                  .textCase(TextCase.Normal)
                  .fontColor('#337EFF')
                  .onClick(() => {
                    this.onLinkClick(textNode.linkInfo!)
                  })
              } else {
                Span(textNode.text)
                  .fontSize($r('app.float.chat_message_text_font_size'))
                  .textCase(TextCase.Normal)
                  .fontColor($r('app.color.color_chat_title'))
              }
            })
          } else if (item.emoji) {
            ImageSpan($rawfile(`emoji/${item.emoji.file}`)).width('18')
              .height('18')
              .objectFit(ImageFit.Fill)
              .verticalAlign(ImageSpanAlignment.CENTER)
          }
        })
      }
      .fontColor($r('app.color.color_chat_title'))
      .lineHeight(20)
      .fontSize($r('app.float.chat_subtitle_text_font_size'))
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .ellipsisMode(EllipsisMode.END)
      .padding({
        left: 14,
        right: 14,
        top: 10,
        bottom: 10
      })
      // .margin({ top: 6 })
    }
  }
}

@ComponentV2
export struct imageBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @Local thumbUrl?: string
  @Local url?: string

  build() {
    Column() {
      Image(this.thumbUrl ?? this.url)
        .objectFit(ImageFit.Cover)
        .width(getImageWidth(this.message))
        .height(getImageHeight(this.message))
        .borderRadius(8)
        .gesture(LongPressGesture().onAction((event: GestureEvent) => {
          this.onMessageClick?.onItemLongClick?.(event, this.message)
        }), GestureMask.IgnoreInternal)
        .onComplete(() => {
          // 图片加载完成后，缓存 PixelMap（用于预览时作为占位图）
          this.cacheThumbPixelMap()
        })
    }
  }

  aboutToAppear(): void {
    this.url = this.message.getImageUrl()
    this.message.getImageThumbUrl().then((thumbUrl) => {
      this.thumbUrl = thumbUrl
    })
  }

  /**
   * 缓存缩略图的 PixelMap
   * 用于在图片预览时，网络不可用的情况下作为占位图显示，避免黑屏
   */
  private cacheThumbPixelMap(): void {
    // 如果已经缓存过，则不再重复缓存
    if (this.message.cachedThumbPixelMap) {
      return
    }

    const imageUrl = this.thumbUrl ?? this.url
    if (!imageUrl) {
      return
    }

    // 本地文件路径直接使用 createImageSource
    if (imageUrl.startsWith('file://') || imageUrl.startsWith('/')) {
      try {
        const filePath = imageUrl.startsWith('file://') ? imageUrl.replace('file://', '') : imageUrl
        const imageSource = image.createImageSource(filePath)
        imageSource.createPixelMap().then((pixelMap) => {
          this.message.cachedThumbPixelMap = pixelMap
        }).catch((err: Error) => {
          console.debug('netease cacheThumbPixelMap createPixelMap failed:', err.message)
        })
      } catch (err) {
        console.debug('netease cacheThumbPixelMap failed:', err)
      }
    } else if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // 网络图片需要先下载再创建 PixelMap
      import('@ohos.net.http')
        .then((httpModule) => {
        const httpRequest = http.createHttp()
        httpRequest.request(imageUrl, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        }).then((response) => {
          if (response.responseCode === 200 && response.result instanceof ArrayBuffer) {
            const imageSource = image.createImageSource(response.result)
            imageSource.createPixelMap().then((pixelMap) => {
              this.message.cachedThumbPixelMap = pixelMap
            }).catch((err: Error) => {
              console.debug('netease cacheThumbPixelMap createPixelMap from http failed:', err.message)
            })
          }
        }).catch((err: Error) => {
          console.debug('netease cacheThumbPixelMap http request failed:', err.message)
        }).finally(() => {
          httpRequest.destroy()
        })
      })
    }
  }
}

@ComponentV2
export struct videoBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @Local videoMessageThumbnail?: image.PixelMap

  showLoading() {
    if ((this.message.message.attachment as V2NIMMessageFileAttachment).path === undefined) {
      if (this.message.downloadProgress > 0) {
        return true
      }
    }
    return false
  }

  async aboutToAppear(): Promise<void> {
    this.videoMessageThumbnail = await getVideoMessageThumbnail(this.message)
  }

  build() {
    Stack() {
      Image(this.videoMessageThumbnail ?? getVideoMessageUrl(this.message)).objectFit(ImageFit.Auto)
        .width(getImageWidth(this.message)).height(getImageHeight(this.message))
        .borderRadius(8)
      Image($r('app.media.ic_chat_message_video')).objectFit(ImageFit.Auto)
        .width(60).height(60)
        .visibility(!this.showLoading() ? Visibility.Visible : Visibility.Hidden)

      Row() {
        Column()
          .width(3)
          .height(18)
          .backgroundColor(Color.White)
          .borderRadius(3)
        Column()
          .width(3)
          .height(18)
          .backgroundColor(Color.White)
          .borderRadius(3)
          .margin({
            left: 6
          })
      }
      .width(12)
      .height(18)
      .backgroundColor(Color.Transparent)
      .visibility(this.showLoading() ? Visibility.Visible : Visibility.Hidden)

      Progress({ value: 0, total: 100, type: ProgressType.Ring })
        .width(42)
        .height(42)
        .value(this.message.downloadProgress)
        .color(Color.White)// 进度条前景色为灰色
        .style({ strokeWidth: 3 })// 设置strokeWidth进度条宽度为15.0vp
        .visibility(this.showLoading() ? Visibility.Visible : Visibility.Hidden)

      // 视频时长显示
      Text(formatVideoDuration(getVideoDuration(this.message)))
        .fontSize(12)
        .fontColor(Color.White)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .borderRadius(4)
        .position({ right: 6, bottom: 6 })
        .visibility(getVideoDuration(this.message) > 0 ? Visibility.Visible : Visibility.Hidden)
    }.gesture(LongPressGesture().onAction((event: GestureEvent) => {
      this.onMessageClick?.onItemLongClick?.(event, this.message)
    }), GestureMask.IgnoreInternal)
  }
}

@ComponentV2
export struct callBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined

  build() {
    Row() {
      if (this.message.isReceiveMsg) {
        Image(getCallMessageIcon(this.message)).width(24).height(24).align(Alignment.Start)
        Text(getCallMessageText(this.message)).lineHeight(20).margin({ left: 6 })
      } else {
        Text(getCallMessageText(this.message)).lineHeight(20)
          .fontSize($r('app.float.chat_subtitle_text_font_size'))
          .fontColor($r('app.color.color_chat_title'))
        Image(getCallMessageIcon(this.message)).width(24).height(24).align(Alignment.Start).margin({ left: 6 })
      }
    }
    .padding({
      left: 12,
      top: 12,
      bottom: 12,
      right: 12
    })
    .onClick(() => {
      if (this.message.getConversationType() !== V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        // only p2p, ignore
        return
      }
      if (this.message.getMessageType() !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
        // only call message, ignore
        return
      }

      // 创建呼叫参数（核心：动态传入选中的callType）
      const targetId: string = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.message.getConversationId())

      // 检查是否开启仅好友通话限制
      if (IMKitConfigCenter.enableOnlyFriendCall && !NEFriendUserCache.getInstance().hasFriendRelation(targetId)) {
        NECommonUtils.showToast($r('app.string.chat_not_friend_call_tip'))
        return
      }

      // call
      let callType: number = 1; // 默认音频通话
      if (get(this.message.message.attachment ?? {}, 'type') === 2) { // is video?
        callType = 2;
      }
      ChatKitUIClient.getInstance().call(targetId, callType)
    })
  }
}


@ComponentV2
export struct fileBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined

  build() {
    Row() {
      Stack({}) {
        Image(getFileMessageIcon(this.message))
          .objectFit(ImageFit.Auto)
          .width(35)
          .height(35)
          .margin({ left: 12, top: 12, bottom: 12 })
        Column()
          .width(35)
          .height(35)
          .margin({ left: 12, top: 12, bottom: 12 })
          .backgroundColor($r('app.color.color_chat_converse_bg'))
          .opacity(0.8)
          .borderRadius(6)
          .visibility(this.message.downloadProgress >= 0 ? Visibility.Visible : Visibility.Hidden)
        Progress({ value: 0, total: 100, type: ProgressType.Ring })
          .width(20)
          .height(20)
          .value(this.message.downloadProgress)
          .margin({ left: 16, top: 16, bottom: 12 })
          .color(Color.White)// 进度条前景色为灰色
          .style({ strokeWidth: 3 })// 设置strokeWidth进度条宽度为15.0vp
          .visibility(this.message.downloadProgress >= 0 ? Visibility.Visible : Visibility.Hidden)
      }

      Column() {
        Text(getFileMessageName(this.message))
          .fontColor($r('app.color.color_chat_title'))
          .fontSize($r('app.float.chat_desc_text_font_size'))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start)
          .width('100%')
          .height(20)
          .maxLines(1)
          .ellipsisMode(EllipsisMode.CENTER)
        Text(getFileMessageSize(this.message))
          .fontColor('#666666')
          .fontSize(10)
          .width('100%')
          .textAlign(TextAlign.Start)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .margin({ top: 2 })
      }.padding({ left: 12, right: 12 }).width('70%').align(Alignment.Start)
    }
  }
}

@ComponentV2
export struct locationBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @Local imagePex: image.PixelMap | undefined

  aboutToAppear(): void {
    if (this.message) {

      let attachment = this.message.message.attachment as V2NIMMessageLocationAttachment;
      let staticMapMarker: staticMap.StaticMapMarker = {
        location: {
          latitude: attachment.latitude,
          longitude: attachment.longitude
        },
        defaultIconSize: staticMap.IconSize.SMALL
      };
      let staticMapOptions: staticMap.StaticMapOptions = {
        location: {
          latitude: attachment.latitude,
          longitude: attachment.longitude
        },
        zoom: 15,
        imageWidth: 300,
        imageHeight: 100,
        markers: [staticMapMarker],
      };

      // 获取静态图
      staticMap.getMapImage(staticMapOptions).then((value) => {
        this.imagePex = value;
        console.info("netease location Succeeded in getting image.");
      }).catch((error: BusinessError) => {
        console.info("netease location fail in getting image.", error.code, error.message);
      });
    }
  }

  build() {
    Column() {
      Text(this.message?.message.text)
        .fontColor($r('app.color.color_chat_title'))
        .fontSize($r('app.float.chat_title_text_font_size'))
        .textAlign(TextAlign.Start)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, top: 12, right: 12 })
      Text((this.message?.message.attachment as V2NIMMessageLocationAttachment).address)
        .fontColor($r('app.color.color_chat_desc'))
        .fontSize($r('app.float.chat_desc_text_font_size'))
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .margin({ top: 6 })
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, right: 12 })
      if (this.imagePex) {
        Image(this.imagePex).width('100%').height(88).margin({ top: 8 })
      } else {
        Image($r('app.media.ic_chat_location_default')).width('100%').height(88).margin({ top: 8 })
      }
    }.alignItems(HorizontalAlign.Start)
  }
}


@ComponentV2
export struct pinLocationBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @Local imagePex: image.PixelMap | undefined

  aboutToAppear(): void {
    if (this.message) {

      let attachment = this.message.message.attachment as V2NIMMessageLocationAttachment;
      let staticMapMarker: staticMap.StaticMapMarker = {
        location: {
          latitude: attachment.latitude,
          longitude: attachment.longitude
        },
        defaultIconSize: staticMap.IconSize.SMALL
      };
      let staticMapOptions: staticMap.StaticMapOptions = {
        location: {
          latitude: attachment.latitude,
          longitude: attachment.longitude
        },
        zoom: 15,
        imageWidth: 300,
        imageHeight: 100,
        markers: [staticMapMarker],
      };

      // 获取静态图
      staticMap.getMapImage(staticMapOptions).then((value) => {
        this.imagePex = value;
        console.info("netease location Succeeded in getting image.");
      }).catch((error: BusinessError) => {
        console.info("netease location fail in getting image.", error.code, error.message);
      });
    }
  }

  build() {
    Column() {
      Text(this.message?.message.text)
        .fontColor($r('app.color.color_chat_title'))
        .fontSize($r('app.float.chat_title_text_font_size'))
        .textAlign(TextAlign.Start)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, top: 12, right: 12 })
      Text((this.message?.message.attachment as V2NIMMessageLocationAttachment).address)
        .fontColor($r('app.color.color_chat_desc'))
        .fontSize($r('app.float.chat_desc_text_font_size'))
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .margin({ top: 6 })
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, right: 12 })
      if (this.imagePex) {
        Image(this.imagePex).width('100%').height(88).margin({ top: 8 })
      } else {
        Image($r('app.media.ic_chat_location_default')).width('100%').height(88).margin({ top: 8 })
      }
    }.alignItems(HorizontalAlign.Start)
    .width('80%')
  }
}

@ComponentV2
export struct unknownBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined

  build() {
    Column() {
      Text($r('app.string.chat_msg_unknown_type'))
        .fontColor($r('app.color.color_chat_title'))
        .lineHeight(20)
        .fontSize($r('app.float.chat_subtitle_text_font_size'))
    }
    .padding({
      left: 12,
      top: 12,
      bottom: 12,
      right: 12
    })
  }
}

@ComponentV2
export struct mergedMessageBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  mergedAttachment: MergedMessageAttachment | undefined
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    if (this.message) {
      this.mergedAttachment = this.message.customAttachment as MergedMessageAttachment
    }
  }

  /**
   * 处理链接点击
   */
  private onLinkClick(linkInfo: LinkInfo) {
    LinkClickUtils.handleLinkClick(this.context, linkInfo)
  }

  build() {
    Column() {
      if (this.mergedAttachment) {
        Text($r('app.string.chat_merged_message_title', this.mergedAttachment.sessionName))
          .fontColor($r('app.color.color_chat_title'))
          .fontSize($r('app.float.chat_title_text_font_size'))
          .height(18)
          .margin({ top: 6, bottom: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(EllipsisMode.CENTER)
        Text() {
          ForEach(parseText(this.message.mergedContent), (item: NEEmojiParseResult) => {
            if (item.text) {
              // 解析文本中的链接
              ForEach(parseTextWithLinks(item.text), (textNode: TextNode) => {
                if (textNode.type === TextNodeType.LINK && textNode.linkInfo) {
                  // 链接文本 - 蓝色可点击
                  Span(textNode.text)
                    .fontSize($r('app.float.chat_message_text_font_size'))
                    .textCase(TextCase.Normal)
                    .fontColor('#337EFF')
                    .onClick(() => {
                      this.onLinkClick(textNode.linkInfo!)
                    })
                } else {
                  // 普通文本
                  Span(textNode.text)
                    .fontSize($r('app.float.chat_message_text_font_size'))
                    .textCase(TextCase.Normal)
                    .fontColor($r('app.color.color_chat_desc'))
                }
              })
            } else if (item.emoji) {
              ImageSpan($rawfile(`emoji/${item.emoji.file}`)).width('18')
                .height('18')
                .objectFit(ImageFit.Fill)
                .verticalAlign(ImageSpanAlignment.CENTER)
            }
          })
        }
        .fontSize($r('app.float.chat_subtitle_text_font_size'))
        .maxLines(3)
        .lineHeight(20)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .ellipsisMode(EllipsisMode.END)
        .margin({ bottom: 6 })

        Line().width('100%').height(1).backgroundColor($r('app.color.color_chat_divider_line'))
        Text($r('app.string.chat_merged_message_desc'))
          .fontColor($r('app.color.color_chat_desc'))
          .fontSize($r('app.float.chat_subtitle_text_font_size'))
          .height(18).margin({ top: 6, bottom: 6 })
      }
    }
    .margin({
      left: 4,
      top: 4,
      bottom: 4,
      right: 4
    })
    .padding({ left: 12, right: 6 })
    .backgroundColor($r('app.color.color_chat_page_bg'))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }
}
