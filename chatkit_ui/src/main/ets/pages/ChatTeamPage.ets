/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatTeamInfo } from '../model/ChatTeamInfo';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { MessageComponent } from '../view/MessageComponent';
import { ChatTeamViewModel } from '../viewmodel/ChatTeamViewModel';
import { AitEditorSpan, InputStyleType, NEChatInputView } from '../view/ChatInputView';
import { NEChatEmojiView } from '../view/NEChatEmojiView';
import { NEEmojiManager, NEEmojiParseResult, NIMEmoticonType } from '../manager/NEEmojiManager';
import { NEChatMoreOperation } from '../view/ChatMoreOperationLayout';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { NEAudioRecordView } from '../view/NEAudioRecordView';
import {
  DoubleAlertDialog,
  ImagesIndexModel,
  ImageViewDialog,
  MediaUtils,
  NavigationBackBuilder,
  NECommonUtils,
  NetworkBrokenBuilder,
  PermissionsUtils,
  VideoViewerDialog
} from '@nimkit/common';
import { NECameraSelectView } from '../view/NECameraSelectView';
import { common } from '@kit.AbilityKit';
import { cameraPicker } from '@kit.CameraKit';
import { LengthMetrics, window } from '@kit.ArkUI';
import { NERectData } from '../model/NERectData';
import { MessageOperationView } from '../view/MessageOperationView';
import { MessageOperationItem, MessageOperationType } from '../model/MessageOperationItem';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { DeviceUtils } from '../common/DeviceUtils';
import {
  V2NIMMessage,
  V2NIMMessageAudioAttachment,
  V2NIMMessageLocationAttachment,
  V2NIMMessageSendingState,
  V2NIMMessageType
} from '@nimsdk/base';
import { ChatConst } from '../constants/ChatConst';
import {
  ChatKitClient,
  ConversationRepo,
  conversationSelectLimitCount,
  ConversationSelectParam,
  CustomMessageUtils,
  ErrorUtils,
  MergedMessageAttachment,
  mergedMessageCustomType,
  mergedMessageLimitCount,
  mergedMessageMaxDepth,
  singleMessageLimitCount,
  TeamMemberCache,
  TeamSettingParam
} from '@nimkit/chatkit';
import { TeamExitDialogParam, TeamExitWarningDialog } from '../view/TeamExitWarningDialog';
import { AudioPlayerManager } from '../manager/AudioPlayerManager';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import { ForwardMessageDialog } from '../view/ForwardMessageDialog';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import {
  downLoadAndOpenFile,
  getAitNodes,
  getMessageImageUrl,
  getMessageImageUrls,
  getMessageVideoRatio,
  getMessageVideoUrl,
  parseMessageText
} from '../common/MessageHelper';
import { computeOperateViewHeight, computeOperateViewWidth, setupMoreOperationData } from '../common/ChatUtils';
import { sceneMap } from '@kit.MapKit';
import { ChatMultiSelectView } from '../view/ChatMultiSelectView';
import { AitManager } from '../manager/ait/AitManager';
import { ChatAitNode } from '../model/ChatAitNode';
import { TextMessageDetailDialog } from '../view/TextMessageDetailDialog';
import { FraudTipView } from '../view/FraudTipView';
import { HashMap } from '@kit.ArkTS';
import { IsReceiveMsgOperation } from '../model/IsReceiveMsg';

@ComponentV2
export struct ChatTeamPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local chatTeamInfo: ChatTeamInfo = new ChatTeamInfo('');
  chatViewModel: ChatTeamViewModel = new ChatTeamViewModel();
  // 底部扩展区域高度，默认为0
  @Local expandHeight: number = 0;
  @Local inputStyle: InputStyleType = InputStyleType.None;
  operationMoreDataList: Array<NEChatMoreOperationData> = Array();
  @Local showMultiSelect: boolean = false;
  @Local multiSelectCount: number = 0;
  @Local hideInput: boolean = false;
  @Local scrollHeight: number = 0;
  @Local showOperationView: boolean = false;
  conversationId: string = '';
  // 长按操作弹窗的边距值
  operationViewMargin: number = 12;
  defaultInputViewHeight: number = 0;
  // 长按操作选中的消息
  @Local operationMsg: NIMMessageInfo | undefined = undefined;
  @Local replyMsg: NIMMessageInfo | undefined = undefined;
  textMessageDetailDialog: CustomDialogController | undefined = undefined;
  operationRect: NERectData = new NERectData();
  screenHeight: number = 0;
  screenWidth: number = 0;
  keyboardHeight: number = 0
  //导航栏高度，用于计算弹窗位置
  navBarHeight: number = 80;
  // 底部输入框以及固定按钮操作栏高度
  @Local bottomHeight: number = 105;
  bottomMargin: number = 100;
  bottomWithReplyHeight: number = 135;
  controller: RichEditorController = new RichEditorController()
  //@所在的span
  builderSpans: AitEditorSpan[] = [];
  // 接受消息标记
  msgSize: number = 0;
  // 列表滚动位置
  listScrollStartPosition: number = 0;
  listScrollEndPosition: number = 0;
  //首次加载数据滚动到底部
  firstLoadData: boolean = true;
  // 新增：是否处于底部
  @Local isAtBottom: boolean = true;
  // 新增：是否正在滚动到底部（用于处理连续收到消息的情况）
  isScrollingToBottom: boolean = false;
  // 新增：新消息计数
  @Local newMessageCount: number = 0;
  @Local newMessageMap: HashMap<string, V2NIMMessage> = new HashMap() // 和 newMessageCount 同步操作的，用于记录 newMessage 里面有的消息
  // 新增：是否显示滚动到新消息按钮
  @Local showScrollToNewMessageButton: boolean = false;
  // 新增：tipBannerArea 的高度（防诈条+断网条）
  @Local tipBannerHeight: number = 0;
  // 新增：转发弹窗是否打开（用于阻止键盘弹出时自动滚动到底部）
  isForwardDialogOpen: boolean = false;
  listScroller: Scroller = new Scroller();
  toScroll: boolean = false
  selectVideoView: CustomDialogController = new CustomDialogController({
    builder: NECameraSelectView({
      onTakePhotoFromCamera: () => {
        const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
        MediaUtils.showCameraPicker(context, cameraPicker.PickerMediaType.PHOTO).then((result) => {
          if (result.uri) {
            if (result.type === photoAccessHelper.PhotoType.IMAGE) {
              this.chatViewModel.sendImageMessage(result.uri)
            } else if (result.type === photoAccessHelper.PhotoType.VIDEO) {
              this.chatViewModel.sendVideoMessage(result.uri, result.duration, result.width, result.height)
            }
            // 发送图片/视频后滚动到最新消息
            this.scrollToNewMessage()
          }
        });
      },
      onTakeVideoFromCamera: () => {
        const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
        MediaUtils.showCameraPicker(context, cameraPicker.PickerMediaType.VIDEO).then(async (result) => {
          if (result.uri) {
            if (result.type === photoAccessHelper.PhotoType.IMAGE) {
              this.chatViewModel.sendImageMessage(result.uri)
            } else if (result.type === photoAccessHelper.PhotoType.VIDEO) {
              this.chatViewModel.sendVideoMessage(result.uri, result.duration, result.width, result.height)
            }
            // 发送图片/视频后滚动到最新消息
            this.scrollToNewMessage()
          }
        });
      }
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    height: 140,
  })
  @Local imagesIndexModel?: ImagesIndexModel
  @Local currentImageIndex: number = 0
  imageViewerDialog: CustomDialogController = new CustomDialogController({
    builder: ImageViewDialog({
      imagesIndexModel: this.imagesIndexModel,
      onDialogClose: () => {
        this.chatViewModel.isPageVisible = true
      }
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Center,
    backgroundColor: Color.Black,
    backgroundBlurStyle: BlurStyle.NONE,
    height: '100%',
    width: '100%',
    customStyle: true,
    onWillDismiss: () => {
      this.chatViewModel.isPageVisible = true
    }
  })
  @Local videoFileUrl?: string
  @Local videoRatio?: number
  videoViewerDialog: CustomDialogController = new CustomDialogController({
    builder: VideoViewerDialog({
      videoUrl: this.videoFileUrl,
      videoRatio: this.videoRatio,
      onDialogClose: () => {
        this.chatViewModel.isPageVisible = true
      }
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Center,
    backgroundColor: Color.Black,
    backgroundBlurStyle: BlurStyle.NONE,
    height: '100%',
    width: '100%',
    customStyle: true,
    onWillDismiss: () => {
      this.chatViewModel.isPageVisible = true
    }
  })
  forwardMessages: V2NIMMessage[] = []
  forwardConversations: ConversationSelectModel[] = []
  currentConversationName?: string
  forwardType?: ResourceStr = $r('app.string.chat_operation_forward')
  forwardMessageDialog = new CustomDialogController({
    builder: ForwardMessageDialog({
      conversationList: this.forwardConversations,
      currentConversationName: this.currentConversationName,
      forwardType: this.forwardType,
      sendForwardMsg: (text: string | undefined) => {
        if (ErrorUtils.checkNetworkAndToast()) {
          this.chatViewModel.forwardMessage(this.forwardMessages, this.forwardConversations, text)
          this.showMultiSelect = false
          // 只有当转发目标包含当前会话时，才滚动到最新消息
          const forwardToCurrentConversation: boolean = this.forwardConversations.some(
            (conv) => conv.conversationId === this.conversationId
          )
          if (forwardToCurrentConversation) {
            this.scrollToNewMessage()
          }
        }
      },
      onDialogClose: () => {
        this.isForwardDialogOpen = false
        this.chatViewModel.isPageVisible = true
      }
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 250,
    width: 276,
    onWillDismiss: () => {
      this.isForwardDialogOpen = false
      // 弹窗关闭后恢复页面可见状态（系统返回键/手势关闭时触发）
      this.chatViewModel.isPageVisible = true
    }
  })
  invalidForwardDialogSureAction?: () => void
  invalidForwardFailureDialog?: CustomDialogController = new CustomDialogController({
    builder: DoubleAlertDialog({
      title: $r('app.string.exception_description'),
      message: $r("app.string.multiForward_exist_invalid_fail"),
      sureAction: this.invalidForwardDialogSureAction
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 140,
    width: 270,
  })
  invalidForwardDepthDialog?: CustomDialogController = new CustomDialogController({
    builder: DoubleAlertDialog({
      title: $r('app.string.exception_description'),
      message: $r('app.string.multiForward_exist_invalid_depth'),
      sureAction: this.invalidForwardDialogSureAction
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 140,
    width: 270,
  })
  aitManager: AitManager = new AitManager()
  forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
    if (this.operationMsg?.message) {
      this.forwardMessages = [this.operationMsg.message]
      this.forwardConversations = selectedList
      this.currentConversationName = this.chatTeamInfo.team?.name
      this.isForwardDialogOpen = true
      this.forwardMessageDialog.open()
    }
  }

  @Monitor("chatTeamInfo.isReceiveMsg")
  onReceiveMsg() {
    if (this.firstLoadData || this.chatTeamInfo.isReceiveMsg.yes) {
      // 检查是否在底部（需要考虑新增消息导致的 totalCount 变化）
      // 新增消息数量
      const newMsgCount = this.chatTeamInfo.isReceiveMsg.messages?.length ?? 0
      // 用收到消息前的 totalCount 来判断是否在底部
      const totalCountBeforeReceive = this.chatTeamInfo.msgList.totalCount() - newMsgCount
      const wasAtBottomBeforeReceive = this.listScrollEndPosition >= totalCountBeforeReceive - 1

      // is call message
      const isCallMessage: boolean = this.chatTeamInfo.isReceiveMsg.messages
        && this.chatTeamInfo.isReceiveMsg.messages.length > 0
        && this.chatTeamInfo.isReceiveMsg.messages[0].messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL

      if (this.firstLoadData) {
        // 首次加载直接滚动到底部
        this.isScrollingToBottom = true
        this.listScroller.scrollEdge(Edge.Bottom)
        this.clearNewMessageCount()
        this.showScrollToNewMessageButton = false
      } else if ((wasAtBottomBeforeReceive || this.isScrollingToBottom) &&
        (this.chatViewModel.isPageVisible || isCallMessage) &&
        !this.chatViewModel.hasNew) {
        // 如果在底部（或正在滚动到底部）且页面可见，且不是定位到历史消息状态，直接滚动到底部
        // 特例：如果是音视频产生的 Call 消息，也滚到最底部
        // 注意：hasNew 为 true 时表示当前显示的是历史消息（锚点消息定位），此时不应该自动滚动
        this.isScrollingToBottom = true
        this.listScroller.scrollEdge(Edge.Bottom)
        this.clearNewMessageCount()
        this.showScrollToNewMessageButton = false
      } else {
        // 如果不在底部或页面不可见，显示新消息按钮并增加计数
        if (this.chatTeamInfo.isReceiveMsg.operation === IsReceiveMsgOperation.DELETE) {
          // 删除操作需要减少计数
          this.subNewMessageCount()
        } else {
          // 新消息操作需要增加计数
          this.addNewMessageCount()
        }
        this.showScrollToNewMessageButton = true
      }

      this.chatTeamInfo.setReceiveMsg(false)
      this.firstLoadData = false;
    }
  }
  @Monitor("chatViewModel.needScrollToBottom")
  onNeedScrollToBottom() {
    if (this.chatViewModel.needScrollToBottom &&
      this.listScrollEndPosition >= this.chatTeamInfo.msgList.totalCount() - 1) {
      this.listScroller.scrollEdge(Edge.Bottom)
      this.chatViewModel.needScrollToBottom = false;
    }
  }

  @Monitor("chatTeamInfo.team")
  onGetTeamInfo() {
    let team = this.chatTeamInfo.team
    if (team && !team.isValidTeam) {
      TeamExitWarningDialog.show(this.getUIContext(), new TeamExitDialogParam(
        () => {
          ConversationRepo.deleteConversation(this.conversationId, true)
          TeamExitWarningDialog.close(this.getUIContext())
          // 关闭 @列表弹窗（如果打开的话）
          this.getUIContext().getHostContext()?.eventHub.emit('aitDialogClose')
          this.pathStack.clear()
        }
      ))
    }
  }

  @Monitor("chatTeamInfo.scrollIndex")
  onScrollIndex() {
    if (this.chatTeamInfo.scrollIndex > -1) {
      this.toScroll = true
      // 使用 ScrollAlign.CENTER 让消息居中显示
      this.listScroller.scrollToIndex(this.chatTeamInfo.scrollIndex, false, ScrollAlign.CENTER)
      this.chatViewModel.setAnchorMessage(undefined)
      this.chatTeamInfo.setScrollIndex(-1)
    }
  }

  @Monitor("chatViewModel.anchorMsg")
  onAnchorMsg() {
    if (this.chatViewModel.anchorMsg) {
        this.chatViewModel.loadAnchorMsg(this.chatViewModel.anchorMsg)
    }
  }

  @Monitor("chatViewModel.isMuteModel")
  onMuteModel() {
    if (this.chatViewModel.isMuteModel) {
      this.clearInput(true)
    }
  }

  @Monitor("chatViewModel.selectMsgCount")
  onSelectMsg() {
    this.multiSelectCount = this.chatViewModel.getSelectMessageSize()
  }

  @Monitor("expandHeight")
  onExpandInputView() {
    if (this.expandHeight > 10) {
      // 如果转发弹窗打开，跳过滚动到底部
      if (this.isForwardDialogOpen) {
        return
      }
      // 如果页面不可见，跳过滚动操作（避免在其他页面输入时影响聊天页）
      if (!this.chatViewModel.isPageVisible) {
        return
      }
      // 如果是定位消息状态，收到键盘展开重新切换最新消息
      if (this.chatViewModel.hasNew) {
        this.chatViewModel.reloadMessageList()
      } else {
        this.listScroller.scrollEdge(Edge.Bottom)
      }
    }
  }


  /**
   * 检查是否在底部
   */
  checkIfAtBottom() {
    const totalCount = this.chatTeamInfo.msgList.totalCount()
    const wasAtBottom = this.isAtBottom
    this.isAtBottom = this.listScrollEndPosition >= totalCount - 1

    // 特殊处理：当消息列表不满屏时（所有消息都可见），不应该显示新消息提示
    // 判断依据：如果 listScrollStartPosition 为 0 且 listScrollEndPosition >= totalCount - 1，
    // 说明所有消息都在可见范围内，不需要滚动
    const isListFullyVisible = this.listScrollStartPosition === 0 && this.listScrollEndPosition >= totalCount - 1

    if (isListFullyVisible && this.newMessageCount > 0) {
      // 所有消息都可见，清除新消息提示
      this.clearNewMessageCount()
      this.showScrollToNewMessageButton = false
    } else if (!wasAtBottom && this.isAtBottom) {
      // 重置新消息计数和按钮状态，相当于手动触发 scrollToNewMessage 的重置逻辑
      this.clearNewMessageCount()
      this.showScrollToNewMessageButton = false
    } else if (wasAtBottom && this.isAtBottom && this.newMessageCount > 0) {
      // 如果有一直在底下的动作，并且还没有处理掉 newMessageCount，需要兜底处理
      this.clearNewMessageCount()
      this.showScrollToNewMessageButton = false
    } else if (this.isAtBottom && this.newMessageCount === 1) {
      // 特殊处理：当只有 1 条新消息且已经在底部时，也需要清理
      // 场景：用户离开前在底部，回来后收到 1 条新消息，此时下沿正好指向新消息
      this.clearNewMessageCount()
      this.showScrollToNewMessageButton = false
    } else if (!this.isAtBottom && this.newMessageCount === 0) {
      // 额外逻辑：如果不在底部且没有新消息计数，则显示"回到底部"按钮
      this.showScrollToNewMessageButton = true
    } else if (this.isAtBottom && this.newMessageCount === 0) {
      // 如果在底部且没有新消息，隐藏按钮
      this.showScrollToNewMessageButton = false
    }
  }

  /**
   * 滚动到新消息
   */
  scrollToNewMessage() {
    // 如果 hasNew 为 true，说明当前显示的不是完整消息历史，需要刷新数据
    if (this.chatViewModel.hasNew) {
      // 重新加载消息列表，相当于重新进入页面
      this.chatViewModel.reloadMessageList()
    } else {
      // 正常情况下直接滚动到底部
      this.listScroller.scrollEdge(Edge.Bottom)
    }
    // 滚动到底部时，对所有消息发送已读回执（因为会滚动到最新，所以传全部消息列表）
    if (this.newMessageCount > 0) {
      const allMessages = this.chatTeamInfo?.msgList.getMessageList() ?? []
      this.chatViewModel.getAndSendMessageReceipts(allMessages)
    }
    // 重置状态
    this.clearNewMessageCount()
    this.showScrollToNewMessageButton = false
    this.isAtBottom = true
  }


  aboutToAppear(): void {
    NEEmojiManager.instance.setup()
    DeviceUtils.rootDirPath = getContext(this).filesDir
    this.operationMoreDataList = setupMoreOperationData(false)
    window.getLastWindow(getContext(this)).then(currentWindow => {
      let property = currentWindow.getWindowProperties();
      // 初始化窗口高度
      let avoidArea = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
      this.screenHeight = px2vp(property.windowRect.height);
      this.screenWidth = px2vp(property.windowRect.width);
      DeviceUtils.windowPXWidth = property.windowRect.width;
      DeviceUtils.windowPXHeight = property.windowRect.height;
      this.scrollHeight =
        px2vp(property.windowRect.height - avoidArea.bottomRect.height) - this.bottomHeight;
      this.defaultInputViewHeight = this.scrollHeight;
      // 监听软键盘的隐藏和显示
      currentWindow.on('avoidAreaChange', data => {
        if (data.type == window.AvoidAreaType.TYPE_KEYBOARD) {
          this.showOperationView = false
          this.keyboardHeight = px2vp(data.area.bottomRect.height);
          // 如果是定位消息状态，收到键盘展开重新切换最新消息
          if (this.keyboardHeight > 10 && this.chatViewModel.hasNew) {
            this.chatViewModel.reloadMessageList()
          }
          this.computeScrollHeight()
          return;
        }
      })
    })
  }

  computeScrollHeight() {
    if ((this.inputStyle === InputStyleType.Emoji || this.inputStyle === InputStyleType.Record ||
      this.inputStyle === InputStyleType.More) && this.keyboardHeight <= 0) {
      this.scrollHeight = this.screenHeight - this.keyboardHeight - this.bottomHeight - this.expandHeight
    } else {
      this.scrollHeight = this.screenHeight - this.keyboardHeight - this.bottomHeight
      if (this.keyboardHeight > 10) {
        this.expandHeight = 0
        this.inputStyle = InputStyleType.None;
        setTimeout(() => {
          // 如果转发弹窗打开或页面不可见，跳过滚动到底部
          if (!this.isForwardDialogOpen && this.chatViewModel.isPageVisible) {
            // 延迟执行滚动，确保列表高度更新完成后再滚动到底部
            this.listScroller.scrollEdge(Edge.Bottom)
          }
        }, 20)
      }
    }
  }

  /**
   * 是否是@的span
   * @param span
   * @returns
   */
  isAitEditorSpan(span: RichEditorImageSpanResult | RichEditorTextSpanResult): boolean {
    return !(span as RichEditorTextSpanResult).value &&
      !(span as RichEditorImageSpanResult).valueResourceStr?.toString().replaceAll(' ', '');
  }

  /**
   * 获取输入数据
   * @returns
   */
  getMessageText(): string {
    let text = '';
    let builderSpanIndex = 0;
    if (this.controller) {
      this.controller.getSpans().forEach((span) => {
        const textSpan = span as RichEditorTextSpanResult;
        const imageSpan = span as RichEditorImageSpanResult;
        if (textSpan.value) {
          text += textSpan.value;
        } else if (this.isAitEditorSpan(span) && builderSpanIndex < this.builderSpans.length) {
          let aitSpan: AitEditorSpan = this.builderSpans[builderSpanIndex]
          let contentText = aitSpan.value
          this.aitManager.addAitWithText(aitSpan.accountId, contentText, text.length)
          text += contentText
          builderSpanIndex += 1;
        } else {
          let resourcePath = imageSpan.valueResourceStr;
          if (resourcePath != null && resourcePath.toString().length > 0) {
            let path = resourcePath.toString();
            let splits = path.split("/")
            let fileName = splits[splits.length - 1];
            let emoji = NEEmojiManager.instance.getEmojiByName(String(fileName));
            if (emoji?.tag != null) {
              text += emoji.tag;
            }
          }
        }
      });
    }

    return text
  }

  getInputContentLength(): number {
    let length = 0
    this.controller.getSpans().forEach((item) => {
      if (typeof (item as RichEditorImageSpanResult)['imageStyle'] != 'undefined') {
        let span = item as RichEditorImageSpanResult;
        if (span.spanPosition.spanRange) {
          let end = span.spanPosition.spanRange[1];
          if (end > length) {
            length = end;
          }
        }
      } else {
        let span = item as RichEditorTextSpanResult
        if (span.spanPosition.spanRange) {
          let end = span.spanPosition.spanRange[1];
          if (end > length) {
            length = end;
          }
        }
      }
    })
    return length
  }

  async requestChatData() {
    this.chatTeamInfo.setConversationId(this.conversationId)
    this.chatViewModel.init(this.conversationId as string, this.chatTeamInfo);
    this.chatViewModel.loadData()
    this.chatViewModel.setTeamExitListener(() => {
      TeamExitWarningDialog.show(this.getUIContext(), new TeamExitDialogParam(
        () => {
          // 关闭 @列表弹窗（如果打开的话）
          this.getUIContext().getHostContext()?.eventHub.emit('aitDialogClose')
          this.pathStack.clear()
          TeamExitWarningDialog.close(this.getUIContext())
        }
      ))
    })
  }

  async showImageDetail(msg?: NIMMessageInfo, onlyMsg?: boolean) {
    try {
      const imageModel =
        onlyMsg ? await getMessageImageUrl(msg, this.chatTeamInfo) : await getMessageImageUrls(msg, this.chatTeamInfo)
      this.imagesIndexModel = imageModel
      this.chatViewModel.isPageVisible = false
      this.imageViewerDialog.open()
    } catch (err) {
      console.error(err)
    }
  }

  showVideoDetail(msg: NIMMessageInfo) {
    AudioPlayerManager.instance.stopPlayAll()
    this.videoFileUrl = getMessageVideoUrl(msg, this.chatTeamInfo)
    if (this.videoFileUrl == undefined) {
      NECommonUtils.showToast($r('app.string.chat_msg_download_tips'))
      return
    }
    this.videoRatio = getMessageVideoRatio(msg)
    if (this.videoFileUrl) {
      this.chatViewModel.isPageVisible = false
      this.videoViewerDialog.open()
    }
  }

  @Builder
  AtSpan(nickname: string) {
    Text(nickname)
      .fontColor('#FF337EFF');
  }

  /**
   * 通过ID来添加@成员
   * @param senderId
   */
  async addAitUserById(senderId: string) {
    //输入框添加@信息
    let sendMember = await TeamMemberCache.getInstance().getMemberById(senderId)
    if (sendMember && this.controller) {
      const controller = this.controller;
      let aitValue = '@' + sendMember.getAitName() + ' '
      const offset = controller.getCaretOffset()
      controller.addBuilderSpan(() => this.AtSpan(aitValue), {
        offset: offset
      });
      let aitSpan: AitEditorSpan = {
        spanIndex: offset,
        accountId: senderId,
        value: aitValue,
      }
      this.builderSpans.push(...[aitSpan])
    }
  }

  showLocationDetail(msg: NIMMessageInfo) {
    let attachment = msg.message.attachment as V2NIMMessageLocationAttachment

    let queryLocationOptions: sceneMap.LocationQueryOptions = {
      location: {
        latitude: attachment.latitude,
        longitude: attachment.longitude
      },
      name: attachment.address,
      address: attachment.address,
    };
    // 拉起地点详情页
    sceneMap.queryLocation(getContext(this) as common.UIAbilityContext, queryLocationOptions).then(() => {
      console.info("netease QueryLocation", "Succeeded in querying location.");
    }).catch((err: BusinessError) => {
      console.error("netease QueryLocation", `Failed to query Location, code: ${err.code}, message: ${err.message}`);
    });
  }

  @Builder
  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: this.chatTeamInfo.conversationName,
        leftButtonAction: () => {
          this.pathStack.pop()
        },
        rightButtonIcon: this.showMultiSelect ? undefined : $r('app.media.ic_public_more_dot'),
        rightButtonTitle: this.showMultiSelect ? $r('app.string.chat_msg_dialog_cancel') : undefined,

        rightButtonAction: () => {
          this.goToTeamSettingPage(this.pathStack)
        }
      })
      RelativeContainer() {
        // 防诈条和断网条 - 放在顶部
        Column() {
          // 防诈条
          FraudTipView({
            pathStack: this.pathStack,
            canReport: true,
            canCancel: true
          })

          // 断网条 - 仅在断网时显示
          if (this.chatViewModel.networkBroken) {
            NetworkBrokenBuilder()
          }
        }
        .width('100%')
        .id("tipBannerArea")
        .alignRules({
          top: { anchor: "__container__", align: VerticalAlign.Top },
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End }
        })
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.tipBannerHeight = Number(newValue.height) || 0
        })

          List({ scroller: this.listScroller }) {
            LazyForEach(this.chatTeamInfo.msgList, (msg: NIMMessageInfo) => {
              ListItem() {
                MessageComponent({
                  message: msg,
                  chatInfo: this.chatTeamInfo,
                  showSelect: this.showMultiSelect,
                  onMessageClick: {
                    onAvatarClick: (msg: NIMMessageInfo | undefined) => {
                      if (this.showMultiSelect) {
                        return
                      }
                      if (msg != null) {
                        if (msg?.message.senderId == ChatKitClient.getLoginUserId()) {
                          this.pathStack.pushPath({
                            name: 'MineInfoPage'
                          })
                        } else {
                          this.pathStack.pushPath({ name: 'PersonInfoPage', param: msg?.message.senderId })
                        }
                      }
                    },
                    onAvatarLongPress: (msg: NIMMessageInfo | undefined) => {
                      if (this.showMultiSelect) {
                        return
                      }
                      if (msg != null) {
                        if (msg?.message.senderId && msg?.message.senderId !== ChatKitClient.getLoginUserId()) {
                          this.addAitUserById(msg.message.senderId)
                        }
                      }
                    },
                    onItemLongClick: (event: GestureEvent, msg: NIMMessageInfo | undefined) => {
                      if (this.showMultiSelect) {
                        return
                      }
                      this.operationMsg = msg
                      let opMenuWidth = computeOperateViewWidth(msg)
                      let opMenuHeight = computeOperateViewHeight(msg)
                      let marginSize = this.operationViewMargin
                      if (event.target.area.position.x !== undefined) {
                        let xPoint = Number(event.target.area.globalPosition.x) +
                          (Number(event.target.area.width) - opMenuWidth) / 2
                        if (xPoint < marginSize) {
                          xPoint = marginSize
                        }
                        if (xPoint + opMenuWidth + marginSize > this.screenWidth) {
                          xPoint = this.screenWidth - opMenuWidth - marginSize
                        }
                        this.operationRect.x = xPoint;
                      }
                      if (event.target.area.position.y !== undefined) {
                        let yPoint =
                          Number(event.target.area.globalPosition.y) - this.navBarHeight +
                          Number(event.target.area.height)
                        if (yPoint + opMenuHeight + marginSize + this.bottomHeight > this.scrollHeight) {
                          yPoint =
                            yPoint - opMenuHeight - marginSize * 2 - Number(event.target.area.height);
                        }
                        if (yPoint < 0) {
                          yPoint = this.scrollHeight / 2;

                        }
                        this.operationRect.y = yPoint
                      }
                      this.showOperationView = true
                    },
                    onItemClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (this.showMultiSelect) {
                        if (msg && !msg.isRevokeMsg) {
                          if (!msg?.isSelectedMsg) {
                            this.chatViewModel.addSelectMessage(msg)
                          } else {
                            this.chatViewModel.removeSelectMessage(msg)
                          }
                        }
                        return
                      }
                      this.showMessageDetail(msg)
                    },
                    onRevokeEditClick: (_event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (msg?.checkRevokeEdit()) {
                        const controller = this.controller
                        if (msg.isReplyMsg && msg.replyMsg) {
                          this.controller.deleteSpans()
                          this.loadReplyInfo(msg.replyMsg, false)
                        } else {
                          this.clearInput(true)
                        }
                        this.builderSpans.splice(0, this.builderSpans.length)
                        parseMessageText(msg.revokeInfo?.revokeMsgText)?.forEach((item: NEEmojiParseResult) => {
                          let spanIndex = 0
                          if (item.text) {
                            getAitNodes(item.startIndex, item.text, msg.message.serverExtension)
                              .forEach((node: ChatAitNode) => {
                                if (node.segment) {
                                  controller.addBuilderSpan(() => this.AtSpan(node.text));
                                  let aitSpan: AitEditorSpan = {
                                    spanIndex: spanIndex,
                                    accountId: node.account ?? '',
                                    value: node.text,
                                  }
                                  this.builderSpans.push(...[aitSpan])
                                  spanIndex++
                                } else {
                                  controller.addTextSpan(node.text)
                                  spanIndex = spanIndex + node.text.length
                                }
                              })
                          } else if (item.emoji) {
                            controller.addImageSpan($rawfile(`emoji/${item.emoji.file}`),
                              {
                                imageStyle: { size: [16, 16] }
                              })
                            spanIndex++
                          }
                        })

                      } else if (msg?.revokeInfo !== undefined) {
                        NECommonUtils.showToast($r('app.string.chat_revoke_edit_error_tips'))
                      }
                    },
                    onReadReceiptClick: (_event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (ErrorUtils.checkNetworkAndToast()) {
                        this.pathStack.pushPath({ name: 'ChatReadReceiptPage', param: msg?.message })
                      }
                    },
                    onMultiSelect: (select: boolean, msg: NIMMessageInfo | undefined) => {
                      if (msg) {
                        if (select) {
                          this.chatViewModel.addSelectMessage(msg)
                        } else {
                          this.chatViewModel.removeSelectMessage(msg)
                        }
                        this.operationMsg = undefined
                      }
                    },
                    onReplyClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (msg) {
                        if (this.chatTeamInfo.msgMap.has(msg.getMessageClientId())) {
                          let index = this.chatTeamInfo.searchPosition(msg.getMessageClientId())
                          this.listScroller.scrollToIndex(index)
                        } else {
                          this.showMessageDetail(msg, true)
                        }
                      }
                    },
                    onSendFailClick: (_event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (this.showMultiSelect) {
                        return
                      }
                      if (msg) {
                        this.chatViewModel.resendMessage(msg)
                      }
                    },
                  }
                })
              }
            }, (item: NIMMessageInfo, index: number) => {
              try {
                return item.message.messageClientId
              } catch (e) {
                return index.toString()
              }
            })
          }
          .id("chatPageListView")
          .cachedCount(4)
          .padding({ bottom: 5 })
          .maintainVisibleContentPosition(true)
          .onScrollIndex((start: number, end: number) => {
            if (!this.toScroll) {
              if (start >= 0 && start < 3
                && this.listScrollStartPosition > start && this.chatViewModel.canLoadMore()) {
                this.chatViewModel.getMoreMessageList()
              } else if (this.listScrollEndPosition < end && this.chatViewModel.canLoadNext(end)) {
                this.chatViewModel.getNewMessageList()
              }
            }
            this.listScrollEndPosition = end;
            this.listScrollStartPosition = start;
            // 如果有新消息，发送已读回执
            if (this.newMessageCount > 0) {
              // 滑到底部时，对可见范围内的消息发送已读回执
              const allMessages = this.chatTeamInfo.msgList.getMessageList()
              const visibleMessages = allMessages.slice(this.listScrollStartPosition, this.listScrollEndPosition + 1)
              this.chatViewModel.getAndSendMessageReceipts(visibleMessages)
            }
            // 检查是否在底部，更新状态
            this.checkIfAtBottom()
          })
          .onScrollStop(() => {
            console.debug('netease to scroll stop:', this.toScroll)
            if (this.toScroll) {
              this.toScroll = false
            }
            // 滚动结束后，重置"正在滚动到底部"标记
            this.isScrollingToBottom = false
          })
          .alignRules({
            left: { anchor: "__container__", align: HorizontalAlign.Start },
            right: { anchor: "__container__", align: HorizontalAlign.End },
            top: { anchor: "tipBannerArea", align: VerticalAlign.Bottom },
          })
          .height(this.scrollHeight - this.bottomMargin - this.tipBannerHeight)
          .onScrollStart(() => {
            this.showOperationView = false
          })
          .onTouch((event) => {
            if (event.type == TouchType.Down) {
              this.showOperationView = false
              this.getUIContext().getFocusController().clearFocus();
              this.scrollHeight = this.defaultInputViewHeight;
              this.expandHeight = 0;
              this.inputStyle = InputStyleType.None
            }
          })

          Column()
            .height(this.bottomHeight)
            .backgroundColor(Color.Transparent)
            .backgroundColor($r('app.color.chat_input_background'))
            .id("chat_input")
            .alignRules({
              left: { anchor: "__container__", align: HorizontalAlign.Start },
              right: { anchor: "__container__", align: HorizontalAlign.End },
              top: { anchor: "chatPageListView", align: VerticalAlign.Bottom },
            })

          if (this.hideInput === false && !this.showMultiSelect) {
            NEChatInputView({
              aitManager: this.aitManager,
              controller: this.controller,
              builderSpans: this.builderSpans,
              placeHolder: (this.chatTeamInfo.conversationName ?? '').length > 15 ?
                this.chatTeamInfo.conversationName?.substring(0, 15) + '...' : this.chatTeamInfo.conversationName,
              replyMsg: this.replyMsg,
              chatInfo: this.chatTeamInfo,
              onDidClickCloseReply: () => {
                this.clearInput(false)
              },
              onDidClickImage: () => {
                this.showOperationView = false
                MediaUtils.showImageVideoPicker().then((result) => {
                  if (result.errorMsg == null && result.uri) {
                    if (result.type === photoAccessHelper.PhotoType.IMAGE) {
                      this.chatViewModel.sendImageMessage(result.uri);
                    } else if (result.type === photoAccessHelper.PhotoType.VIDEO) {
                      this.chatViewModel.sendVideoMessage(result.uri, result.duration, result.width, result.height);
                    }
                    // 发送图片/视频后滚动到最新消息
                    this.scrollToNewMessage()
                  }
                })
              },
              onDidClickAudio: () => {
                let context = getContext(this) as common.UIAbilityContext
                this.showOperationView = false
                this.getUIContext().getFocusController().clearFocus()
                PermissionsUtils.reqPermissionsFromUser(['ohos.permission.MICROPHONE'], context).then((result) => {
                  if (result.grantStatus == true) {
                    if (this.inputStyle == InputStyleType.Record) {
                      this.expandHeight = 0
                      this.inputStyle = InputStyleType.None;
                      this.scrollHeight = this.screenHeight - this.expandHeight - this.bottomHeight
                    } else {
                      this.inputStyle = InputStyleType.Record
                      this.expandHeight = ChatConst.messageInputAreaHeight
                      this.scrollHeight = this.screenHeight - this.expandHeight - this.bottomHeight
                    }

                  } else {
                    NECommonUtils.showToast($r('app.string.chat_permission_deny_tips'))
                  }
                })

              },
              onDidClickEmoji: () => {
                this.showOperationView = false
                if (this.inputStyle == InputStyleType.Emoji) {
                  this.expandHeight = 0
                  this.inputStyle = InputStyleType.None;
                  this.scrollHeight = this.screenHeight - this.expandHeight - this.bottomHeight
                } else {
                  this.inputStyle = InputStyleType.Emoji
                  this.expandHeight = ChatConst.messageInputAreaHeight
                  this.scrollHeight = this.screenHeight - this.expandHeight - this.bottomHeight
                }
              },
              onDidClickMore: () => {
                this.showOperationView = false
                if (this.inputStyle == InputStyleType.More) {
                  this.expandHeight = 0
                  this.inputStyle = InputStyleType.None;
                  this.scrollHeight = this.screenHeight - this.expandHeight - this.bottomHeight
                } else {
                  this.inputStyle = InputStyleType.More
                  this.expandHeight = ChatConst.messageInputAreaHeight
                  this.scrollHeight = this.screenHeight - this.expandHeight - this.bottomHeight
                }
              },
              onSendTextMessage: () => {
                const text = this.getMessageText()
                let textSend = text.trimEnd()
                this.showOperationView = false
                if (textSend.length <= 0) {
                  NECommonUtils.showToast($r('app.string.null_message_not_support'))
                  return
                }
                if (text.length - textSend.length <= 1) {
                  textSend = text
                }
                this.chatViewModel.sendTextMessage(textSend, this.replyMsg, this.aitManager.aitModel,
                  this.aitManager.getPushList())
                this.clearInput(true)
                this.aitManager.cleanAit()
                this.builderSpans.splice(0, this.builderSpans.length)
              },
              inputStyle: this.inputStyle,
              mute: this.chatViewModel.isMuteModel,
              teamId: this.chatTeamInfo.team?.teamId,
              team: this.chatTeamInfo.team
            }).alignRules({
              left: { anchor: "chat_input", align: HorizontalAlign.Start },
              right: { anchor: "chat_input", align: HorizontalAlign.End },
              bottom: { anchor: "chat_input", align: VerticalAlign.Bottom },
              top: { anchor: "chat_input", align: VerticalAlign.Top },
            }).backgroundColor(this.chatViewModel.isMuteModel ? '#ffE9EFF5' : $r('app.color.chat_input_background'))
          } else if (this.showMultiSelect) {
            ChatMultiSelectView({
              isEnable: this.multiSelectCount > 0,
              onMultiForward: () => {
                if (ChatKitClient.connectBroken()) {
                  NECommonUtils.showToast($r('app.string.chat_network_error_tips'))
                } else {
                  this.multiForwardMessage()
                }
              },
              onSingleForward: () => {
                if (ChatKitClient.connectBroken()) {
                  NECommonUtils.showToast($r('app.string.chat_network_error_tips'))
                } else {
                  this.singleForwardMessage()
                }
              },
              onMultiDelete: () => {
                let selectMsg = this.chatViewModel.getSelectMessageList()
                if (selectMsg.length > ChatConst.messageDeleteLimit) {
                  NECommonUtils.showToast($r('app.string.chat_multi_delete_limit_tips', ChatConst.messageDeleteLimit))
                } else {
                  this.showDialogToDelete(selectMsg)
                }
              },
            }).width('100%').height(this.bottomHeight)
              .alignRules({
                left: { anchor: "chat_input", align: HorizontalAlign.Start },
                right: { anchor: "chat_input", align: HorizontalAlign.End },
                bottom: { anchor: "chat_input", align: VerticalAlign.Bottom },
                top: { anchor: "chat_input", align: VerticalAlign.Top },
              }).backgroundColor($r('app.color.chat_input_background'))
          }

          Column() {
            if (this.inputStyle === InputStyleType.Record) {
              NEAudioRecordView({
                onRecordAudio: (filepath, duration) => {
                  console.log("net ease record audio " + filepath);
                  this.chatViewModel.sendAudioMessage(filepath, duration)

                },
                onRecordStart: () => {
                  this.hideInput = true
                },
                onRecordEnd: () => {
                  this.hideInput = false
                }
              })
                .width('100%')
                .height(150)
                .alignRules({
                  left: { anchor: "__container__", align: HorizontalAlign.Start },
                  right: { anchor: "__container__", align: HorizontalAlign.End },
                  top: { anchor: "__container__", align: VerticalAlign.Top },
                })
            } else if (this.inputStyle === InputStyleType.More) {
              NEChatMoreOperation({
                dataList: this.operationMoreDataList, onDidClick: (data) => {
                  let context = getContext(this) as common.UIAbilityContext;
                  if (data.type == NEChatMoreOperationType.Video) {
                    PermissionsUtils.reqPermissionsFromUser(['ohos.permission.CAMERA'], context).then((result) => {
                      if (result.grantStatus == true) {
                        this.selectVideoView.open()
                      } else {
                        NECommonUtils.showToast($r('app.string.chat_permission_deny_tips'))
                      }
                    })
                  } else if (data.type == NEChatMoreOperationType.File) {
                    console.log("net ease click file")
                    MediaUtils.showFilePicker().then((result) => {
                      if (result.errorMsg == null && result.uri) {
                        this.chatViewModel.sendFileMessage(result.uri);
                      }
                    })
                  } else if (data.type == NEChatMoreOperationType.Location) {
                    PermissionsUtils.reqPermissionsFromUser(['ohos.permission.LOCATION',
                      'ohos.permission.APPROXIMATELY_LOCATION'], context).then((result) => {
                      if (result.grantStatus == true) {
                        let locationChoosingOptions: sceneMap.LocationChoosingOptions = {
                          // 展示搜索控件
                          searchEnabled: true,
                          // 展示附近Poi
                          showNearbyPoi: true
                        };
                        // 拉起地点选取页
                        sceneMap.chooseLocation(getContext(this) as common.UIAbilityContext, locationChoosingOptions)
                          .then((data) => {
                            this.chatViewModel.sendLocationMessage(data)
                            console.info("ChooseLocation", "Succeeded in choosing location.");
                          })
                          .catch((err: BusinessError) => {
                            console.error("ChooseLocation",
                              `Failed to choose location, code: ${err.code}, message: ${err.message}`);
                            // NECommonUtils.showToast(`code: ${err.code}, message: ${err.message}`)
                          });
                      } else {
                        NECommonUtils.showToast($r('app.string.chat_permission_deny_tips'))
                      }
                    })
                  }

                }
              }).padding({ top: 10 })
                .width('100%')
                .height(150)
                .alignRules({
                  left: { anchor: "__container__", align: HorizontalAlign.Start },
                  right: { anchor: "__container__", align: HorizontalAlign.End },
                  top: { anchor: "__container__", align: VerticalAlign.Top },
                })
            } else if (this.inputStyle === InputStyleType.Emoji) {
              NEChatEmojiView({
                onDidClick: (emoji) => {
                  console.log("net ease click emoji", emoji);
                  if (emoji.type === NIMEmoticonType.file) {
                    this.controller.addImageSpan($rawfile(`emoji/${emoji.file}`),
                      {
                        offset: this.controller.getCaretOffset(),
                        imageStyle: { size: [16, 16] }
                      })
                  } else if (emoji.type === NIMEmoticonType.delete) {
                    if (this.controller) {
                      let index = this.controller.getCaretOffset()
                      if (index > 0) {
                        this.controller.deleteSpans({
                          start: index - 1,
                          end: index
                        })
                      }
                    }
                  }
                },
                onEmojiSendMessage: () => {
                  const text = this.getMessageText()
                  let textSend = text.trimEnd()
                  if (textSend.length <= 0) {
                    NECommonUtils.showToast($r('app.string.null_message_not_support'))
                    return
                  }
                  if (text.length - textSend.length <= 1) {
                    textSend = text
                  }
                  this.chatViewModel.sendTextMessage(textSend, this.replyMsg, this.aitManager.aitModel,
                    this.aitManager.getPushList())
                  this.clearInput(true)
                  this.aitManager.cleanAit()
                  this.builderSpans.splice(0, this.builderSpans.length)
                }
              }).padding({ top: 0 })
                .width('100%')
                .height(170)
                .alignRules({
                  left: { anchor: "__container__", align: HorizontalAlign.Start },
                  right: { anchor: "__container__", align: HorizontalAlign.End },
                  top: { anchor: "__container__", align: VerticalAlign.Top }
                })
            }
          }
          .height(this.expandHeight)
          .width('100%')
          .alignRules({
            left: { anchor: "__container__", align: HorizontalAlign.Start },
            right: { anchor: "__container__", align: HorizontalAlign.End },
            top: { anchor: "chat_input", align: VerticalAlign.Bottom },
          })
          .id("input_expand_back_container")
          .backgroundColor($r('app.color.chat_input_background'))

          // 滚动到新消息按钮
          if (this.showScrollToNewMessageButton && !this.showMultiSelect) {
            Row() {
              Image($r('app.media.ic_chat_scroll_down'))
                .width(16)
                .height(16)
                .fillColor('#007AFF')
                .margin({ right: this.newMessageCount > 0 ? 8 : 0 })

              if (this.newMessageCount > 0) {
                Text($r('app.string.chat_new_message_count', this.newMessageCount))
                  .fontSize(14)
                  .fontColor('#007AFF')
              }
            }
            // .height(36)
            .backgroundColor(Color.White)
            .borderRadius(this.newMessageCount > 0 ?
              {
                topLeft: 20,
                bottomLeft: 20,
                topRight: 0,
                bottomRight: 0
              } : 20)
            .padding(12)
            .alignRules({
              right: { anchor: "__container__", align: HorizontalAlign.End },
              bottom: { anchor: "chat_input", align: VerticalAlign.Top }
            })
            .margin({ right: this.newMessageCount > 0 ? 0 : 16, bottom: 18 })
            .onClick(() => {
              this.scrollToNewMessage()
            })
            .shadow({
              radius: 20,
              color: '#20000000',
              offsetX: 0,
              offsetY: 4
            })
          }

          if (this.showOperationView) {
            MessageOperationView({
              operateMsg: this.operationMsg,
              didClickItem: (item: MessageOperationItem) => {
                console.log('net ease click operation item event')
                this.showOperationView = false
                if (this.operationMsg == undefined) {
                  return;
                }

                if (item.operationType == MessageOperationType.Copy) {
                  const pasteboardData =
                    pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.operationMsg.message.text)
                  pasteboard.getSystemPasteboard().setDataSync(pasteboardData)
                  NECommonUtils.showToast($r('app.string.chat_message_copy_success_tips'))
                } else if (item.operationType == MessageOperationType.Delete) {
                  this.showDialogToDelete([this.operationMsg])
                } else if (item.operationType == MessageOperationType.Undo) {
                  this.showDialogToRevoke(this.operationMsg)
                } else if (item.operationType == MessageOperationType.Forward) {
                  // 转发
                  this.forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
                    if (this.operationMsg?.message) {
                      this.forwardMessages = [this.operationMsg.message]
                      this.forwardConversations = selectedList
                      this.currentConversationName = this.chatTeamInfo.team?.name
                      this.isForwardDialogOpen = true
                      this.forwardMessageDialog.open()
                    }
                  }
                  this.forwardType = $r('app.string.chat_operation_forward')
                  this.pathStack.pushPath({
                    name: 'ConversationSelectPage',
                    param: new ConversationSelectParam([], conversationSelectLimitCount, this.forwardMessageAction)
                  })
                } else if (item.operationType == MessageOperationType.Collection) {
                  // 收藏
                  this.chatViewModel.collectionMessage(this.operationMsg)
                } else if (item.operationType == MessageOperationType.Pin) {
                  this.chatViewModel.pinMessage(this.operationMsg)
                } else if (item.operationType == MessageOperationType.Unpin) {
                  this.chatViewModel.unpinMessage(this.operationMsg)
                } else if (item.operationType == MessageOperationType.Select) {
                  this.chatViewModel.clearSelectMessage()
                  this.chatViewModel.addSelectMessage(this.operationMsg)
                  this.showMultiSelect = true
                } else if (item.operationType == MessageOperationType.Reply) {
                  this.loadReplyInfo(this.operationMsg, true)
                }
              }
            })
              .position({ x: this.operationRect.x, y: this.operationRect.y })
              .borderRadius(8)
              .shadow(ShadowStyle.OUTER_DEFAULT_MD)

          }
        }
      .margin({ bottom: this.bottomMargin })
      .expandSafeArea([SafeAreaType.KEYBOARD])
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      let param = this.pathStack.getParamByName("ChatTeamPage") as string[];
      if (param.length > 0) {
        this.conversationId = param[0];
        this.requestChatData();
      } else {
        this.pathStack.removeByName("ChatTeamPage")
      }
    })
    .onShown(() => {
      // 页面显示时设置为可见
      this.chatViewModel.isPageVisible = true
      // 回到页面时，只对可见范围内的消息发送已读回执
      const allMessages = this.chatTeamInfo?.msgList.getMessageList() ?? []
      const visibleMessages = allMessages.slice(this.listScrollStartPosition, this.listScrollEndPosition + 1)
      this.chatViewModel.getAndSendMessageReceipts(visibleMessages)
    })
    .onHidden(() => {
      // 页面隐藏时设置为不可见
      this.chatViewModel.isPageVisible = false
      AudioPlayerManager.instance.stopPlayAll()
    })
  }

  clearInput(clearInput?: boolean) {
    if (clearInput) {
      this.controller.deleteSpans()
    }
    this.replyMsg = undefined
    this.bottomHeight = 105
    this.computeScrollHeight()
  }

  loadReplyInfo(msg: NIMMessageInfo, needAit: boolean) {
    this.bottomHeight = 135
    this.replyMsg = msg
    if (needAit && this.replyMsg.message.senderId !== ChatKitClient.getLoginUserId()) {
      this.addAitUserById(this.replyMsg.message.senderId)
    }
    this.getUIContext().getFocusController().requestFocus("chat_edit_input")
  }

  /**
   * 【逐条转发】将多个消息逐条转发到多个会话中，并将留言发送到多个会话中
   */
  singleForwardMessage() {
    // 校验网络
    if (ErrorUtils.checkNetworkAndToast()) {
      this.forwardType = $r('app.string.chat_operation_single_forward')
      // 校验转发条数
      if (this.chatViewModel.selectMsgMap.size > singleMessageLimitCount) {
        let resourceManager = getContext(this).resourceManager
        NECommonUtils.showToast($r("app.string.chat_forward_limit", resourceManager.getStringSync(this.forwardType.id),
          singleMessageLimitCount))
        return
      }

      // 不可合并转发的消息列表
      let invalidMessages: NIMMessageInfo[] = []
      for (const message of this.chatViewModel.selectMsgMap.values()) {
        // 发送失败的消息不可转发
        // 语音消息不可转发
        // 话单消息不可转发
        // 远端反垃圾消息不可转发
        if (message.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED
          || message.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO
          || message.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL
          || message.isServerAntiSpam
        ) {
          invalidMessages.push(message)
          continue
        }
      }

      this.forwardMessageAction = async (selectedList: ConversationSelectModel[]) => {
        let selectMessage = this.chatViewModel.getSelectMessageList().map(msg => msg.message)
        selectMessage = selectMessage.sort((m1, m2) => {
          if (m1.createTime < m2.createTime) {
            return -1
          }
          if (m1.createTime > m2.createTime) {
            return 1
          }
          return 0
        })
        this.forwardMessages = selectMessage
        this.forwardConversations = selectedList
        this.currentConversationName = this.chatTeamInfo.team?.name
        this.isForwardDialogOpen = true
        this.forwardMessageDialog.open()
      }

      // 存在不可转发的消息：提示 + 取消勾选
      if (invalidMessages.length > 0) {
        this.invalidForwardFailureDialog?.open()
        this.invalidForwardDialogSureAction = () => {
          for (const invalidMessage of invalidMessages) {
            this.chatViewModel.removeSelectMessage(invalidMessage)
            invalidMessage.isSelectedMsg = false
          }
          if (this.chatViewModel.getSelectMessageSize() > 0) {
            this.pathStack.pushPath({
              name: 'ConversationSelectPage',
              param: new ConversationSelectParam([], conversationSelectLimitCount, this.forwardMessageAction)
            })
          }
        }
      } else {
        if (this.chatViewModel.getSelectMessageSize() > 0) {
          this.pathStack.pushPath({
            name: 'ConversationSelectPage',
            param: new ConversationSelectParam([], conversationSelectLimitCount, this.forwardMessageAction)
          })
        }
      }
    }
  }

  /**
   * 【合并转发】将多个消息合并为一条自定义消息，转发到多个会话中，并将留言发送到多个会话中
   */
  multiForwardMessage() {
    // 校验网络
    if (ErrorUtils.checkNetworkAndToast()) {
      this.forwardType = $r('app.string.chat_operation_multi_forward')
      // 校验转发条数
      if (this.chatViewModel.selectMsgMap.size > mergedMessageLimitCount) {
        let resourceManager = getContext(this).resourceManager
        NECommonUtils.showToast($r("app.string.chat_forward_limit", resourceManager.getStringSync(this.forwardType.id),
          mergedMessageLimitCount))
        return
      }

      // 计算层数（深度） depth
      let depth = 0
      // 不可合并转发的消息列表(1.发送失败的消息；2.转发层数超过 mergedMessageMaxDepth 的消息)
      const invalidMessages: NIMMessageInfo[] = []
      let invalidFail: boolean = false
      let invalidDepth: boolean = false
      for (const message of this.chatViewModel.selectMsgMap.values()) {
        // 发送失败的消息不可转发
        // 远端反垃圾消息不可转发
        if (message.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED
          || message.isServerAntiSpam
        ) {
          invalidMessages.push(message)
          invalidFail = true
          continue
        }

        // 解析消息中的 depth
        if (message.message.attachment) {
          let data = CustomMessageUtils.dataOfCustomMessage(message.message.attachment)
          if (data) {
            let dep = data["depth"] as number
            if (dep >= mergedMessageMaxDepth) {
              invalidMessages.push(message)
              invalidDepth = true
            } else if (dep >= depth) {
              depth = dep
            }
          }
        }
      }

      // 当前合并转发消息深度 + 1
      depth += 1

      this.forwardMessageAction = async (selectedList: ConversationSelectModel[]) => {
        let forwardMessages =
          await this.chatViewModel.mergeForwardMessage(this.chatViewModel.getSelectMessageList(), depth)
        if (forwardMessages) {
          this.forwardMessages = [forwardMessages]
        }
        this.forwardConversations = selectedList
        this.currentConversationName = this.chatTeamInfo.team?.name
        this.isForwardDialogOpen = true
        this.forwardMessageDialog.open()
      }

      // 存在不可转发的消息：提示 + 取消勾选
      if (invalidMessages.length > 0) {
        if (invalidFail) {
          this.invalidForwardFailureDialog?.open()
        } else if (invalidDepth) {
          this.invalidForwardDepthDialog?.open()
        }
        this.invalidForwardDialogSureAction = () => {
          for (const invalidMessage of invalidMessages) {
            this.chatViewModel.removeSelectMessage(invalidMessage)
            invalidMessage.isSelectedMsg = false
          }
          if (this.chatViewModel.getSelectMessageSize() > 0) {
            this.pathStack.pushPath({
              name: 'ConversationSelectPage',
              param: new ConversationSelectParam([], conversationSelectLimitCount, this.forwardMessageAction)
            })
          }
        }
      } else {
        if (this.chatViewModel.getSelectMessageSize() > 0) {
          this.pathStack.pushPath({
            name: 'ConversationSelectPage',
            param: new ConversationSelectParam([], conversationSelectLimitCount, this.forwardMessageAction)
          })
        }
      }
    }
  }

  /**
   * 查看消息详情，点击消息体查看或者点击被回复内容查看
   * @param msg 点击的消息
   * @param onlyShow 是否为只展示该消息，如果是则文本消息会直接弹窗展示，图片消息则只查看当前消息
   */

  showMessageDetail(msg: NIMMessageInfo | undefined, onlyShow?: boolean) {
    if (msg) {
      if (onlyShow && msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
        this.textMessageDetailDialog = new CustomDialogController({
          builder: TextMessageDetailDialog({
            message: msg
          }),
          cornerRadius: 0,
          alignment: DialogAlignment.Center,
          backgroundColor: Color.White,
          height: '100%',
          width: '100%',
          customStyle: true
        })
        this.textMessageDetailDialog.open()
      }
      if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
        this.showImageDetail(msg, onlyShow)
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
        downLoadAndOpenFile(msg, getContext(this), this.chatTeamInfo)
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
        this.showVideoDetail(msg)
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
        this.showLocationDetail(msg)
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
        if (onlyShow) {
          this.playAudioMessage(msg)
        }
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
        const attachment = msg.message.attachment
        if (attachment) {
          const type = CustomMessageUtils.typeOfCustomMessage(attachment)
          if (type === mergedMessageCustomType) {
            let data = CustomMessageUtils.dataOfCustomMessage(attachment)
            if (data as MergedMessageAttachment) {
              this.pathStack.pushPath({
                name: 'MergeMessageDetailPage',
                param: data as MergedMessageAttachment
              })
            }
          }
        }
      }
    }
  }

  playAudioMessage(msg: NIMMessageInfo) {
    if (msg.message.attachment) {
      let audioManager = AudioPlayerManager.instance
      audioManager.stopPlayAll()
      audioManager.avPlayerLive((msg.message.attachment as V2NIMMessageAudioAttachment).url ?? '')
    }
  }

  showDialogToDelete(messages: NIMMessageInfo[]) {
    AlertDialog.show(
      {
        title: $r('app.string.chat_msg_delete_dialog_title'),
        message: $r('app.string.chat_msg_delete_dialog_desc'),
        autoCancel: true,
        alignment: DialogAlignment.Bottom,
        gridCount: 4,
        offset: { dx: 0, dy: -20 },
        primaryButton: {
          value: $r('app.string.chat_msg_dialog_cancel'),
          action: () => {
          }
        },
        secondaryButton: {
          enabled: true,
          defaultFocus: true,
          style: DialogButtonStyle.HIGHLIGHT,
          value: $r('app.string.chat_msg_dialog_sure'),
          action: () => {
            this.chatViewModel.deleteMessageList(messages)
            this.showMultiSelect = false
          }
        }
      }
    )
  }

  showDialogToRevoke(message: NIMMessageInfo) {
    AlertDialog.show(
      {
        title: $r('app.string.chat_msg_revoke_dialog_title'),
        message: $r('app.string.chat_msg_revoke_dialog_desc'),
        autoCancel: true,
        alignment: DialogAlignment.Bottom,
        gridCount: 4,
        offset: { dx: 0, dy: -20 },
        primaryButton: {
          value: $r('app.string.chat_msg_dialog_cancel'),
          action: () => {
            console.info('Callback when the first button is clicked')
          }
        },
        secondaryButton: {
          enabled: true,
          defaultFocus: true,
          style: DialogButtonStyle.HIGHLIGHT,
          value: $r('app.string.chat_msg_dialog_sure'),
          action: () => {
            console.info('Callback when the second button is clicked')
            this.chatViewModel.revokeMessage(message)
          }
        }
      }
    )
  }

  goToTeamSettingPage(pathStack: NavPathStack) {
    if (this.showMultiSelect) {
      this.chatViewModel.clearSelectMessage()
      this.showMultiSelect = false
    } else {
      pathStack.pushPath({
        name: 'TeamSettingPage',
        param: this.chatTeamInfo.team?.teamId
      })
    }
    this.controller.stopEditing()
  }

  onPageHide(): void {
    this.chatViewModel.clearUnreadCount()
  }

  /**
   * 计算此时的 this.chatTeamInfo.isReceiveMsg 中有多少应该被记录成 newMessageCount 增加的
   * 满足以下条件的才允许添加：
   * 1. conversationId 为当前会话
   * 2. 发送者不是自己
   * @returns
   */
  private addNewMessageCount(): void {
    for (const message of this.chatTeamInfo.isReceiveMsg.messages) {
      if (message.conversationId === this.conversationId
        && message.senderId != ChatKitClient.getLoginUserId()
      ) {
        this.newMessageMap.set(message.messageClientId, message)
        this.newMessageCount = this.newMessageMap.length
      }
    }
  }

  /**
   * 撤回情况下，需要从 newMessage 里面去掉
   */
  private subNewMessageCount(): void {
    for (const message of this.chatTeamInfo.isReceiveMsg.messages) {
      if (message.conversationId === this.conversationId
        && message.senderId != ChatKitClient.getLoginUserId()
      ) {
        this.newMessageMap.remove(message.messageClientId)
        this.newMessageCount = this.newMessageMap.length
      }
    }
  }

  /**
   * 清理 newMessageCount 和 newMessageMap
   */
  private clearNewMessageCount(): void {
    this.newMessageMap.clear()
    this.newMessageCount = 0
  }

  aboutToDisappear(): void {
    this.chatViewModel.clearUnreadCount()
    this.chatViewModel.onDestroy()
    AudioPlayerManager.instance.stopPlayAll()
    TeamMemberCache.getInstance().clear()
  }
}

// 跳转页面入口函数
@Builder
export function ChatTeamPageBuilder() {
  ChatTeamPage()
}