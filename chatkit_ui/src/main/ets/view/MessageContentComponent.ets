/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEEmojiParseResult } from '../manager/NEEmojiManager'
import { V2NIMMessageFileAttachment, V2NIMMessageLocationAttachment, V2NIMMessageType } from '@nimsdk/base'
import {
  getCallMessageIcon,
  getCallMessageText,
  getFileMessageIcon,
  getFileMessageName,
  getFileMessageSize,
  getImageHeight,
  getImageWidth,
  getVideoMessageUrl,
  parseMessageText
} from '../common/MessageHelper'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { MessageAudioItemView } from '../view/MessageAudioItemView'


@ComponentV2
export struct messageContent {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onItemLongClick?: (event: GestureEvent, msg: NIMMessageInfo | undefined,) => void

  build() {
    if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      textBuilder({ message: this.message });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
      locationBuilder({ message: this.message });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
      imageBuilder({ message: this.message, onItemLongClick: this.onItemLongClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
      videoBuilder({ message: this.message, onItemLongClick: this.onItemLongClick });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
      fileBuilder({ message: this.message });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      MessageAudioItemView({ message: this.message });
    } else if (this.message.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
      callBuilder({ message: this.message });
    } else {
      unknownBuilder({ message: this.message });
    }
  }
}


@ComponentV2
export struct textBuilder {
  @BuilderParam
  message: NIMMessageInfo

  build() {
    Column() {
      // Text(message?.message.text?.trimStart().trimEnd())
      Text() {
        ForEach(parseMessageText(this.message), (item: NEEmojiParseResult) => {
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
export struct imageBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onItemLongClick?: (event: GestureEvent, msg: NIMMessageInfo | undefined,) => void

  build() {
    Column() {
      Image(this.message?.getImageUrl()).objectFit(ImageFit.Cover)
        .width(getImageWidth(this.message)).height(getImageHeight(this.message))
        .borderRadius(8)
    }.gesture(LongPressGesture().onAction((event: GestureEvent) => {
      this.onItemLongClick?.(event, this.message)
    }), GestureMask.IgnoreInternal)
  }
}

@ComponentV2
export struct videoBuilder {
  @BuilderParam
  message: NIMMessageInfo
  @BuilderParam
  onItemLongClick?: (event: GestureEvent, msg: NIMMessageInfo | undefined,) => void

  showLoading() {
    if ((this.message.message.attachment as V2NIMMessageFileAttachment).path === undefined) {
      if (this.message.downloadProgress > 0) {
        return true
      }
    }
    return false
  }

  build() {
    Stack() {
      Image(getVideoMessageUrl(this.message)).objectFit(ImageFit.Auto)
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
      this.onItemLongClick?.(event, this.message)
    }), GestureMask.IgnoreInternal)
  }
}

@ComponentV2
export struct callBuilder {
  @BuilderParam
  message: NIMMessageInfo

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
      Image($r('app.media.ic_chat_location_default')).width('100%').height(88).margin({ top: 8 })
    }.alignItems(HorizontalAlign.Start)
  }
}


@ComponentV2
export struct unknownBuilder {
  @BuilderParam
  message: NIMMessageInfo

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