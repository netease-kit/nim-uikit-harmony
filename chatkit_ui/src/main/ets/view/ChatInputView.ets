/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { NEImageButton } from './NEImageButton';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { NEEmojiManager, NEEmojiParseResult } from '../manager/NEEmojiManager';
import { inputMethod } from '@kit.IMEKit';
import { V2NIMTeam } from '@nimsdk/base';
import { ChatAitDialog } from './ChatAitDialog';
import { TeamMemberCache } from '@nimkit/chatkit/src/main/ets/cache/TeamMemberCache';
import { accountAll, ChatKitClient, TeamMemberWithUser } from '@nimkit/chatkit';
import { AitManager } from '../manager/ait/AitManager';
import { getReplyMessageText, getReplyMessageTitle, parseMessageText, sliceMessageText } from '../common/MessageHelper';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { ChatInfo } from '../model/ChatInfo';

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
  inputSpans: Array<RichEditorImageSpanResult | RichEditorTextSpanResult> = []
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
  @Param @Require
  onDidClickCloseReply?: () => void;
  @Param inputStyle: InputStyleType = InputStyleType.None;
  @Param @Require
  controller?: RichEditorController;
  inputFontSize = 16;
  contentLength = 0;
  @Param
  mute: boolean = false
  //群ID
  @Param
  teamId?: string = undefined
  //群
  @Param
  team?: V2NIMTeam = undefined
  //空格符
  blank: string = ' ';
  @Param
  aitManager?: AitManager = undefined
  //@的Span
  @Param
  builderSpans: AitEditorSpan[] = [];
  @Param
  replyMsg: NIMMessageInfo | undefined = undefined
  @Param
  chatInfo: ChatInfo | undefined = undefined
  private isPasteText = false
  /**
   * @弹框
   */
  chatAitDialogController: CustomDialogController = new CustomDialogController({
    builder: ChatAitDialog({
      teamId: this.teamId,
      team: this.team,
      onSelectedAll: this.onSelectedAll.bind(this),
      onMemberSelected: this.onTeamMemberSelected.bind(this)
    }),
    openAnimation: {
      curve: Curve.Linear,
      playMode: PlayMode.Alternate
    },
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.White,
    height: '60%',
    width: '100%',
    customStyle: true
  })

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

  /**
   * @所有人
   */
  onSelectedAll() {
    //输入框添加@信息
    let aitValue = getContext().resourceManager.getStringByNameSync('chat_team_ait_all') + this.blank

    //输入框添加@信息
    if (this.controller) {
      const controller = this.controller;
      const offset = controller.getCaretOffset();
      const range: RichEditorRange = { start: offset - 1, end: offset };
      controller.deleteSpans(range);
      const spanOffset = offset - 1
      controller.addBuilderSpan(() => this.AtSpan(aitValue), {
        offset: spanOffset
      });
      let aitSpan: AitEditorSpan = {
        spanIndex: spanOffset,
        accountId: accountAll,
        value: '@' + aitValue
      }
      let index = this.builderSpans.findIndex((e) => e.spanIndex >= spanOffset)
      if (index < 0) {
        this.builderSpans.push(...[aitSpan])
      } else {
        this.builderSpans.splice(index, 0, aitSpan)
      }

    }
  }

  /**
   * @单个人
   * @param member
   */
  onTeamMemberSelected(member: TeamMemberWithUser) {
    //输入框添加@信息
    let aitValue = member.getAitName() + this.blank
    if (this.controller) {
      const controller = this.controller;
      const offset = controller.getCaretOffset();
      const range: RichEditorRange = { start: offset - 1, end: offset };
      controller.deleteSpans(range);
      const spanOffset = offset - 1
      controller.addBuilderSpan(() => this.AtSpan(aitValue), {
        offset: spanOffset
      });
      let aitSpan: AitEditorSpan = {
        spanIndex: spanOffset,
        accountId: member.getAccId(),
        value: '@' + aitValue,
      }
      let index = this.builderSpans.findIndex((e) => e.spanIndex >= spanOffset)
      if (index < 0) {
        this.builderSpans.push(...[aitSpan])
      } else {
        this.builderSpans.splice(index, 0, aitSpan)
      }
    }
  }

  @Builder
  AtSpan(nickname: string) {
    Text(`@${nickname}`)
      .fontColor('#FF337EFF');
  }

  /**
   * 显示@的弹框
   */
  async showAitDialog() {
    let teamMemberCache = TeamMemberCache.getInstance()
    if (teamMemberCache.needFetchMember()) {
      await teamMemberCache.getMemberList()
    }
    this.chatAitDialogController.open()
  }

  /**
   * 是否是@的span
   * @param span
   * @returns
   */
  isAitEditorSpan(span: RichEditorImageSpanResult | RichEditorTextSpanResult, offset?: number): boolean {
    if (offset !== undefined && offset >= 0) {
      const buildSpan = this.builderSpans.find(e => e.spanIndex === offset)
      if (!buildSpan) {
        return false
      }
    }

    return !(span as RichEditorTextSpanResult).value &&
      !(span as RichEditorImageSpanResult).valueResourceStr?.toString().replaceAll(' ', '');
  }

  /**
   * 是否有选中
   * @param controller
   * @returns
   */
  hasSelection(controller: RichEditorController) {
    const selection = controller.getSelection().selection;
    return selection[0] !== selection[1];
  }

  /**
   * 删除@Span
   */
  deleteAitEditorSpan() {
    const controller = this.controller;
    if (controller) {
      const range: RichEditorRange = { end: controller.getCaretOffset() };
      const index = this.getAitEditorSpanCount(controller, range) - 1;
      this.builderSpans.splice(index, 1);
    }
  }

  /**
   * 获取@Span的内容
   * @param controller
   * @param range
   * @returns
   */
  getAitEditorSpanCount(controller: RichEditorController, range: RichEditorRange) {
    return controller.getSpans(range).reduce((count: number, span) => {
      return this.isAitEditorSpan(span) ? count + 1 : count;
    }, 0);
  }

  /**
   * 删除操作
   */
  aboutToDelete: (value: RichEditorDeleteValue) => boolean = value => {
    ChatKitClient.logger?.debug('NEChatInputView', 'aboutToDelete')
    const controller = this.controller;
    const span = value.richEditorDeleteSpans[0];
    if (controller && span && this.isAitEditorSpan(span, value.offset)) {
      this.deleteAitEditorSpan();
    }
    return true;
  }

  build() {
    RelativeContainer() {
      Column() {
        if (!this.mute && this.replyMsg) {
          Row() {
            Image($r('app.media.ic_chat_reply_close')).height(20).width(20).margin({ right: 12 })
              .onClick((event) => {
                this.onDidClickCloseReply?.()
              })
            Text() {
              if (this.chatInfo) {
                Span(getReplyMessageTitle(this.replyMsg, this.chatInfo))
                  .fontSize($r('app.float.chat_desc_text_font_size'))
                  .textCase(TextCase.Normal)
                  .fontColor($r('app.color.color_chat_desc'))
              }

              ForEach(sliceMessageText(parseMessageText(getReplyMessageText(this.replyMsg)), 30),
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
            .width('90%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .ellipsisMode(EllipsisMode.END)
            .fontColor($r('app.color.color_chat_desc'))
            .fontSize($r('app.float.chat_desc_text_font_size'))
          }
          .height(32)
          .justifyContent(FlexAlign.Start)
          .width('100%')
        }

        RichEditor({ controller: this.controller })
          .backgroundColor(this.mute ? $r('app.color.color_chat_mute_bg') : $r('app.color.color_chat_page_bg'))
          .height(40)
          .placeholder(this.mute ? $r('app.string.chat_team_all_mute') :
          $r('app.string.chat_send_tips', this.placeHolder))
          .onWillChange((value: RichEditorChangeValue) => {
            console.debug(`ChatInputView onWillChange before: ${value.rangeBefore}`)
            return true
          })
          .aboutToDelete(this.aboutToDelete)
          .onDidChange((rangeBefore: TextRange, rangeAfter: TextRange) => {
            console.debug(`ChatInputView onDidChange before ${rangeBefore.start} ~ ${rangeBefore.end} after ${rangeAfter.start} ~ ${rangeAfter.end}`)
            this.isPasteText = false
            this.inputSpans = this.controller?.getSpans() ?? []
          })
          .onSelectionChange((range: RichEditorRange) => {
            console.debug(`ChatInputView onSelectionChange ${range.start} ~ ${range.end}`)
          })
          .onIMEInputComplete((result: RichEditorTextSpanResult) => {
            //记录输入内容
            this.inputSpans = this.controller?.getSpans() ?? []
            let value = result.value
            let indexStart: number = result.offsetInSpan[0]
            //span长度
            let spanLen = result.offsetInSpan[1] - result.offsetInSpan[0]
            console.debug(` onIMEInputComplete value = ${value} index = ${indexStart} len = ${spanLen}}`)
            if (this.teamId && this.teamId.length > 0) {
              //判断span 长度，解决复制粘贴问题
              if (spanLen === 1 && value.charAt(indexStart) === "@") {
                //输入@
                this.showAitDialog()
              }

            }
          })
          .onCut((event: CutEvent) => {
            console.debug(`ChatInputView onCut`)
            event.preventDefault!()
          })
          .onCopy((event: CopyEvent) => {
            console.debug(`ChatInputView onCopy`)

            event.preventDefault!()
          })
          .onPaste((event: PasteEvent) => {
            this.isPasteText = true
            console.debug(`ChatInputView onPaste`)
          })
          .borderRadius(8)
          .id('chat_edit_input')
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
      }.padding({ top: 6, left: 7, right: 7 })

      if (this.mute) {
        Column()
          .alignRules({
            left: { anchor: "__container__", align: HorizontalAlign.Start },
            right: { anchor: "__container__", align: HorizontalAlign.End },
            top: { anchor: "__container__", align: VerticalAlign.Top },
            bottom: { anchor: "__container__", align: VerticalAlign.Bottom }
          })
          .backgroundColor($r('app.color.color_chat_mute_bg'))
          .opacity(0.4)
          .width('100%')
          .height('100%')
      }
    }
  }
}

export interface AitEditorSpan {
  spanIndex: number,
  accountId: string
  value: string
}