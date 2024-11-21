/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEEmojiParseResult } from '../manager/NEEmojiManager'
import { V2NIMMessageFileAttachment, V2NIMMessageLocationAttachment, V2NIMMessageType } from '@nimsdk/base'
import {
  getAitNodes,
  getCallMessageIcon,
  getCallMessageText,
  getFileMessageIcon,
  getFileMessageName,
  getFileMessageSize,
  getImageHeight,
  getImageWidth,
  getReplyMessageText,
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
import { MergedMessageAttachment } from '@nimkit/chatkit'
import { ChatInfo } from '../model/ChatInfo'


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
      textBuilder({
        message: this.message,
        onMessageClick: this.onMessageClick,
        chatInfo: this.chatInfo
      });
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
      if (this.message.isMergeMsg) {
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
      if (this.message.isMergeMsg) {
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
export struct textBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined
  @BuilderParam
  chatInfo: ChatInfo | undefined

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
          .onClick((event: ClickEvent) => {
            this.onMessageClick?.onReplyClick?.(event, this.message.replyMsg)
          })
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
      Text() {
        if (this.message.isRevokeMsg) {
          Span(this.message.message.text)
          if (this.message.revokeEditMsg) {
            Span($r('app.string.chat_msg_undo_edit_tips'))
              .fontColor($r('app.color.color_chat_send'))
              .onClick((event: ClickEvent) => {
                this.onMessageClick?.onRevokeEditClick?.(event, this.message)
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
                    Span(node.text)
                      .fontSize($r('app.float.chat_message_text_font_size'))
                      .textCase(TextCase.Normal)
                      .fontColor($r('app.color.color_chat_title'))
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

  build() {
    Column() {
      Text() {
        ForEach(parseMessageText(this.message.message.text?.trimStart()?.trimEnd()), (item: NEEmojiParseResult) => {
          if (item.text) {
            Span(item.text)
              .fontSize($r('app.float.chat_message_text_font_size'))
              .textCase(TextCase.Normal)
              .fontColor($r('app.color.color_chat_title'))
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
export struct imageBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onMessageClick: MessageItemClick | undefined

  build() {
    Column() {
      Image(this.message?.getImageUrl()).objectFit(ImageFit.Cover)
        .width(getImageWidth(this.message)).height(getImageHeight(this.message))
        .borderRadius(8)
    }.gesture(LongPressGesture().onAction((event: GestureEvent) => {
      this.onMessageClick?.onItemLongClick?.(event, this.message)
    }), GestureMask.IgnoreInternal)
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
          .ellipsisMode(EllipsisMode.END)
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

  aboutToAppear(): void {
    if (this.message) {
      this.mergedAttachment = this.message.customAttachment as MergedMessageAttachment
    }
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
              Span(item.text)
                .fontSize($r('app.float.chat_message_text_font_size'))
                .textCase(TextCase.Normal)
                .fontColor($r('app.color.color_chat_desc'))

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