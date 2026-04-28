/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMTeam } from '@nimsdk/base';
import { ChatAitDialog } from './ChatAitDialog';
import { TeamMemberCache, TeamMemberWithUser } from '@nimkit/chatkit';
import { ContactRepo } from '@nimkit/chatkit';
import { AitManager } from '../manager/ait/AitManager';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { AitEditorSpan } from './ChatInputView';
import { contentOfMessage, getReplyMessageTitle } from '../common/MessageHelper';
import { ChatTeamInfo } from '../model/ChatTeamInfo';
import { ChatUserInfo } from '../model/ChatUserInfo';
import { NECommonUtils } from '@nimkit/common';
import {
  collectRichInputTransferNodes,
  getRichInputTransferText,
  RichInputTransferNode,
  RichInputTransferNodeType
} from '../common/InputTransferUtils';

/**
 * 多行输入面板组件
 * 
 * 功能：
 * - 标题输入框（TextInput）
 * - 正文输入框（RichEditor，支持 @ 功能）
 * - 发送按钮
 * - 收起按钮
 */
@ComponentV2
export struct MultiLineInputView {
  /**
   * 群 ID（单聊时为 undefined）
   */
  @Param
  teamId?: string = undefined

  /**
   * 群对象（单聊时为 undefined）
   */
  @Param
  team?: V2NIMTeam = undefined

  /**
   * 会话名称（用于 placeholder）
   */
  @Param @Require
  conversationName: string = ''

  /**
   * 标题内容（组件内部管理）
   */
  @Local
  multiLineTitle: string = ''

  /**
   * 初始标题内容（用于撤回重编辑、模式切换）
   */
  @Param
  initialTitle: string = ''

  /**
   * 初始正文内容（用于撤回重编辑、模式切换）
   */
  @Param
  initialBody: string = ''

  /**
   * 初始正文富文本节点（用于模式切换时保留 emoji / @ 信息）
   */
  @Param
  initialBodyNodes: RichInputTransferNode[] = []

  /**
   * AitManager 实例（用于管理 @ 用户）
   */
  @Param
  aitManager?: AitManager = undefined

  /**
   * 回复消息对象
   */
  @Param
  replyMsg: NIMMessageInfo | undefined = undefined

  /**
   * 聊天信息（用于回复预览显示）
   */
  @Param
  chatInfo?: ChatTeamInfo | ChatUserInfo = undefined

  /**
   * 关闭回复回调
   */
  @Param
  onCloseReply?: () => void = undefined

  /**
   * 发送多行消息回调
   * @param title 标题
   * @param body 正文
   */
  @Param
  onSendMultiLineMessage?: (title: string, body: string) => void = undefined

  /**
   * 收起按钮点击回调
   * @param title 标题内容
   * @param bodyText 正文纯文本
   * @param bodyNodes 正文富文本节点
   */
  @Param
  onCollapseClick?: (title: string, bodyText: string, bodyNodes: RichInputTransferNode[]) => void = undefined

  /**
   * 输入框内容变化回调（用于"正在输入"功能）
   * @param hasText true 表示输入框有内容，false 表示输入框为空
   */
  @Param
  onInputTextChange?: (hasText: boolean) => void = undefined

  /**
   * 组件就绪回调（传递组件实例给父组件）
   */
  @Param
  onComponentReady?: (instance: MultiLineInputView) => void = undefined

  /**
   * 正文 RichEditor controller
   */
  multiLineBodyController: RichEditorController = new RichEditorController()

  /**
   * @ 用户的 span 列表
   */
  @Local builderSpans: AitEditorSpan[] = []

  /**
   * 正文是否有内容（用于控制发送按钮状态）
   */
  @Local hasBodyContent: boolean = false

  /**
   * @ 选择器 Dialog Controller
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

  /**
   * @All 选择回调
   */
  onSelectedAll() {
    this.chatAitDialogController.close()
    // TODO: 实现 @All 逻辑
  }

  /**
   * 选择群成员回调
   * @param member 群成员对象
   */
  onTeamMemberSelected(member: TeamMemberWithUser) {
    this.chatAitDialogController.close()
    this.addAitUser(member)
  }

  /**
   * 显示 @ 选择器
   */
  async showAitDialog() {
    let teamMemberCache = TeamMemberCache.getInstance()
    if (teamMemberCache.needFetchMember()) {
      await teamMemberCache.getMemberList()
    }
    // 检查是否有成员缺失 userInfo，如果有则从云端获取
    await this.ensureMemberUserInfo(teamMemberCache)
    this.chatAitDialogController.open()
  }

  /**
   * 确保所有成员都有用户信息
   */
  async ensureMemberUserInfo(teamMemberCache: TeamMemberCache) {
    const allMembers = teamMemberCache.getAllMembers()
    const missingUserInfoAccountIds = allMembers
      .filter((member) => !member.userInfo)
      .map((member) => member.getAccId())

    if (missingUserInfoAccountIds.length > 0) {
      try {
        const userList = await ContactRepo.getUserListFromCloud(missingUserInfoAccountIds)
        teamMemberCache.onUserProfileChanged(userList)
      } catch (e) {
        console.error(`MultiLineInputView ensureMemberUserInfo failed: ${e}`)
      }
    }
  }

  /**
   * 添加 @ 用户（完全参考 ChatInputView 的实现）
   */
  addAitUser(member: TeamMemberWithUser) {
    if (!this.multiLineBodyController) {
      return
    }
    
    const controller = this.multiLineBodyController
    let aitValue = member.getAitName() + ' '
    const offset = controller.getCaretOffset()
    
    // 删除原来的 @ 符号
    const range: RichEditorRange = { start: offset - 1, end: offset }
    controller.deleteSpans(range)
    
    // 在删除后的位置添加 @ span（蓝色高亮）
    const spanOffset = offset - 1
    controller.addBuilderSpan(() => this.AtSpan(aitValue), {
      offset: spanOffset
    })
    
    // 记录 @ span 信息（注意：不在这里调用 aitManager.addAitWithText，发送时才调用）
    let aitSpan: AitEditorSpan = {
      spanIndex: spanOffset,
      accountId: member.getAccId(),
      value: '@' + aitValue,
    }
    
    // 按照 spanIndex 顺序插入
    let index = this.builderSpans.findIndex((e) => e.spanIndex >= spanOffset)
    if (index < 0) {
      this.builderSpans.push(aitSpan)
    } else {
      this.builderSpans.splice(index, 0, aitSpan)
    }
  }

  /**
   * 通过用户 ID 添加 @ 用户（用于回复时自动 @）
   * 参考 ChatTeamPage.addAitUserById 的实现
   */
  async addAitUserById(senderId: string) {
    if (!this.multiLineBodyController) {
      return
    }
    
    let sendMember = await TeamMemberCache.getInstance().getMemberById(senderId)
    if (!sendMember) {
      return
    }
    
    const controller = this.multiLineBodyController
    let aitValue = '@' + sendMember.getAitName() + ' '
    const offset = controller.getCaretOffset()
    
    // 直接在当前光标位置添加 @ span（回复时不需要删除 @）
    controller.addBuilderSpan(() => this.AtSpan(aitValue), {
      offset: offset
    })
    
    // 记录 @ span 信息
    let aitSpan: AitEditorSpan = {
      spanIndex: offset,
      accountId: senderId,
      value: aitValue,
    }
    
    this.builderSpans.push(aitSpan)
  }

  /**
   * @ 用户名高亮显示（蓝色）
   */
  @Builder
  AtSpan(nickname: string) {
    Text(`@${nickname}`)
      .fontColor('#FF337EFF')
  }

  /**
   * 判断是否是 @ span（参考 ChatInputView）
   */
  isAitEditorSpan(span: RichEditorImageSpanResult | RichEditorTextSpanResult, offset?: number): boolean {
    if (offset !== undefined && offset >= 0) {
      const buildSpan = this.builderSpans.find(e => e.spanIndex === offset)
      if (!buildSpan) {
        return false
      }
    }

    return !(span as RichEditorTextSpanResult).value &&
      !(span as RichEditorImageSpanResult).valueResourceStr?.toString().replaceAll(' ', '')
  }

  /**
   * 从 RichEditor 提取纯文本（参考 ChatTeamPage.getMessageText()）
   * 同时调用 aitManager.addAitWithText() 记录 @ 信息
   */
  getMultiLineBodyText(): string {
    // 清空 aitManager（每次获取文本时重新计算）
    if (this.aitManager) {
      this.aitManager.cleanAit()
    }

    const nodes = this.getMultiLineBodyTransferNodes()
    let text = ''
    nodes.forEach((node) => {
      if (node.type === RichInputTransferNodeType.Ait && this.aitManager) {
        this.aitManager.addAitWithText(node.accountId ?? '', node.text, text.length)
      }
      text += node.text
    })

    return text
  }

  getMultiLineBodyTransferNodes(): RichInputTransferNode[] {
    if (!this.multiLineBodyController) {
      return []
    }

    return collectRichInputTransferNodes(this.multiLineBodyController.getSpans(), this.builderSpans)
  }

  private restoreBodyNodes(bodyNodes: RichInputTransferNode[]) {
    this.multiLineBodyController.deleteSpans()
    this.builderSpans = []

    bodyNodes.forEach((node) => {
      if (node.type === RichInputTransferNodeType.Text) {
        if (node.text.length > 0) {
          this.multiLineBodyController.addTextSpan(node.text)
        }
        return
      }

      if (node.type === RichInputTransferNodeType.Emoji) {
        if (node.emojiFile) {
          this.multiLineBodyController.addImageSpan($rawfile(`emoji/${node.emojiFile}`), {
            imageStyle: { size: [16, 16] }
          })
        }
        return
      }

      const spanOffset = this.multiLineBodyController.getCaretOffset()
      const aitDisplayValue = node.text.startsWith('@') ? node.text.substring(1) : node.text
      this.multiLineBodyController.addBuilderSpan(() => this.AtSpan(aitDisplayValue), {
        offset: spanOffset
      })
      this.builderSpans.push({
        spanIndex: spanOffset,
        accountId: node.accountId ?? '',
        value: node.text
      })
    })
  }

  /**
   * 清空输入内容
   */
  clearContent() {
    this.multiLineTitle = ''
    // 清空 RichEditor（不带参数的 deleteSpans() 会删除所有内容）
    if (this.multiLineBodyController) {
      this.multiLineBodyController.deleteSpans()
    }
    this.builderSpans = []
    this.hasBodyContent = false
    if (this.aitManager) {
      this.aitManager.cleanAit()
    }
  }

  /**
   * 设置多行内容（用于撤回重编辑）
   */
  setContent(title: string, body: string, bodyNodes: RichInputTransferNode[] = []) {
    // 设置标题
    this.multiLineTitle = title
    // 清空并设置正文
    if (this.multiLineBodyController) {
      if (bodyNodes.length > 0) {
        this.restoreBodyNodes(bodyNodes)
        this.hasBodyContent = getRichInputTransferText(bodyNodes).trim().length > 0
      } else if (body && body.length > 0) {
        this.multiLineBodyController.deleteSpans()
        this.multiLineBodyController.addTextSpan(body)
        this.hasBodyContent = true
      } else {
        this.multiLineBodyController.deleteSpans()
        this.hasBodyContent = false
      }
    }
    // 清空 @ 信息
    if (bodyNodes.length <= 0) {
      this.builderSpans = []
    }
    if (this.aitManager) {
      this.aitManager.cleanAit()
    }
  }

  /**
   * 发送消息
   */
  sendMessage() {
    const title = this.multiLineTitle.trim()
    const body = this.getMultiLineBodyText().trim()

    if (title.length === 0 && body.length === 0) {
      NECommonUtils.showToast($r('app.string.null_message_not_support'))
      return
    }

    // 先调用回调（让 Page 层获取数据）
    if (this.onSendMultiLineMessage) {
      this.onSendMultiLineMessage(title, body)
    }

    // 回调后再清空内容
    this.clearContent()
  }

  /**
   * 收起按钮点击
   * 多行 → 单行转换规则：
   * - 多行的标题 → 单行的第一行
   * - 多行的正文 → 单行的后续行
   */
  handleCollapseClick() {
    const title = this.multiLineTitle.trim()
    const bodyNodes = this.getMultiLineBodyTransferNodes()
    const bodyText = getRichInputTransferText(bodyNodes)
    
    // 清空内容
    this.clearContent()
    
    // 回调通知 Page 层，回传标题和正文
    if (this.onCollapseClick) {
      this.onCollapseClick(title, bodyText, bodyNodes)
    }
  }

  /**
   * 检查并通知输入状态变化（用于"正在输入"功能）
   */
  private checkAndNotifyInputChange() {
    // 更新正文内容状态（用于发送按钮高亮）
    const bodyText = this.getMultiLineBodyText().trim()
    this.hasBodyContent = bodyText.length > 0
    
    // 通知"正在输入"状态变化
    if (this.onInputTextChange) {
      const hasText = this.multiLineTitle.trim().length > 0 || bodyText.length > 0
      this.onInputTextChange(hasText)
    }
  }

  /**
   * 组件生命周期：组件即将出现
   */
  aboutToAppear() {
    // 通知父组件，传递组件实例
    if (this.onComponentReady) {
      this.onComponentReady(this)
    }
  }

  build() {
    Column() {
      // 回复预览（如果有）
      if (this.replyMsg && this.chatInfo) {
        Row() {
          Image($r('app.media.ic_chat_reply_close')).height(20).width(20).margin({ right: 12 })
            .onClick(() => {
              if (this.onCloseReply) {
                this.onCloseReply()
              }
            })
          Text(getReplyMessageTitle(this.replyMsg, this.chatInfo) + contentOfMessage(this.replyMsg.message))
            .fontSize($r('app.float.chat_desc_text_font_size'))
            .fontColor($r('app.color.color_chat_desc'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .height(32)
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ bottom: 4 })
      }

      // 标题栏（标题输入框 + 收起按钮）
      Row() {
        TextInput({ text: this.multiLineTitle, placeholder: '请输入标题' })
          .layoutWeight(1)
          .height(40)
          .fontSize(16)
          .backgroundColor($r('app.color.color_chat_page_bg'))
          .borderRadius(8)
          .onChange((value: string) => {
            this.multiLineTitle = value
            // 通知输入状态变化（用于"正在输入"功能）
            this.checkAndNotifyInputChange()
          })
          .maxLength(20)

        // 收起按钮
        Image($r('app.media.ic_chat_input_collapse'))
          .width(24)
          .height(24)
          .margin({ left: 8 })
          .onClick(() => {
            this.handleCollapseClick()
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 正文区域（RichEditor + 发送按钮）
      Stack({ alignContent: Alignment.BottomEnd }) {
        RichEditor({ controller: this.multiLineBodyController })
          .width('100%')
          .height(80)
          .placeholder(`发送给 ${this.conversationName}`)
          .backgroundColor($r('app.color.color_chat_page_bg'))
          .borderRadius(8)
          .id('multiline_body_input')
          .onDidChange((rangeBefore: TextRange, rangeAfter: TextRange) => {
            // 通知输入状态变化（用于"正在输入"功能）
            this.checkAndNotifyInputChange()
          })
          .onIMEInputComplete((result: RichEditorTextSpanResult) => {
            // 监听输入，检测 @ 触发（仅群聊）
            if (!this.teamId) {
              return
            }
            
            let value = result.value
            let indexStart: number = result.offsetInSpan[0]
            let spanLen = result.offsetInSpan[1] - result.offsetInSpan[0]
            
            if (spanLen === 1 && value.charAt(indexStart) === "@") {
              this.showAitDialog()
            }
          })
          .onReady(() => {
            // 初始化时设置内容（撤回重编辑、模式切换传递内容）
            if (this.initialTitle && this.initialTitle.length > 0) {
              this.multiLineTitle = this.initialTitle
            }
            if (this.initialBodyNodes.length > 0) {
              this.restoreBodyNodes(this.initialBodyNodes)
              this.hasBodyContent = getRichInputTransferText(this.initialBodyNodes).trim().length > 0
            } else if (this.initialBody && this.initialBody.length > 0) {
              this.multiLineBodyController.addTextSpan(this.initialBody)
              this.hasBodyContent = true
            }
          })
          .enableDataDetector(true)
          .dataDetectorConfig({
            types: [TextDataDetectorType.PHONE_NUMBER, TextDataDetectorType.URL, TextDataDetectorType.EMAIL],
          })

        // 发送按钮
        Image($r('app.media.ic_chat_send'))
          .width(28)
          .height(28)
          .margin({ right: 8, bottom: 8 })
          .opacity((this.multiLineTitle.trim().length > 0 || this.hasBodyContent) ? 1.0 : 0.4)
          .onClick(() => {
            this.sendMessage()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignRules({
      left: { anchor: "__container__", align: HorizontalAlign.Start },
      right: { anchor: "__container__", align: HorizontalAlign.End },
      top: { anchor: "__container__", align: VerticalAlign.Top }
    })
  }
}
