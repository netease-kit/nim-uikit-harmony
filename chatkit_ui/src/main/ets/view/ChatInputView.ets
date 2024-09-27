/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { NEImageButton } from './NEImageButton'
import prompt from '@ohos.prompt';
import { abilityAccessCtrl, bundleManager, common, Permissions, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import picker from '@ohos.file.picker';
import { NEChatEmojiView } from './NEChatEmojiView';
import { NEEmojiManager, NIMInputEmoticon } from '../manager/NEEmojiManager';
import { NEChatMoreOperation } from './ChatMoreOperationLayout';
import { NEAudioRecordView } from './NEAudioRecordView';
import { inputMethod } from '@kit.IMEKit';

export enum InputStyleType {
  // 底部无内容
  None = 1,
  // 展示表情输入框
  Emoji = 2,
  // 长按录音UI展示
  Record = 3,
  // 更多面板展示
  More = 4,
}

@Entry
@ComponentV2
export struct NEChatInputView {
  text: string = ''
  @Param @Require
  onSendTextMessage?: () => void;
  @Local operationMoreDataList: Array<NEChatMoreOperationData> = Array();
  @Param
  placeHolder: string = '';
  @Param @Require
  onDidClickImage?: () => void;
  @Param @Require
  onDidClickAudio?: () => void;
  @Param @Require
  onDidClickEmoji?: () => void;
  @Param @Require
  onDidClickMore?: () => void;
  @Param inputStyle: InputStyleType = InputStyleType.None;
  @Param @Require
  controller?: RichEditorController;
  inputFontSize = 16;
  contentLength = 0;

  aboutToAppear(): void {
    this.initData();
  }

  // 初始化数据
  initData() {
    const videoOperationData = new NEChatMoreOperationData();
    videoOperationData.operationTitle = "video";
    videoOperationData.type = NEChatMoreOperationType.Video;
    videoOperationData.imageSource = "app.media.ic_public_chat_photo";
    this.operationMoreDataList.push(videoOperationData);
    const fileOperationData = new NEChatMoreOperationData();
    fileOperationData.operationTitle = "file";
    fileOperationData.type = NEChatMoreOperationType.File;
    fileOperationData.imageSource = "app.media.ic_public_chat_file";
    this.operationMoreDataList.push(fileOperationData);
    NEEmojiManager.instance.setup();
  }

  toSendMessage() {
    console.log('net ease toSendMessage')
    this.text = '';
    let results = this.controller?.getSpans();
    console.log('net ease rich editor results:' + JSON.stringify(results))
    results?.forEach((item) => {
      if (typeof (item as RichEditorImageSpanResult)['imageStyle'] != 'undefined') {
        let resourcePath = (item as RichEditorImageSpanResult).valueResourceStr;
        if (resourcePath != null && resourcePath.toString().length > 0) {
          let path = resourcePath.toString();
          let splits = path.split("/")
          let fileName = splits[splits.length - 1];
          console.log('net ease file name :' + fileName)
          let emoji = NEEmojiManager.instance.getEmojiByName(String(fileName));
          if (emoji?.tag != null) {
            this.text += emoji.tag;
          }
          console.log('net ease current text ', this.text)
        }
      } else {
        this.text += (item as RichEditorTextSpanResult).value;
        console.log('net ease current text ', this.text)
      }
    })
  }

  build() {
    RelativeContainer() {
      RichEditor({ controller: this.controller })
        .backgroundColor("#FFFFFF")
        .height(40)
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "__container__", align: VerticalAlign.Top },
        })
        .placeholder($r('app.string.chat_send_tips', this.placeHolder))
        .onWillChange((value: RichEditorChangeValue) => {
          console.log('net ease test log: onWillChange')
          return true
        })
        .onDidChange((rangeBefore: TextRange, rangeAfter: TextRange) => {
          console.log('net ease onDidChange')
          console.log('net ease rangeBefore:' + JSON.stringify(rangeBefore))
          console.log('net ease rangeAfter:' + JSON.stringify(rangeAfter))
        })
        .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
          console.log('net ease test log: onSizeChange old value ', JSON.stringify(oldValue))
          console.log('net ease test log: onSizeChange new value ', JSON.stringify(newValue))

        })
        .onCut((event: CutEvent) => {
          event.preventDefault!()
          console.log('net ease ：onCut')
        })
        .onCopy((event: CopyEvent) => {
          event.preventDefault!()
          console.log('net ease ：onCopy')
        })
        .onPaste(() => {
          console.log('net ease ：onPaste')
        })
        .borderRadius(8)
        .id("chat_input")
        .onSubmit((type) => {
          if (type == EnterKeyType.Send) {
            console.log("net ease send input text message");
            if (this.onSendTextMessage) {
              this.onSendTextMessage();
            }
          }
        })
        .enterKeyType(EnterKeyType.Send)

      Row({ space: 0 }) {
        if (this.inputStyle === InputStyleType.Record) {
          NEImageButton({
            image: $r('app.media.ic_public_chat_speaker_select'), onDidClick: (): void => {
              console.log("net ease click speaker");
              if (this.onDidClickAudio) {
                inputMethod.getController().stopInputSession();
                this.onDidClickAudio()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_emoji"), onDidClick: (): void => {
              console.log("net ease click emoji");
              if (this.onDidClickEmoji) {
                inputMethod.getController().stopInputSession();
                this.onDidClickEmoji()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_image"), onDidClick: async (): Promise<void> => {
              console.log("net ease click image");
              if (this.onDidClickImage) {
                this.onDidClickImage()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_more"), onDidClick: (): void => {
              console.log("net ease click more");
              if (this.onDidClickMore) {
                inputMethod.getController().stopInputSession();
                this.onDidClickMore()
              }
            }
          })
            .width('25%')
            .height(40)
        } else if (this.inputStyle === InputStyleType.More) {
          NEImageButton({
            image: $r('app.media.ic_public_chat_speaker'), onDidClick: (): void => {
              console.log("net ease click speaker");
              if (this.onDidClickAudio) {
                inputMethod.getController().stopInputSession();
                this.onDidClickAudio()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_emoji"), onDidClick: (): void => {
              console.log("net ease click emoji");
              if (this.onDidClickEmoji) {
                inputMethod.getController().stopInputSession();
                this.onDidClickEmoji()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_image"), onDidClick: async (): Promise<void> => {
              console.log("net ease click image");
              if (this.onDidClickImage) {
                this.onDidClickImage()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_more_select"), onDidClick: (): void => {
              console.log("net ease click more");
              if (this.onDidClickMore) {
                inputMethod.getController().stopInputSession();
                this.onDidClickMore()
              }
            }
          })
            .width('25%')
            .height(40)
        } else if (this.inputStyle === InputStyleType.Emoji) {
          NEImageButton({
            image: $r('app.media.ic_public_chat_speaker'), onDidClick: (): void => {
              console.log("net ease click speaker");
              if (this.onDidClickAudio) {
                inputMethod.getController().stopInputSession();
                this.onDidClickAudio()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_emoji_select"), onDidClick: (): void => {
              console.log("net ease click emoji");
              if (this.onDidClickEmoji) {
                inputMethod.getController().stopInputSession();
                this.onDidClickEmoji()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_image"), onDidClick: async (): Promise<void> => {
              console.log("net ease click image");
              if (this.onDidClickImage) {
                this.onDidClickImage()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_more"), onDidClick: (): void => {
              console.log("net ease click more");
              if (this.onDidClickMore) {
                inputMethod.getController().stopInputSession();
                this.onDidClickMore()
              }
            }
          })
            .width('25%')
            .height(40)
        } else if (this.inputStyle === InputStyleType.None) {
          NEImageButton({
            image: $r('app.media.ic_public_chat_speaker'), onDidClick: (): void => {
              console.log("net ease click speaker");
              if (this.onDidClickAudio) {
                inputMethod.getController().stopInputSession();
                this.onDidClickAudio()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_emoji"), onDidClick: (): void => {
              console.log("net ease click emoji");
              if (this.onDidClickEmoji) {
                inputMethod.getController().stopInputSession();
                this.onDidClickEmoji()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_image"), onDidClick: async (): Promise<void> => {
              console.log("net ease click image");
              if (this.onDidClickImage) {
                this.onDidClickImage()
              }
            }
          })
            .width('25%')
            .height(40)

          NEImageButton({
            image: $r("app.media.ic_public_chat_more"), onDidClick: (): void => {
              console.log("net ease click more");
              if (this.onDidClickMore) {
                inputMethod.getController().stopInputSession();
                this.onDidClickMore()
              }
            }
          })
            .width('25%')
            .height(40)
        }

      }
      .width('100%')
      .height(60)
      .id("action_button")
      .alignRules({
        left: { anchor: "__container__", align: HorizontalAlign.Start },
        right: { anchor: "__container__", align: HorizontalAlign.End },
        top: { anchor: "chat_input", align: VerticalAlign.Bottom },
      })
    }.padding({ top: 6, left: 7, right: 7 })
  }
}