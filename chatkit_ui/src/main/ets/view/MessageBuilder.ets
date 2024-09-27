/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NEEmojiParseResult } from '../manager/NEEmojiManager'
import { V2NIMMessageLocationAttachment } from '@nimsdk/base'
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

@Builder
export function textBuilder(message: NIMMessageInfo) {
  Column() {
    // Text(message?.message.text?.trimStart().trimEnd())
    Text() {
      ForEach(parseMessageText(message), (item: NEEmojiParseResult) => {
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

@Builder
export function imageBuilder(message: NIMMessageInfo) {
  Column() {
    Image(message?.getImageUrl()).objectFit(ImageFit.Auto)
      .width(getImageWidth(message)).height(getImageHeight(message))
      .borderRadius(20)
  }
}

@Builder
export function videoBuilder(message: NIMMessageInfo) {
  Stack() {
    Image(getVideoMessageUrl(message)).objectFit(ImageFit.Auto)
      .width(getImageWidth(message)).height(getImageHeight(message))
      .borderRadius(20)
    Image($r('app.media.ic_chat_message_video')).objectFit(ImageFit.Auto)
      .width(60).height(60)
  }
}

@Builder
export function audioBuilder(message: NIMMessageInfo) {
  MessageAudioItemView({
    message: message
  })

}

@Builder
export function callBuilder(message: NIMMessageInfo) {
  Row() {
    if (message.isReceiveMessage()) {
      Image(getCallMessageIcon(message)).width(24).height(24).align(Alignment.Start)
      Text(getCallMessageText(message)).lineHeight(20).margin({ left: 6 })
    } else {
      Text(getCallMessageText(message)).lineHeight(20)
        .fontSize($r('app.float.chat_subtitle_text_font_size'))
        .fontColor($r('app.color.color_chat_title'))
      Image(getCallMessageIcon(message)).width(24).height(24).align(Alignment.Start).margin({ left: 6 })
    }
  }
  .padding({
    left: 12,
    top: 12,
    bottom: 12,
    right: 12
  })

}


@Builder
export function fileBuilder(message: NIMMessageInfo) {
  Row() {
    Stack({}) {
      Image(getFileMessageIcon(message))
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
        .visibility(message.downloadProgress >= 0 ? Visibility.Visible : Visibility.Hidden)
      Progress({ value: 0, total: 100, type: ProgressType.Ring })
        .width(20)
        .height(20)
        .value(message.downloadProgress)
        .margin({ left: 16, top: 16, bottom: 12 })
        .color(Color.White)// 进度条前景色为灰色
        .style({ strokeWidth: 3 })// 设置strokeWidth进度条宽度为15.0vp
        .visibility(message.downloadProgress >= 0 ? Visibility.Visible : Visibility.Hidden)
    }

    Column() {
      Text(getFileMessageName(message))
        .fontColor($r('app.color.color_chat_title'))
        .fontSize($r('app.float.chat_desc_text_font_size'))
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Start)
        .width('100%')
        .height(20)
        .maxLines(1)
        .ellipsisMode(EllipsisMode.END)
      Text(getFileMessageSize(message))
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

@Builder
export function locationBuilder(message: NIMMessageInfo) {
  Column() {
    Text(message?.message.text)
      .fontColor($r('app.color.color_chat_title'))
      .fontSize($r('app.float.chat_title_text_font_size'))
      .textAlign(TextAlign.Start)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 12, top: 12, right: 12 })
    Text((message?.message.attachment as V2NIMMessageLocationAttachment).address)
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


@Builder
export function unknownBuilder(message: NIMMessageInfo) {
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