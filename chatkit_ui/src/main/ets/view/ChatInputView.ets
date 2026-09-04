/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { Logger } from '@nimkit/common';
import { NEImageButton } from './NEImageButton';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { NEEmojiManager, NEEmojiParseResult } from '../manager/NEEmojiManager';
import { inputMethod } from '@kit.IMEKit';
import { V2NIMAIUser, V2NIMTeam } from '@nimsdk/base';
import { ChatAitDialog } from './ChatAitDialog';
import { TeamMemberCache } from '@nimkit/chatkit';
import { accountAll, ChatKitClient, ContactRepo, IMKitConfigCenter, TeamMemberWithUser } from '@nimkit/chatkit';
import { AitManager } from '../manager/ait/AitManager';
import { getReplyMessageText, getReplyMessageTitle, parseMessageText, sliceMessageText } from '../common/MessageHelper';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { ChatInfo } from '../model/ChatInfo';
import {
  collectRichInputTransferNodes,
  restoreMultiLineContent,
  RichInputTransferNode,
  splitSingleLineTransferNodes
} from '../common/InputTransferUtils';

export enum InputStyleType {
  // 底部无内容
  None = 1,
  // 展示表情输入框
  Emoji = 2,
  // 长按录音UI展示
  Record = 3,
  // 更多面板展示
  More = 4,
  // 多行输入模式（换行消息）
  Multiline = 5,
  // AI 助聊面板
  AiHelper = 6,
}

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
  // AI 助聊按钮点击
  @Param
  onDidClickAIHelper: () => void = () => {}
  @Param
  enableAIHelper: boolean = true
  /**
   * 输入框内容变化回调（用于"正在输入"功能）
   * @param hasText true 表示输入框有内容，false 表示输入框为空
   */
  @Param
  onInputTextChange: (hasText: boolean) => void = (_: boolean) => { /* nothing*/ };
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
  @Param
  showAitAll: boolean = true
  @Param
  showAIUserAit: boolean = false
  @Param
  showTeamMemberAit: boolean = true
  @Param
  aiUsers: V2NIMAIUser[] = []
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
  /**
   * 会话名称（用于多行模式 placeholder）
   */
  @Param
  conversationName: string = ''
  /**
   * 发送多行消息回调
   */
  @Param
  onSendMultiLineMessage?: (title: string, body: string) => void = undefined
  /**
   * 多行模式切换回调
   * @param isMultiline 是否切换到多行模式
   * @param transferTitle 切换时传递的标题（单行->多行：单行第一行；多行->单行：标题）
   * @param transferBody 切换时传递的正文（单行->多行：单行第二行起；多行->单行：正文内容）
   * @param transferBodyNodes 切换时传递的正文富文本节点（用于保留 emoji / @ 信息）
   */
  @Param
  onMultilineModeChange?: (
    isMultiline: boolean,
    transferTitle?: string,
    transferBody?: string,
    transferBodyNodes?: RichInputTransferNode[]
  ) => void = undefined
  /**
   * 撤回重编辑恢复多行内容的回调
   * 页面收到回调后设置自己的 multiLineTitle 和 multiLineBody
   */
  @Param
  onRestoreMultiLineContent?: (title: string, body: string, bodyNodes: RichInputTransferNode[]) => void = undefined
  /**
   * 撤回重编辑时恢复的多行内容（外部传入）
   * 格式: { title: string, body: string } 的 JSON 字符串
   */
  @Param
  revokeMultiLineContent: string = ''
  /**
   * 多行模式下的标题内容
   */
  @Local multiLineTitle: string = ''
  /**
   * 多行模式下的正文内容
   */
  @Local multiLineBody: string = ''
  /**
   * @弹框
   */
  chatAitDialogController: CustomDialogController = new CustomDialogController({
    builder: ChatAitDialog({
      teamId: this.teamId,
      team: this.team,
      showAitAll: this.showAitAll,
      showAIUser: this.showAIUserAit,
      showTeamMember: this.showTeamMemberAit,
      aiUsers: this.aiUsers,
      onSelectedAll: this.onSelectedAll.bind(this),
      onMemberSelected: this.onTeamMemberSelected.bind(this),
      onAIUserSelected: this.onAIUserSelected.bind(this)
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
  onMute() {
    if (this.mute) {
      this.controller?.deleteSpans()
      this.controller?.stopEditing()
    }
  }

  private canShowAIHelperButton(): boolean {
    return this.enableAIHelper && IMKitConfigCenter.enableAIChatHelper && !this.mute &&
      this.inputStyle !== InputStyleType.Multiline
  }

  private canShowRichTextButton(): boolean {
    return IMKitConfigCenter.enableRichTextMessage && !this.mute && this.inputStyle !== InputStyleType.Multiline
  }

  private getInputRightPadding(): number {
    let padding = 12
    if (this.canShowAIHelperButton()) {
      padding += 34
    }
    if (this.canShowRichTextButton()) {
      padding += 30
    }
    return padding
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
    this.addAitSpan(accountAll, aitValue)
  }

  /**
   * @单个人
   * @param member
   */
  onTeamMemberSelected(member: TeamMemberWithUser) {
    //输入框添加@信息
    let aitValue = member.getAitName() + this.blank
    this.addAitSpan(member.getAccId(), aitValue)
  }

  onAIUserSelected(aiUser: V2NIMAIUser) {
    let aitValue = (aiUser.name ?? aiUser.accountId) + this.blank
    this.addAitSpan(aiUser.accountId, aitValue)
  }

  private addAitSpan(accountId: string, aitValue: string) {
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
        accountId: accountId,
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
    if (this.showTeamMemberAit && this.teamId && this.teamId.length > 0) {
      let teamMemberCache = TeamMemberCache.getInstance()
      teamMemberCache.intTeamInfo(this.teamId, this.team)
      if (teamMemberCache.needFetchMember(this.teamId)) {
        await teamMemberCache.getMemberList()
      }
      // 检查是否有成员缺失userInfo，如果有则从云端获取
      await this.ensureMemberUserInfo(teamMemberCache)
    }
    this.chatAitDialogController.open()
  }

  private canShowAitDialog(): boolean {
    return (this.teamId !== undefined && this.teamId.length > 0) || (this.showAIUserAit && this.aiUsers.length > 0)
  }

  /**
   * 确保所有成员都有用户信息（userInfo），缺失的从云端获取
   * @param teamMemberCache
   */
  async ensureMemberUserInfo(teamMemberCache: TeamMemberCache) {
    const allMembers = teamMemberCache.getAllMembers()
    // 找出缺失 userInfo 的成员
    const missingUserInfoAccountIds = allMembers
      .filter((member) => !member.userInfo)
      .map((member) => member.getAccId())

    if (missingUserInfoAccountIds.length > 0) {
      try {
        // 从云端获取缺失的用户信息
        const userList = await ContactRepo.getUserListFromCloud(missingUserInfoAccountIds)
        // 更新到 TeamMemberCache
        teamMemberCache.onUserProfileChanged(userList)
      } catch (e) {
        Logger.error('ChatKitUI', `ensureMemberUserInfo failed: ${e}`)
      }
    }
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

  private getCurrentBuilderSpanOffsets(): number[] {
    const offsets: number[] = []
    const spans = this.controller?.getSpans() ?? []
    spans.forEach((span, spanOrder) => {
      if (!this.isAitEditorSpan(span)) {
        return
      }
      const textSpan = span as RichEditorTextSpanResult
      const spanRange = textSpan.spanPosition?.spanRange
      offsets.push(spanRange ? spanRange[0] : spanOrder)
    })
    return offsets
  }

  private syncBuilderSpanOffsets(): void {
    const offsets = this.getCurrentBuilderSpanOffsets()
    const length = Math.min(offsets.length, this.builderSpans.length)
    for (let index = 0; index < length; index++) {
      this.builderSpans[index].spanIndex = offsets[index]
    }
    if (this.builderSpans.length > offsets.length) {
      this.builderSpans.splice(offsets.length, this.builderSpans.length - offsets.length)
    }
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

  /**
   * 获取单行输入框的文本内容
   */
  getSingleLineTransferNodes(): RichInputTransferNode[] {
    this.syncBuilderSpanOffsets()
    return collectRichInputTransferNodes(this.controller?.getSpans() ?? [], this.builderSpans)
  }

  /**
   * 切换到多行输入模式
   * 单行 → 多行转换规则：
   * - 单行只有一行时 → 转到正文（不设置标题）
   * - 单行有多行时 → 第一行 → 标题，第二行起 → 正文
   */
  switchToMultilineMode() {
    inputMethod.getController().stopInputSession()
    const transferNodes = this.getSingleLineTransferNodes()
    const transferPayload = splitSingleLineTransferNodes(transferNodes)
    // 清空单行输入框
    this.controller?.deleteSpans()
    this.builderSpans.splice(0, this.builderSpans.length)

    this.onMultilineModeChange?.(
      true,
      transferPayload.title,
      transferPayload.bodyText,
      transferPayload.bodyNodes
    )
  }

  /**
   * 收起多行输入模式
   * 将多行 body 的内容传递回单行输入框
   */
  collapseToSingleLine() {
    // 获取多行 body 内容作为 transferText（标题不传递，只传递 body）
    const bodyText = this.multiLineBody.trim()
    // 清空多行内容
    this.multiLineTitle = ''
    this.multiLineBody = ''
    this.onMultilineModeChange?.(false, bodyText)
  }

  /**
   * 发送消息（多行模式）
   */
  sendMultiLineMessage() {
    const title = this.multiLineTitle.trim()
    const body = this.multiLineBody.trim()

    if (title.length === 0 && body.length === 0) {
      return // 内容为空，不发送
    }

    if (title.length > 0) {
      // 有标题，发送多行消息
      this.onSendMultiLineMessage?.(title, body)
    } else {
      // 无标题，仅有正文，发送普通文本消息
      // 将正文设置到 RichEditor 中然后发送
      this.controller?.addTextSpan(body)
      this.onSendTextMessage?.()
    }

    // 清空并收起
    this.multiLineTitle = ''
    this.multiLineBody = ''
    this.onMultilineModeChange?.(false)
  }

  /**
   * 监听撤回重编辑多行内容变化
   */
  @Monitor('revokeMultiLineContent')
  onRevokeMultiLineChanged() {
    if (this.revokeMultiLineContent && this.revokeMultiLineContent.length > 0) {
      try {
        const title = JSON.parse(this.revokeMultiLineContent)['title'] as string ?? ''
        const body = JSON.parse(this.revokeMultiLineContent)['body'] as string ?? ''
        const bodyNodes = JSON.parse(this.revokeMultiLineContent)['bodyNodes'] as RichInputTransferNode[] | undefined
        const restoredContent = restoreMultiLineContent(title, body, bodyNodes)
        // 关闭软键盘
        inputMethod.getController().stopInputSession()
        // 通过回调通知页面恢复内容并切换到多行模式
        if (title && title.length > 0) {
          this.onRestoreMultiLineContent?.(restoredContent.title, restoredContent.body, restoredContent.bodyNodes)
          this.onMultilineModeChange?.(true, restoredContent.title, restoredContent.body, restoredContent.bodyNodes)
        } else {
          // 仅有 body，设置到单行输入框
          this.controller?.addTextSpan(restoredContent.body)
        }
      } catch (e) {
        Logger.error('ChatKitUI', 'onRevokeMultiLineChanged parse error:', e)
      }
    }
  }

  /**
   * 设置多行内容（用于撤回重编辑）
   */
  setMultiLineContent(title: string, body: string) {
    if (title && title.length > 0) {
      this.multiLineTitle = title
      this.multiLineBody = body
    } else {
      // 仅设置 body 到单行输入框
      this.controller?.addTextSpan(body)
    }
  }

  /**
   * 发送按钮是否可用
   */
  canSendMultiLine(): boolean {
    return this.multiLineTitle.trim().length > 0 || this.multiLineBody.trim().length > 0
  }

  build() {
    RelativeContainer() {
      Column() {
        if (!this.mute && this.replyMsg) {
          Row() {
            Image($r('app.media.ic_chat_reply_close')).height(20).width(20).margin({ right: 12 })
              .onClick(() => {
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

        // 单行输入模式（始终存在，多行模式时隐藏）
        Stack({ alignContent: Alignment.TopEnd }) {
          RichEditor({ controller: this.controller })
            .backgroundColor(this.mute ? $r('app.color.color_chat_mute_bg') : $r('app.color.color_chat_page_bg'))
            .height(40)
            .width('100%')
            .padding({ right: this.getInputRightPadding() })
            .placeholder(this.mute ? $r('app.string.chat_team_all_mute') :
            $r('app.string.chat_send_tips', this.placeHolder))
            .onWillChange((value: RichEditorChangeValue) => {
              Logger.debug('ChatKitUI', `ChatInputView onWillChange before: ${value.rangeBefore}`)
              return true
            })
            .aboutToDelete(this.aboutToDelete)
            .onDidChange((rangeBefore: TextRange, rangeAfter: TextRange) => {
              Logger.debug('ChatKitUI', `ChatInputView onDidChange before ${rangeBefore.start} ~ ${rangeBefore.end} after ${rangeAfter.start} ~ ${rangeAfter.end}`)
              // Keep mention span offsets aligned after edits before them.
              this.syncBuilderSpanOffsets()
              this.inputSpans = this.controller?.getSpans() ?? []
              // 通知输入状态变化（用于"正在输入"功能）
              if (this.onInputTextChange) {
                const hasText = this.inputSpans.length > 0
                this.onInputTextChange(hasText)
              }
            })
            .onSelectionChange((range: RichEditorRange) => {
              Logger.debug('ChatKitUI', `ChatInputView onSelectionChange ${range.start} ~ ${range.end}`)
            })
            .onIMEInputComplete((result: RichEditorTextSpanResult) => {
              //记录输入内容
              this.inputSpans = this.controller?.getSpans() ?? []
              let value = result.value
              let indexStart: number = result.offsetInSpan[0]
              //span长度
              let spanLen = result.offsetInSpan[1] - result.offsetInSpan[0]
              Logger.debug('ChatKitUI', ` onIMEInputComplete value = ${value} index = ${indexStart} len = ${spanLen}}`)
              if (this.canShowAitDialog()) {
                //判断span 长度，解决复制粘贴问题
                if (spanLen === 1 && value.charAt(indexStart) === "@") {
                  //输入@
                  this.showAitDialog()
                }
              }
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

          // 右侧按钮组（AI助聊 + 多行扩展）
          Row({ space: 10 }) {
            // AI 助聊按钮
            if (this.canShowAIHelperButton()) {
              Image(this.inputStyle === InputStyleType.AiHelper ?
                $rawfile('ai_icon_highlight.png') : $rawfile('ic_chat_ai_helper.svg'))
                .width(24)
                .height(24)
                .onClick(() => {
                  this.onDidClickAIHelper?.()
                })
            }
            // 扩展按钮
            if (this.canShowRichTextButton()) {
              Image($r('app.media.ic_chat_input_expand'))
                .width(20)
                .height(20)
                .onClick(() => {
                  this.switchToMultilineMode()
                })
            }
          }
          .margin({ right: 8, top: 8 })
        }
        .width('100%')
        .height(40)
        .visibility(this.inputStyle === InputStyleType.Multiline ? Visibility.None : Visibility.Visible)

        // 底部工具栏（多行模式 / AI 助聊模式下隐藏）
        if (this.inputStyle !== InputStyleType.Multiline && this.inputStyle !== InputStyleType.AiHelper) {
          Row({ space: 0 }) {
            if (this.inputStyle === InputStyleType.Record) {
              NEImageButton({
                image: $r('app.media.ic_public_chat_speaker_select'), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click speaker");
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
                  Logger.info('ChatKitUI', "net ease click emoji");
                  if (this.onDidClickEmoji) {
                    inputMethod.getController().stopInputSession();
                    this.onDidClickEmoji()
                  }
                }
              })
                .width('25%')
                .height(40)

              NEImageButton({
                image: $r("app.media.ic_public_chat_image"), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click image");
                  if (this.onDidClickImage) {
                    this.onDidClickImage()
                  }
                }
              })
                .width('25%')
                .height(40)

              NEImageButton({
                image: $r("app.media.ic_public_chat_more"), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click more");
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
                  Logger.info('ChatKitUI', "net ease click speaker");
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
                  Logger.info('ChatKitUI', "net ease click emoji");
                  if (this.onDidClickEmoji) {
                    inputMethod.getController().stopInputSession();
                    this.onDidClickEmoji()
                  }
                }
              })
                .width('25%')
                .height(40)

              NEImageButton({
                image: $r("app.media.ic_public_chat_image"), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click image");
                  if (this.onDidClickImage) {
                    this.onDidClickImage()
                  }
                }
              })
                .width('25%')
                .height(40)

              NEImageButton({
                image: $r("app.media.ic_public_chat_more_select"), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click more");
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
                Logger.info('ChatKitUI', "net ease click speaker");
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
                Logger.info('ChatKitUI', "net ease click emoji");
                if (this.onDidClickEmoji) {
                  inputMethod.getController().stopInputSession();
                  this.onDidClickEmoji()
                }
              }
            })
              .width('25%')
              .height(40)

              NEImageButton({
                image: $r("app.media.ic_public_chat_image"), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click image");
                  if (this.onDidClickImage) {
                    this.onDidClickImage()
                  }
                }
              })
                .width('25%')
                .height(40)

              NEImageButton({
                image: $r("app.media.ic_public_chat_more"), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click more");
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
                  Logger.info('ChatKitUI', "net ease click speaker");
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
                  Logger.info('ChatKitUI', "net ease click emoji");
                  if (this.onDidClickEmoji) {
                    inputMethod.getController().stopInputSession();
                    this.onDidClickEmoji()
                  }
                }
              })
                .width('25%')
                .height(40)

              NEImageButton({
                image: $r("app.media.ic_public_chat_image"), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click image");
                  if (this.onDidClickImage) {
                    this.onDidClickImage()
                  }
                }
              })
                .width('25%')
                .height(40)

              NEImageButton({
                image: $r("app.media.ic_public_chat_more"), onDidClick: (): void => {
                  Logger.info('ChatKitUI', "net ease click more");
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
        }
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
