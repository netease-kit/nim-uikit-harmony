/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { NEImageButton } from './NEImageButton';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { NEEmojiManager } from '../manager/NEEmojiManager';
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
  @Param
  mute: boolean = false

  aboutToAppear(): void {
    this.initData();
  }

  @Monitor('mute')
  onMute(monitor: IMonitor) {
    if (this.mute) {
      this.controller?.deleteSpans()
      this.controller?.stopEditing()
    }
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

  build() {
    RelativeContainer() {
      RichEditor({ controller: this.controller })
        .backgroundColor(this.mute ? '#ffE3E4E4' : "#FFFFFF")
        .height(40)
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "__container__", align: VerticalAlign.Top },
        })
        .placeholder(this.mute ? $r('app.string.chat_team_all_mute') :
        $r('app.string.chat_send_tips', this.placeHolder))
        .onWillChange((value: RichEditorChangeValue) => {
          return true
        })
        .onDidChange((rangeBefore: TextRange, rangeAfter: TextRange) => {
        })
        .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {

        })
        .onCut((event: CutEvent) => {
          event.preventDefault!()
        })
        .onCopy((event: CopyEvent) => {
          event.preventDefault!()
        })
        .onPaste(() => {
        })
        .borderRadius(8)
        .id("chat_input")
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
          if (enterKey == EnterKeyType.Send) {
            if (this.onSendTextMessage) {
              this.onSendTextMessage();
              event.keepEditableState()
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

      if (this.mute) {
        Column()
          .alignRules({
            left: { anchor: "__container__", align: HorizontalAlign.Start },
            right: { anchor: "__container__", align: HorizontalAlign.End },
            top: { anchor: "__container__", align: VerticalAlign.Top },
            bottom: { anchor: "__container__", align: VerticalAlign.Bottom }
          })
          .width('100%')
          .height('100%')
      }
    }.padding({ top: 6, left: 7, right: 7 })
  }
}