/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { ChatUserInfo } from '../model/ChatUserInfo';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { MessageComponent } from '../view/MessageComponent';
import { ChatP2PViewModel } from '../viewmodel/ChatP2PViewModel';
import { NEChatEmojiView } from '../view/NEChatEmojiView';
import { NEEmojiManager, NIMEmoticonType } from '../manager/NEEmojiManager';
import { NEChatMoreOperation } from '../view/ChatMoreOperationLayout';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { AIHelperView } from '../view/ai/AIHelperView';
import { AITranslateView } from '../view/ai/AITranslateView';
import { AISearchPanel } from '../aisearchkit/AISearchPanel';
import { AISearchSelectionState, getMultiLineAISearchText } from '../aisearchkit/AISearchMenuUtils';
import { AIHelperItem } from '../model/AIHelperItem';
import { AIHelperRepo } from '../repo/AIHelperRepo';
import { inputMethod } from '@kit.IMEKit';
import { NEAudioRecordView } from '../view/NEAudioRecordView';
import { AitEditorSpan, InputStyleType, NEChatInputView } from '../view/ChatInputView';
import { MultiLineInputView } from '../view/MultiLineInputView';
import { DoubleAlertDialog, ImagesIndexModel, MediaUtils, NavigationBackBuilder, NECommonUtils, NetworkBrokenBuilder, PermissionsUtils, VideoViewerDialog, CommonConstants } from '@nimkit/common';
import { NECameraSelectView } from '../view/NECameraSelectView';
import { common } from '@kit.AbilityKit';
import { cameraPicker } from '@kit.CameraKit';
import { LengthMetrics, promptAction, window } from '@kit.ArkUI';
import { NERectData } from '../model/NERectData';
import { MessageOperationView } from '../view/MessageOperationView';
import { MessageOperationItem, MessageOperationType } from '../model/MessageOperationItem';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { DeviceUtils } from '../common/DeviceUtils';
import { ImageViewDialog } from '@nimkit/common';
import { V2NIMMessage, V2NIMMessageAudioAttachment, V2NIMMessageLocationAttachment, V2NIMMessageSendingState, V2NIMMessageType } from '@nimsdk/base';
import { ChatConst } from '../constants/ChatConst';
import { ChatKitClient } from '@nimkit/chatkit';
import { AudioRecordManager } from '../manager/AudioRecordManager';
import { AudioPlayerManager } from '../manager/AudioPlayerManager';
import {
  conversationSelectLimitCount,
  ConversationSelectParam,
  CustomMessageUtils,
  ErrorUtils,
  getMultiLineBody,
  getMultiLineTitle,
  AIUserManager,
  IMKitConfigCenter,
  isMultiLineMessage,
  MergedMessageAttachment,
  mergedMessageCustomType,
  mergedMessageLimitCount,
  mergedMessageMaxDepth,
  NEAIUserCache,
  NEFriendUserCache,
  parseMultiLineAttachment,
  singleMessageLimitCount,
  SubscriptionRepo,
  UserAIBotManager,
  ChatRepo
} from '@nimkit/chatkit';
import { ConversationSelectModel } from '@nimkit/chatkit';
import { ForwardMessageDialog } from '../view/ForwardMessageDialog';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import {
  contentOfMessage,
  downLoadAndOpenFile,
  getMessageImageUrl,
  getMessageImageUrls,
  getMessageVideoRatio,
  getMessageVideoUrl,
  getReplyMessageTitle
} from '../common/MessageHelper';
import { sceneMap } from '@kit.MapKit';
import {
  canShowAISearchForMessage,
  computeOperateViewHeightByCount,
  computeOperateViewWidthByCount,
  getOperateMenu,
  getSelectedTextOperateMenu,
  getTranslationOperateMenu,
  setupMoreOperationData
} from '../common/ChatUtils';
import { ChatMultiSelectView } from '../view/ChatMultiSelectView';
import { TextMessageDetailDialog } from '../view/TextMessageDetailDialog';
import { ChatKitUIClient } from '../ChatKitUIClient';
import { FraudTipView } from '../view/FraudTipView';
import { HashMap } from '@kit.ArkTS';
import { IsReceiveMsgOperation } from '../model/IsReceiveMsg';
import { MessageTranslationService } from '../service/translation/MessageTranslationService';
import { AitManager } from '../manager/ait/AitManager';
import {
  collectRichInputTransferNodes,
  RichInputTransferNode,
  RichInputTransferNodeType,
  restoreAitTransferNodesFromMessageText
} from '../common/InputTransferUtils';
import { buildAIHelperContext } from '../common/AIHelperUtils';

@ComponentV2
export struct ChatP2PPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local chatUserInfo: ChatUserInfo = new ChatUserInfo();
  chatViewModel: ChatP2PViewModel = new ChatP2PViewModel();
  conversationId: string = '';
  // 底部扩展区域高度，默认为0
  @Local expandHeight: number = 0;
  @Local inputStyle: InputStyleType = InputStyleType.None;
  @Local aiHelperLoading: boolean = false
  @Local aiHelperError: boolean = false
  @Local aiHelperItems: AIHelperItem[] = []
  aiHelperLastMessageClientId: string = ''
  aiHelperHiddenByMessageListTouch: boolean = false
  aiHelperMediaRestoreTask: number = -1
  @Local showTranslateView: boolean = false
  @Local translateResetKey: number = 0
  @Local hideInput: boolean = false;
  @Local scrollHeight: number = 0;
  @Local showOperationView: boolean = false;
  @Local showMultiSelect: boolean = false;
  @Local multiSelectCount: number = 0;
  // 长按操作弹窗的边距值
  operationViewMargin: number = 12;
  defaultInputViewHeight: number = 0;
  // 长按操作选中的消息
  @Local operationMsg: NIMMessageInfo | undefined = undefined
  @Local translatedActionMsg: NIMMessageInfo | undefined = undefined
  @Local translationOperationMode: boolean = false
  @Local operationMenuItems: Array<MessageOperationItem> | undefined = undefined
  @Local selectedOperationText: string = ''
  @Local showAISearchPanel: boolean = false
  @Local aiSearchKeyword: string = ''
  @Local aiSearchSelectionState: AISearchSelectionState = new AISearchSelectionState()
  @Local aiSearchSelectingMessageId: string = ''
  @Local replyMsg: NIMMessageInfo | undefined = undefined
  // 撤回重编辑的富文本内容
  @Local revokeMultiLineContent: string = ''
  // 多行输入模式的标题和正文
  @Local multiLineTitle: string = ''
  @Local multiLineBody: string = ''
  @Local multiLineBodyNodes: RichInputTransferNode[] = []
  // 多行输入面板组件实例引用
  multiLineInputViewInstance?: MultiLineInputView = undefined
  @Local operationRect: NERectData = new NERectData()
  screenHeight: number = 0;
  screenWidth: number = 0;
  keyboardHeight: number = 0
  //导航栏高度，用于计算弹窗位置
  navBarHeight: number = 80;
  // 底部输入框以及固定按钮操作栏高度
  @Local bottomHeight: number = 105;
  @Local translatePanelHeight: number = 80
  @Local translateResult: string = ''
  @Local translateIsLoading: boolean = false
  @Local translateIsResultMode: boolean = false
  @Local translateInputText: string = ''
  bottomMargin: number = 100;
  bottomWithReplyHeight: number = 135;
  aiHelperInputHeight: number = 50;
  aiHelperPanelHeight: number = 235;
  controller: RichEditorController = new RichEditorController()
  //@所在的span
  builderSpans: AitEditorSpan[] = []
  aitManager: AitManager = new AitManager()
  operationMoreDataList: Array<NEChatMoreOperationData> = Array()
  listScroller: Scroller = new Scroller()
  toScroll: boolean = false
  inputContentLength: number = 0
  // 接受消息标记
  msgSize: number = 0
  // 列表滚动位置
  listScrollStartPosition: number = 0
  listScrollEndPosition: number = 0
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
  // 新增：是否需要停止录音（用于通知 NEAudioRecordView 停止录音）
  @Local shouldStopRecord: boolean = false;
  // 新增：tipBannerArea 的高度（防诈条+断网条）
  @Local tipBannerHeight: number = 0;
  // 新增：转发弹窗是否打开（用于阻止键盘弹出时自动滚动到底部）
  isForwardDialogOpen: boolean = false;
  private pendingExpandPanelAfterKeyboardHide: boolean = false
  private singleLineFocusTask: number = -1
  private multiLineFocusTask: number = -1
  private translationFinishedListener: (messageClientId: string) => void = (messageClientId: string) => {
    this.handleTranslationFinished(messageClientId)
  }
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
        MediaUtils.showCameraPicker(context, cameraPicker.PickerMediaType.VIDEO).then((result) => {
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
  textMessageDetailDialog: CustomDialogController | undefined = undefined
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
          // 退出多选模式后，如果是多行输入模式，恢复 bottomHeight
          if (this.inputStyle === InputStyleType.Multiline) {
            this.bottomHeight = 0
          }
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
  private closeTextMessageDetailDialog(): void {
    this.textMessageDetailDialog?.close()
  }

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
  forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
    if (this.operationMsg?.message) {
      this.forwardMessages = [this.operationMsg.message]
      this.forwardConversations = selectedList
      this.currentConversationName = this.chatUserInfo.getConversationName()
      this.isForwardDialogOpen = true
      this.forwardMessageDialog.open()
    }
  }

  @Monitor("chatUserInfo.isReceiveMsg")
  onReceiveMsg() {
    if (this.firstLoadData || this.chatUserInfo.isReceiveMsg.yes) {
      // 检查是否在底部（需要考虑新增消息导致的 totalCount 变化）
      // 新增消息数量
      const newMsgCount = this.chatUserInfo.isReceiveMsg.messages?.length ?? 0
      // 用收到消息前的 totalCount 来判断是否在底部
      const totalCountBeforeReceive = this.chatUserInfo.msgList.totalCount() - newMsgCount
      const wasAtBottomBeforeReceive = this.listScrollEndPosition >= totalCountBeforeReceive - 1

      // is call message
      const isCallMessage: boolean = this.chatUserInfo.isReceiveMsg.messages
        && this.chatUserInfo.isReceiveMsg.messages.length > 0
        && this.chatUserInfo.isReceiveMsg.messages[0].messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL

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
        if (this.chatUserInfo.isReceiveMsg.operation === IsReceiveMsgOperation.DELETE) {
          // 删除操作需要减少计数
          this.subNewMessageCount()
        } else {
          // 新消息操作需要增加计数
          this.addNewMessageCount()
        }
        this.showScrollToNewMessageButton = true
      }

      this.chatUserInfo.setReceiveMsg(false)
      this.firstLoadData = false;
    }
  }

  @Monitor("chatUserInfo.scrollIndex")
  onScrollIndex() {
    if (this.chatUserInfo.scrollIndex > -1) {
      this.toScroll = true
      // 使用 ScrollAlign.CENTER 让消息居中显示
      this.listScroller.scrollToIndex(this.chatUserInfo.scrollIndex, false, ScrollAlign.CENTER)
      this.chatViewModel.setAnchorMessage(undefined)
      this.chatUserInfo.setScrollIndex(-1)
    }
  }

  @Monitor("chatViewModel.needScrollToBottom")
  onNeedScrollToBottom() {
    if (this.chatViewModel.needScrollToBottom &&
      this.listScrollEndPosition >= this.chatUserInfo.msgList.totalCount() - 1) {
      this.listScroller.scrollEdge(Edge.Bottom)
      this.chatViewModel.needScrollToBottom = false;
    }
  }

  @Monitor("chatViewModel.anchorMsg")
  onAnchorMsg() {
    if (this.chatViewModel.anchorMsg) {
      this.chatViewModel.loadAnchorMsg(this.chatViewModel.anchorMsg)
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
    const totalCount = this.chatUserInfo.msgList.totalCount()
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
    // 重置状态
    this.clearNewMessageCount()
    this.showScrollToNewMessageButton = false
    this.isAtBottom = true
  }

  private handleTranslationFinished(messageClientId: string): void {
    const allMessages = this.chatUserInfo.msgList.getMessageList()
    const lastMessage = allMessages[allMessages.length - 1]
    if (!lastMessage || lastMessage.message.messageClientId !== messageClientId) {
      return
    }
    if (!this.isAtBottom || this.isForwardDialogOpen || !this.chatViewModel.isPageVisible) {
      return
    }
    setTimeout(() => {
      if (this.chatViewModel.hasNew) {
        this.chatViewModel.reloadMessageList()
      } else {
        this.scrollToNewMessage()
      }
    }, 20)
  }

  /**
   * 从多行正文 RichEditor 提取纯文本
   */
  aboutToAppear(): void {
    NEEmojiManager.instance.setup();
    DeviceUtils.rootDirPath = getContext(this).filesDir
    this.operationMoreDataList = setupMoreOperationData(true, NEAIUserCache.getAIUser(this.chatUserInfo.targetId) !== undefined)
    MessageTranslationService.instance.addTranslationFinishedListener(this.translationFinishedListener)
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
          // 键盘弹出时自动退出 AI 助聊模式
          if (this.keyboardHeight > 10 && this.inputStyle === InputStyleType.AiHelper) {
            this.bottomHeight = this.getSingleLineInputHeight()
            this.expandHeight = 0
            this.inputStyle = InputStyleType.None
          }
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
    const translateHeight = this.getTranslatePanelHeight()
    if (((this.inputStyle === InputStyleType.Emoji || this.inputStyle === InputStyleType.Record ||
      this.inputStyle === InputStyleType.More) && this.keyboardHeight <= 0) ||
      this.inputStyle === InputStyleType.AiHelper) {
      if (this.inputStyle !== InputStyleType.AiHelper) {
        this.pendingExpandPanelAfterKeyboardHide = false
      }
      this.scrollHeight = this.screenHeight - this.bottomHeight - this.expandHeight - translateHeight
    } else if (this.inputStyle === InputStyleType.Multiline) {
      // 多行模式：bottomHeight = 0，需要考虑 expandHeight
      this.scrollHeight = this.screenHeight - this.keyboardHeight - this.expandHeight - translateHeight
      // 键盘弹出时滚动到底部
      if (this.keyboardHeight > 10) {
        setTimeout(() => {
          if (!this.isForwardDialogOpen && this.chatViewModel.isPageVisible) {
            this.listScroller.scrollEdge(Edge.Bottom)
          }
        }, 20)
      }
    } else {
      this.scrollHeight = this.screenHeight - this.keyboardHeight - this.bottomHeight - translateHeight
      if (this.keyboardHeight > 10) {
        if (!this.pendingExpandPanelAfterKeyboardHide) {
          this.expandHeight = 0
          this.inputStyle = InputStyleType.None;
        }
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

  private getTranslatePanelHeight(): number {
    return this.showTranslateView && !this.showMultiSelect ? this.translatePanelHeight : 0
  }

  private getChatInputContainerHeight(): number {
    if (this.showTranslateView && !this.showMultiSelect) {
      return this.bottomHeight + this.translatePanelHeight
    }
    return this.bottomHeight
  }

  private getSingleLineInputHeight(): number {
    return this.replyMsg ? this.bottomWithReplyHeight : 105
  }

  private getAIHelperInputHeight(): number {
    return this.aiHelperInputHeight + (this.replyMsg ? this.bottomWithReplyHeight - 105 : 0)
  }

  private getInputExpandContainerHeight(): number {
    return this.expandHeight
  }

  private getTranslateInputText(): string {
    if (this.inputStyle === InputStyleType.Multiline) {
      return this.multiLineInputViewInstance?.getMultiLineBodyText() ?? this.multiLineBody
    }
    return this.getMessageText()
  }

  private syncTranslateInputText() {
    this.translateInputText = this.getTranslateInputText()
  }

  private setTranslateInputText(text: string) {
    if (this.inputStyle === InputStyleType.Multiline) {
      this.multiLineInputViewInstance?.setBodyText(text)
      this.multiLineBody = text
      this.multiLineBodyNodes = []
      this.aitManager.cleanAit()
      return
    }
    this.controller.deleteSpans()
    this.builderSpans.splice(0, this.builderSpans.length)
    this.aitManager.cleanAit()
    if (text.length > 0) {
      this.controller.addTextSpan(text, { offset: 0 })
    }
  }

  private showAITranslateView() {
    if (!IMKitConfigCenter.enableAI || !AIUserManager.getAITranslateUser()) {
      return
    }
    this.showTranslateView = true
    if (this.inputStyle === InputStyleType.More) {
      this.inputStyle = InputStyleType.None
      this.expandHeight = 0
    }
    this.computeScrollHeight()
  }

  private hideAITranslateView() {
    this.showTranslateView = false
    this.clearAITranslateState()
    this.computeScrollHeight()
  }

  private hideAIHelperPanel() {
    if (this.inputStyle !== InputStyleType.AiHelper) {
      return
    }
    this.bottomHeight = this.getSingleLineInputHeight()
    this.expandHeight = 0
    this.inputStyle = InputStyleType.None
    this.computeScrollHeight()
  }

  private resetAIHelperCache() {
    this.aiHelperLoading = false
    this.aiHelperError = false
    this.aiHelperItems = []
    this.aiHelperLastMessageClientId = ''
    this.clearPendingAIHelperMediaRestore()
  }

  private restoreAIHelperPanelForMediaPreview() {
    if (!this.aiHelperHiddenByMessageListTouch) {
      return
    }
    this.clearAIHelperMediaRestoreTask()
    this.aiHelperHiddenByMessageListTouch = false
    this.inputStyle = InputStyleType.AiHelper
    this.bottomHeight = this.getAIHelperInputHeight()
    this.expandHeight = this.aiHelperPanelHeight
    this.computeScrollHeight()
  }

  private markAIHelperHiddenByMessageListTouch() {
    this.aiHelperHiddenByMessageListTouch = this.inputStyle === InputStyleType.AiHelper
    if (!this.aiHelperHiddenByMessageListTouch) {
      return
    }
    this.clearAIHelperMediaRestoreTask()
    this.aiHelperMediaRestoreTask = setTimeout(() => {
      this.aiHelperMediaRestoreTask = -1
      this.aiHelperHiddenByMessageListTouch = false
    }, 1500)
  }

  private clearAIHelperMediaRestoreTask() {
    if (this.aiHelperMediaRestoreTask >= 0) {
      clearTimeout(this.aiHelperMediaRestoreTask)
      this.aiHelperMediaRestoreTask = -1
    }
  }

  private clearPendingAIHelperMediaRestore() {
    this.clearAIHelperMediaRestoreTask()
    this.aiHelperHiddenByMessageListTouch = false
  }

  private resetAITranslateView() {
    if (this.showTranslateView) {
      this.translateResetKey += 1
    }
    this.clearAITranslateState()
  }

  private clearAITranslateState() {
    this.translateResult = ''
    this.translateIsLoading = false
    this.translateIsResultMode = false
  }

  private getAIChatUsers() {
    return AIUserManager.getAIChatUserList()
  }

  private canAitAIUser(): boolean {
    return IMKitConfigCenter.enableAI &&
      this.getAIChatUsers().length > 0 &&
      !AIUserManager.isAIUser(this.chatUserInfo.targetId)
  }

  private shouldShowOnlineState(): boolean {
    return IMKitConfigCenter.enableShownOnlineState &&
      !AIUserManager.isAIUser(this.chatUserInfo.targetId)
  }

  private getAitPushList(): string[] | undefined {
    return this.aitManager.getPushList()
  }

  private getFirstAitAIUserAccount(): string | undefined {
    return this.aitManager.getFirstAIChatAccount(this.getAIChatUsers().map(aiUser => aiUser.accountId))
  }

  private getOperationText(): string {
    if (!this.operationMsg) {
      return ''
    }
    if (this.selectedOperationText.length > 0) {
      return this.selectedOperationText
    }
    if (this.translationOperationMode) {
      return MessageTranslationService.instance.getTranslatedDisplayText(this.operationMsg)
    }
    if (this.operationMsg.isMultiLineMsg) {
      const title = getMultiLineTitle(this.operationMsg.message)
      const body = getMultiLineBody(this.operationMsg.message)
      return title && body ? `${title}\n${body}` : (title || body)
    }
    return this.operationMsg.message.text ?? ''
  }

  private getAISearchOperationText(): string {
    if (!this.operationMsg) {
      return ''
    }
    if (this.selectedOperationText.length > 0) {
      return this.selectedOperationText
    }
    if (this.translationOperationMode) {
      return MessageTranslationService.instance.getTranslatedDisplayText(this.operationMsg)
    }
    if (this.operationMsg.isMultiLineMsg) {
      return getMultiLineAISearchText(getMultiLineBody(this.operationMsg.message))
    }
    return this.operationMsg.message.text ?? ''
  }

  private getMessageAISearchText(msg: NIMMessageInfo | undefined): string {
    if (!msg) {
      return ''
    }
    if (msg.isMultiLineMsg) {
      return getMultiLineAISearchText(getMultiLineBody(msg.message))
    }
    if (msg.getMessageType() === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      return msg.message.text ?? ''
    }
    return ''
  }

  private getSelectionOperationMenuItems(): MessageOperationItem[] {
    if (this.translationOperationMode && this.aiSearchSelectionState.isAllSelected()) {
      return getTranslationOperateMenu()
    }
    if (this.translationOperationMode) {
      // Hide AI search for translated text
      return getSelectedTextOperateMenu(this.aiSearchSelectionState.selectedText(), false)
    }
    if (!this.aiSearchSelectionState.active || this.aiSearchSelectionState.isAllSelected()) {
      return getOperateMenu(this.operationMsg)
    }
    return getSelectedTextOperateMenu(this.aiSearchSelectionState.selectedText())
  }

  private updateSelectionOperationMenu(): void {
    if (!this.aiSearchSelectionState.active) {
      return
    }
    this.selectedOperationText = this.aiSearchSelectionState.isAllSelected() ? '' :
    this.aiSearchSelectionState.selectedText()
    this.operationMenuItems = this.getSelectionOperationMenuItems()
    const itemCount = this.operationMenuItems.length
    const opMenuWidth = computeOperateViewWidthByCount(itemCount)
    const opMenuHeight = computeOperateViewHeightByCount(itemCount)
    this.operationRect.x = this.aiSearchSelectionState.rectX +
      (this.aiSearchSelectionState.rectWidth - opMenuWidth) / 2
    if (this.operationRect.x < this.operationViewMargin) {
      this.operationRect.x = this.operationViewMargin
    }
    if (this.operationRect.x + opMenuWidth + this.operationViewMargin > this.screenWidth) {
      this.operationRect.x = this.screenWidth - opMenuWidth - this.operationViewMargin
    }
    this.operationRect.y = this.aiSearchSelectionState.rectY - opMenuHeight - this.operationViewMargin
    if (this.operationRect.y < 0) {
      this.operationRect.y = this.aiSearchSelectionState.rectY + this.aiSearchSelectionState.rectHeight +
        this.operationViewMargin
    }
    this.showOperationView = itemCount > 0
  }

  private closeAISearchSelection(): void {
    this.aiSearchSelectionState.close()
    this.aiSearchSelectingMessageId = ''
  }

  private clearOperationMenuIfMatch(messageClientId?: string): void {
    if (!messageClientId ||
      (this.operationMsg?.getMessageClientId() !== messageClientId &&
        this.aiSearchSelectingMessageId !== messageClientId)) {
      return
    }
    this.showOperationView = false
    this.operationMsg = undefined
    this.translatedActionMsg = undefined
    this.translationOperationMode = false
    this.operationMenuItems = undefined
    this.selectedOperationText = ''
    this.closeAISearchSelection()
  }

  private openAISearchSelection(event: GestureEvent, msg: NIMMessageInfo | undefined): boolean {
    if (!canShowAISearchForMessage(msg)) {
      return false
    }
    const text = this.getMessageAISearchText(msg).trim()
    Logger.info('ChatKitUI', `[AISearchMarkdownSelect] P2P openAISearchSelection msgId=${msg?.getMessageClientId()} textLength=${text.length} type=${msg?.getMessageType()} aiResponse=${msg?.isAIResponseMsg()} aiStream=${msg?.isAiStreamMessage()}`)
    return this.openTextSelection(event, msg, text, false)
  }

  private openTranslationSelection(event: GestureEvent, msg: NIMMessageInfo | undefined): boolean {
    const text = msg ? MessageTranslationService.instance.getTranslatedDisplayText(msg).trim() : ''
    return this.openTextSelection(event, msg, text, true)
  }

  private openTextSelection(event: GestureEvent, msg: NIMMessageInfo | undefined, text: string,
    isTranslation: boolean): boolean {
    Logger.info('ChatKitUI', `[AISearchMarkdownSelect] P2P openTextSelection msgId=${msg?.getMessageClientId()} textLength=${text.length} isTranslation=${isTranslation} hasX=${event.target.area.globalPosition.x !== undefined} hasY=${event.target.area.globalPosition.y !== undefined}`)
    if (text.length === 0 || event.target.area.globalPosition.x === undefined ||
      event.target.area.globalPosition.y === undefined) {
      this.closeAISearchSelection()
      Logger.info('ChatKitUI', `[AISearchMarkdownSelect] P2P openTextSelection close msgId=${msg?.getMessageClientId()}`)
      return false
    }
    this.aiSearchSelectionState.open(text,
      Number(event.target.area.globalPosition.x),
      Number(event.target.area.globalPosition.y) - this.navBarHeight,
      Number(event.target.area.width),
      Number(event.target.area.height))
    this.operationMsg = msg
    this.translatedActionMsg = isTranslation ? msg : undefined
    this.translationOperationMode = isTranslation
    this.aiSearchSelectingMessageId = msg?.getMessageClientId() ?? ''
    this.selectedOperationText = ''
    this.operationMenuItems = this.getSelectionOperationMenuItems()
    this.updateSelectionOperationMenu()
    Logger.info('ChatKitUI', `[AISearchMarkdownSelect] P2P setSelectingMessageId id=${this.aiSearchSelectingMessageId}`)
    Logger.info('ChatKitUI', `[AISearchMarkdownSelect] P2P openTextSelection opened msgId=${msg?.getMessageClientId()} active=${this.aiSearchSelectionState.active} rect=${this.aiSearchSelectionState.rectX},${this.aiSearchSelectionState.rectY},${this.aiSearchSelectionState.rectWidth},${this.aiSearchSelectionState.rectHeight}`)
    return true
  }

  private showOperationMenu(event: GestureEvent, msg: NIMMessageInfo | undefined,
    operationItems?: Array<MessageOperationItem>, selectedText: string = ''): void {
    if (selectedText.length === 0) {
      this.closeAISearchSelection()
    }
    this.operationMsg = msg
    this.translationOperationMode = false
    this.operationMenuItems = operationItems
    this.selectedOperationText = selectedText
    const itemCount = operationItems ? operationItems.length : getOperateMenu(msg).length
    let opMenuWidth = computeOperateViewWidthByCount(itemCount)
    let opMenuHeight = computeOperateViewHeightByCount(itemCount)
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
    this.showOperationView = itemCount > 0
  }

  private updateTextSelection(msg: NIMMessageInfo | undefined, text: string, start: number, end: number,
    isTranslation: boolean): void {
    Logger.info('ChatKitUI', `[AISearchMarkdownSelect] P2P updateTextSelection enter msgId=${msg?.getMessageClientId()} active=${this.aiSearchSelectionState.active} operationSame=${this.operationMsg === msg} mode=${this.translationOperationMode} isTranslation=${isTranslation} start=${start} end=${end} textLength=${text.length}`)
    if (!this.aiSearchSelectionState.active || this.operationMsg !== msg ||
      this.translationOperationMode !== isTranslation) {
      return
    }
    this.aiSearchSelectionState.text = text
    this.aiSearchSelectionState.updateRange(start, end)
    this.translatedActionMsg = isTranslation ? msg : undefined
    this.selectedOperationText = this.aiSearchSelectionState.isAllSelected() ? '' :
    this.aiSearchSelectionState.selectedText()
    this.updateSelectionOperationMenu()
    Logger.info('ChatKitUI', `[AISearchMarkdownSelect] P2P updateTextSelection updated allSelected=${this.aiSearchSelectionState.isAllSelected()} selectedLength=${this.selectedOperationText.length}`)
  }

  @Builder
  AITranslatePanel() {
    AITranslateView({
      inputText: this.translateInputText,
      translateAccountId: AIUserManager.getAITranslateUser()?.accountId ?? '',
      loginAccountId: ChatKitClient.getLoginUserId(),
      languages: AIUserManager.getAITranslateLanguages(),
      resetKey: this.translateResetKey,
      initialTranslateResult: this.translateResult,
      initialIsLoading: this.translateIsLoading,
      initialIsResultMode: this.translateIsResultMode,
      onTranslateClick: () => {
        return this.getTranslateInputText()
      },
      onResultClick: (text: string) => {
        this.setTranslateInputText(text)
        this.computeScrollHeight()
      },
      onStateChange: (translateResult: string, isResultMode: boolean, isLoading: boolean) => {
        this.translateResult = translateResult
        this.translateIsResultMode = isResultMode
        this.translateIsLoading = isLoading
      },
      onCloseClick: () => {
        this.hideAITranslateView()
      },
      onHeightChange: (height: number) => {
        if (height !== this.translatePanelHeight) {
          this.translatePanelHeight = height
          this.computeScrollHeight()
        }
      }
    })
      .width('100%')
      .height(this.translatePanelHeight)
      .backgroundColor('#F5F5F5')
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

  getMessageText(): string {
    this.aitManager.cleanAit()
    const nodes = collectRichInputTransferNodes(this.controller?.getSpans(), this.builderSpans)
    let text = ''
    nodes.forEach((node) => {
      if (node.type === RichInputTransferNodeType.Ait) {
        this.aitManager.addAitWithText(node.accountId ?? '', node.text, text.length)
      }
      text += node.text
    })
    return text
  }

  isAitEditorSpan(span: RichEditorImageSpanResult | RichEditorTextSpanResult): boolean {
    return !(span as RichEditorTextSpanResult).value &&
      !(span as RichEditorImageSpanResult).valueResourceStr?.toString().replaceAll(' ', '')
  }

  @Builder
  AtSpan(nickname: string) {
    Text(nickname)
      .fontColor('#FF337EFF')
  }

  private restoreSingleLineTransferNodes(title: string, bodyText: string, bodyNodes: RichInputTransferNode[]) {
    this.controller.deleteSpans()
    this.builderSpans.splice(0, this.builderSpans.length)
    if (title.length > 0) {
      this.controller.addTextSpan(bodyText.length > 0 || bodyNodes.length > 0 ? `${title}\n` : title)
    }
    if (bodyNodes.length > 0) {
      bodyNodes.forEach((node) => {
        if (node.type === RichInputTransferNodeType.Text) {
          if (node.text.length > 0) {
            this.controller.addTextSpan(node.text)
          }
          return
        }

        if (node.type === RichInputTransferNodeType.Emoji && node.emojiFile) {
          this.controller.addImageSpan($rawfile(`emoji/${node.emojiFile}`), {
            imageStyle: { size: [16, 16] }
          })
          return
        }

        if (node.type === RichInputTransferNodeType.Ait) {
          const spanOffset = this.controller.getCaretOffset()
          this.controller.addBuilderSpan(() => this.AtSpan(node.text), {
            offset: spanOffset
          })
          this.builderSpans.push({
            spanIndex: spanOffset,
            accountId: node.accountId ?? '',
            value: node.text
          })
        }
      })
      return
    }

    if (bodyText.length > 0) {
      this.controller.addTextSpan(bodyText)
    }
  }

  loadChatData() {
    this.chatUserInfo.setConversationId(this.conversationId)
    this.chatViewModel.init(this.conversationId, this.chatUserInfo);
    this.chatViewModel.onOperateMessageInvalid = (messageClientId: string) => {
      this.clearOperationMenuIfMatch(messageClientId)
    }
    this.chatViewModel.loadData();
  }

  async showImageDetail(msg?: NIMMessageInfo, onlyMsg?: boolean) {
    try {
      const imageModel =
        onlyMsg ? await getMessageImageUrl(msg, this.chatUserInfo) : await getMessageImageUrls(msg, this.chatUserInfo)
      this.restoreAIHelperPanelForMediaPreview()
      this.imagesIndexModel = imageModel
      this.chatViewModel.isPageVisible = false
      this.imageViewerDialog.open()
    } catch (err) {
      this.clearPendingAIHelperMediaRestore()
      Logger.error('ChatKitUI', err)
    }
  }

  showVideoDetail(msg: NIMMessageInfo) {
    AudioPlayerManager.instance.stopPlayAll()
    this.videoFileUrl = getMessageVideoUrl(msg, this.chatUserInfo)
    if (this.videoFileUrl == undefined) {
      this.clearPendingAIHelperMediaRestore()
      NECommonUtils.showToast($r('app.string.chat_msg_download_tips'))
      return
    }
    this.videoRatio = getMessageVideoRatio(msg)
    if (this.videoFileUrl) {
      this.restoreAIHelperPanelForMediaPreview()
      this.chatViewModel.isPageVisible = false
      this.videoViewerDialog.open()
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
      Logger.info('ChatKitUI', "netease QueryLocation", "Succeeded in querying location.");
    }).catch((err: BusinessError) => {
      Logger.error('ChatKitUI', "netease QueryLocation", `Failed to query Location, code: ${err.code}, message: ${err.message}`);
    });
  }

  @Builder
  build() {
    NavDestination() {
      Stack() {
        Column() {
          NavigationBackBuilder({
            title: this.chatUserInfo.conversationName,
            // 在线状态显示
            titleSuffix: this.shouldShowOnlineState()
              ? (SubscriptionRepo.getOnlineState(this.chatUserInfo.targetId)
                ? $r('app.string.chat_title_status_online')
                : $r('app.string.chat_title_status_offline'))
              : undefined,
            // 听筒模式时显示听筒图标
            titleSuffixIcon: IMKitConfigCenter.enableEarphoneMode
              ? $r('app.media.ic_chat_audio_earphone')
              : undefined,
            rightButtonIcon: this.showMultiSelect ? undefined : $r('app.media.ic_public_more_dot'),
            rightButtonTitle: this.showMultiSelect ? $r('app.string.chat_msg_dialog_cancel') : undefined,
            rightButtonAction: () => {
              this.goToSettingPage(this.pathStack)
            },
            leftButtonAction: () => {
              this.pathStack.pop()
            },
            // 正在输入提示
            enableTypingIndicator: IMKitConfigCenter.enableTypingStatus,
            showTypingIndicator: this.chatViewModel.isRemoteTyping,
            typingIndicatorText: $r('app.string.chat_typing_indicator')
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
            LazyForEach(this.chatUserInfo.msgList, (msg: NIMMessageInfo) => {
              ListItem() {
                MessageComponent({
                  message: msg,
                  chatInfo: this.chatUserInfo,
                  showSelect: this.showMultiSelect,
                  aiSearchSelectingMessageId: this.aiSearchSelectingMessageId,
                  aiSearchSelectingTranslation: this.translationOperationMode,
                  onMessageClick: {
                    onAvatarClick: ((msg: NIMMessageInfo | undefined) => {
                      if (this.showMultiSelect) {
                        return
                      }
                      if (msg != null) {
                        const senderId = msg.getDisplaySenderId()
                        if (senderId == ChatKitClient.getLoginUserId()) {
                          this.pathStack.pushPath({
                            name: 'MineInfoPage'
                          })
                        } else {
                          if (senderId && NEAIUserCache.getAIUser(senderId)) {
                            this.pathStack.pushPath({ name: 'AIPersonInfoPage', param: senderId })
                          } else {
                            this.pathStack.pushPath({ name: 'PersonInfoPage', param: senderId })
                          }
                        }
                      }
                    }),
                    onItemLongClick: ((event: GestureEvent, msg: NIMMessageInfo | undefined) => {
                      if (this.showMultiSelect) {
                        return
                      }
                      if (msg?.isRevokeMsg) {
                        return
                      }
                      if (msg?.isAIStreamInProgress()) {
                        return
                      }
                      if (this.openAISearchSelection(event, msg)) {
                        return
                      }
                      this.showOperationMenu(event, msg, getOperateMenu(msg))
                    }),
                    onItemClick: (_event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (this.showMultiSelect) {
                        if (msg?.canOperateInMultiSelect()) {
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
                      if (this.showMultiSelect) {
                        return
                      }
                      if (msg?.checkRevokeEdit()) {
                        const attachment = msg.revokeInfo?.revokeMsgAttachment
                        const multiLine = attachment && attachment.length > 0 ? parseMultiLineAttachment(attachment) : null

                        this.resetMultiLineDraft()
                        if (!multiLine) {
                          this.exitMultiLineEditMode()
                        }

                        this.clearInput(true)
                        if (msg.isReplyMsg && msg.replyMsg) {
                          this.loadReplyInfo(msg.replyMsg)
                        }
                        if (multiLine) {
                          const bodyNodes =
                            restoreAitTransferNodesFromMessageText(multiLine.data.body, msg.message.serverExtension)
                          this.revokeMultiLineContent = JSON.stringify({
                            title: multiLine.data.title,
                            body: multiLine.data.body,
                            bodyNodes: bodyNodes,
                            _ts: Date.now()
                          })
                          return
                        }

                        const bodyNodes =
                          restoreAitTransferNodesFromMessageText(msg.revokeInfo?.revokeMsgText,
                            msg.message.serverExtension)
                        this.restoreSingleLineTransferNodes('', msg.revokeInfo?.revokeMsgText ?? '', bodyNodes)
                      } else if (msg?.revokeInfo !== undefined) {
                        NECommonUtils.showToast($r('app.string.chat_revoke_edit_error_tips'))
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
                    onReplyClick: (_event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (msg) {
                        if (this.chatUserInfo.msgMap.has(msg.getMessageClientId())) {
                          let index = this.chatUserInfo.searchPosition(msg.getMessageClientId())
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
                    onTranslatedAreaLongClick: (event: GestureEvent, msg: NIMMessageInfo | undefined) => {
                      if (msg) {
                        if (this.openTranslationSelection(event, msg)) {
                          return
                        }
                        this.operationMsg = msg
                        this.translatedActionMsg = msg
                        this.translationOperationMode = true
                        this.operationMenuItems = getTranslationOperateMenu()
                        this.showOperationMenu(event, msg, this.operationMenuItems)
                        this.translationOperationMode = true
                      }
                    },
                    onTextSelectionChange: (msg: NIMMessageInfo | undefined, text: string, start: number,
                      end: number, isTranslation: boolean) => {
                      this.updateTextSelection(msg, text, start, end, isTranslation)
                    },
                    onAvatarLongPress: () => {

                    },
                    onReadReceiptClick: (_event: ClickEvent) => {

                    },
                    // AI 流式消息 - 停止输出
                    onAIStreamStop: (_event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (msg) {
                        this.chatViewModel.stopAIStream(msg)
                      }
                    },
                    // AI 流式消息 - 重新生成
                    onAIStreamRefresh: (_event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                      if (msg) {
                        this.chatViewModel.regenAIMessage(msg)
                      }
                    }
                  },
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
          .cachedCount(3)
          .maintainVisibleContentPosition(true)
          .padding({ bottom: 0 })
          .onScrollIndex((start: number, end: number) => {
            // Listen to the first index of the current list.
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
            // 只按当前可见区发送已读回执，避免把未进入视窗的消息提前标记。
            if (this.chatViewModel.isPageVisible) {
              const allMessages = this.chatUserInfo.msgList.getMessageList()
              const visibleMessages = allMessages.slice(this.listScrollStartPosition, this.listScrollEndPosition + 1)
              this.chatViewModel.toHandleReceiptMessage(visibleMessages)
            }
            // 检查是否在底部，更新状态
            this.checkIfAtBottom()
          })
          .onScrollStop(() => {
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
            this.closeAISearchSelection()
            this.clearPendingAIHelperMediaRestore()
          })
          .onTouch((event) => {
            if (event.type == TouchType.Down) {
              this.markAIHelperHiddenByMessageListTouch()
              this.showOperationView = false
              this.closeAISearchSelection()
              this.getUIContext().getFocusController().clearFocus();
              // 多行模式下点击消息列表不切换模式，只收起键盘
              if (this.inputStyle === InputStyleType.Multiline) {
                return
              }
              // 非多行模式：收起 emoji/more/record/aiHelper 面板
              this.pendingExpandPanelAfterKeyboardHide = false
              this.bottomHeight = this.getSingleLineInputHeight()
              this.expandHeight = 0;
              this.inputStyle = InputStyleType.None
              this.computeScrollHeight()
            }
          })

          Column() {
            if (this.showTranslateView && !this.showMultiSelect) {
              this.AITranslatePanel()
            }
          }
            .height(this.getChatInputContainerHeight())
            .backgroundColor(Color.Transparent)
            .backgroundColor($r('app.color.chat_input_background'))
            .id("chat_input")
            .alignRules({
              left: { anchor: "__container__", align: HorizontalAlign.Start },
              right: { anchor: "__container__", align: HorizontalAlign.End },
              top: { anchor: "chatPageListView", align: VerticalAlign.Bottom },
            })

          // 单行输入框：使用 visibility 控制显隐，避免组件销毁导致内容丢失
          if (this.hideInput === false) {
            NEChatInputView({
              controller: this.controller,
              placeHolder: (this.chatUserInfo.conversationName ?? '').length > 15 ?
                this.chatUserInfo.conversationName?.substring(0, 15) + '...' : this.chatUserInfo.conversationName,
              replyMsg: this.replyMsg,
              chatInfo: this.chatUserInfo,
              revokeMultiLineContent: this.revokeMultiLineContent,
              onRestoreMultiLineContent: (title: string, body: string, bodyNodes: RichInputTransferNode[]) => {
                // 恢复撤回重编辑的多行内容
                this.multiLineTitle = title
                this.multiLineBody = body
                this.multiLineBodyNodes = bodyNodes
                // 如果当前已经在多行模式，需要直接更新 MultiLineInputView 的内容
                if (this.inputStyle === InputStyleType.Multiline && this.multiLineInputViewInstance) {
                  this.multiLineInputViewInstance.setContent(title, body, bodyNodes)
                }
              },
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
                this.showOperationView = false
                this.hideAIHelperPanel()
                let context = getContext(this) as common.UIAbilityContext
                this.getUIContext().getFocusController().clearFocus()
                PermissionsUtils.reqPermissionsFromUser(['ohos.permission.MICROPHONE'], context).then((result) => {
                  if (result.grantStatus == true) {
                    if (this.inputStyle == InputStyleType.Record) {
                      this.pendingExpandPanelAfterKeyboardHide = false
                      this.expandHeight = 0
                      this.inputStyle = InputStyleType.None;
                      this.computeScrollHeight()
                    } else {
                      this.pendingExpandPanelAfterKeyboardHide = this.keyboardHeight > 10
                      this.inputStyle = InputStyleType.Record
                      this.expandHeight = ChatConst.messageInputAreaHeight
                      this.computeScrollHeight()
                    }
                  } else {
                    NECommonUtils.showToast($r('app.string.chat_permission_deny_tips'))
                  }
                })

              },
              onDidClickEmoji: () => {
                this.showOperationView = false
                this.hideAIHelperPanel()
                if (this.inputStyle == InputStyleType.Emoji) {
                  this.pendingExpandPanelAfterKeyboardHide = false
                  this.expandHeight = 0
                  this.inputStyle = InputStyleType.None;
                  this.computeScrollHeight()
                } else {
                  this.pendingExpandPanelAfterKeyboardHide = this.keyboardHeight > 10
                  this.inputStyle = InputStyleType.Emoji
                  this.expandHeight = ChatConst.messageInputAreaHeight
                  this.computeScrollHeight()
                }
              },
              onDidClickMore: () => {
                this.showOperationView = false
                this.hideAIHelperPanel()
                if (this.inputStyle == InputStyleType.More) {
                  this.pendingExpandPanelAfterKeyboardHide = false
                  this.expandHeight = 0
                  this.inputStyle = InputStyleType.None;
                  this.computeScrollHeight()
                } else {
                  this.pendingExpandPanelAfterKeyboardHide = this.keyboardHeight > 10
                  this.inputStyle = InputStyleType.More
                  this.expandHeight = ChatConst.messageInputAreaHeight
                  this.computeScrollHeight()
                }
              },
              onDidClickAIHelper: () => {
                this.showOperationView = false
                if (this.inputStyle == InputStyleType.AiHelper) {
                  this.bottomHeight = this.getSingleLineInputHeight()
                  this.expandHeight = 0
                  this.inputStyle = InputStyleType.None;
                  this.computeScrollHeight()
                } else {
                  inputMethod.getController().stopInputSession()
                  this.inputStyle = InputStyleType.AiHelper
                  this.bottomHeight = this.getAIHelperInputHeight()
                  this.expandHeight = this.aiHelperPanelHeight
                  this.computeScrollHeight()
                  this.loadAIHelperData(false)
                }
              },
              onSendTextMessage: () => {
                this.showOperationView = false
                let text = this.getMessageText().trimEnd()
                if (text.length <= 0) {
                  NECommonUtils.showToast($r('app.string.null_message_not_support'))
                  return
                }
                this.chatViewModel.sendTextMessage(text, this.replyMsg, this.aitManager.aitModel,
                  this.getAitPushList(), this.getFirstAitAIUserAccount())
                this.clearInput(true)
                this.aitManager.cleanAit()
                this.builderSpans.splice(0, this.builderSpans.length)
                this.resetAITranslateView()
              },
              onSendMultiLineMessage: (title: string, body: string) => {
                this.showOperationView = false
                this.chatViewModel.sendMultiLineMessage(title, body, this.replyMsg, this.aitManager.aitModel,
                  this.getAitPushList(), this.getFirstAitAIUserAccount())
                this.clearInput(true)
                this.aitManager.cleanAit()
                this.builderSpans.splice(0, this.builderSpans.length)
                this.resetAITranslateView()
                // 发送后滚动到最新消息
                this.scrollToNewMessage()
              },
              onInputTextChange: (hasText: boolean) => {
                this.syncTranslateInputText()
                // 通知 ViewModel 输入状态变化（用于"正在输入"功能）
                this.chatViewModel.sendInputNotification(hasText)
              },
              onMultilineModeChange: (
                isMultiline: boolean,
                transferTitle?: string,
                transferBody?: string,
                transferBodyNodes?: RichInputTransferNode[]
              ) => {
                this.showOperationView = false
                this.hideAIHelperPanel()
                if (isMultiline) {
                  this.inputStyle = InputStyleType.Multiline
                  // 多行模式：隐藏单行输入框，使用 expandHeight 显示多行面板
                  this.bottomHeight = 0
                  // 有回复时高度增加 36（32px 回复预览 + 4px margin）
                  this.expandHeight = this.replyMsg ? 186 : 150
                  this.computeScrollHeight()
                  // 单行 → 多行转换：
                  // - 单行第一行 → 多行标题
                  // - 单行第二行起 → 多行正文
                  this.multiLineTitle = transferTitle ?? ''
                  this.multiLineBody = transferBody ?? ''
                  this.multiLineBodyNodes = transferBodyNodes ?? []
                  this.scrollToNewMessage()
                } else {
                  this.inputStyle = InputStyleType.None
                  this.bottomHeight = this.getSingleLineInputHeight()
                  this.expandHeight = 0
                  this.computeScrollHeight()
                  this.restoreSingleLineTransferNodes(transferTitle ?? '', transferBody ?? '', transferBodyNodes ?? [])
                  this.multiLineBodyNodes = []
                }
              },
              conversationName: this.chatUserInfo.conversationName ?? '',
              aitManager: this.aitManager,
              builderSpans: this.builderSpans,
              showAitAll: false,
              showAIUserAit: this.canAitAIUser(),
              showTeamMemberAit: false,
              aiUsers: this.getAIChatUsers(),
              inputStyle: this.inputStyle
            }).alignRules({
              left: { anchor: "chat_input", align: HorizontalAlign.Start },
              right: { anchor: "chat_input", align: HorizontalAlign.End },
              bottom: { anchor: "chat_input", align: VerticalAlign.Bottom },
            }).height(this.bottomHeight)
              .backgroundColor(this.inputStyle === InputStyleType.AiHelper ? $r('app.color.ai_chat_helper_background_main') : $r('app.color.chat_input_background'))
              .visibility(this.showMultiSelect ? Visibility.None : Visibility.Visible)
          }

          // 多选操作栏
          if (this.showMultiSelect) {
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
              }).backgroundColor($r('app.color.chat_input_background'))
          }

          Column() {
            if (this.inputStyle === InputStyleType.Record) {
              NEAudioRecordView({
                shouldStop: this.shouldStopRecord,
                onRecordAudio: (filepath, duration) => {
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
                            Logger.info('ChatKitUI', "ChooseLocation", "Succeeded in choosing location.");
                          })
                          .catch((err: BusinessError) => {
                            Logger.error('ChatKitUI', "ChooseLocation",
                              `Failed to choose location, code: ${err.code}, message: ${err.message}`);
                          });
                      } else {
                        NECommonUtils.showToast($r('app.string.chat_permission_deny_tips'))
                      }
                    })

                  } else if (data.type == NEChatMoreOperationType.Call) {
                    promptAction.showActionMenu({
                      title: $r('app.string.chat_kit_select_call_type'),
                      buttons: [
                        {
                          text: $r('app.string.chat_kit_audio_call_type'),
                          color: '#000000'
                        },
                        {
                          text: $r('app.string.chat_kit_video_call_type'),
                          color: '#000000'
                        },
                      ]
                    })
                      .then((data: promptAction.ActionMenuSuccessResponse) => {
                        Logger.info('ChatKitUI', 'showActionMenu success, click button: ' + data.index);
                        let callType: number = 1; // 默认音频通话
                        // 根据选中索引，切换通话类型
                        switch (data.index) {
                          case 0: // 选中【音频通话】
                            callType = 1;
                            break;
                          case 1: // 选中【视频通话】
                            callType = 2;
                            break;
                          default: // 选中取消/空白处，直接返回不执行后续逻辑
                            return;
                        }

                        const targetId: string = this.chatUserInfo.targetId;
                        // 检查是否仅允许好友通话
                        if (IMKitConfigCenter.enableOnlyFriendCall &&
                            !NEFriendUserCache.getInstance().hasFriendRelation(targetId)) {
                          // 非好友，弹出提示框
                          NECommonUtils.showToast($r('app.string.chat_not_friend_call_tip'))
                          return;
                        }
                        ChatKitUIClient.getInstance().call(targetId, callType)
                      })
                      .catch((err: Error) => {
                        Logger.error('ChatKitUI', 'showActionMenu error: ' + err);
                      })
                  } else if (data.type == NEChatMoreOperationType.Translate) {
                    inputMethod.getController().stopInputSession()
                    this.showAITranslateView()
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
                  if (emoji.type === NIMEmoticonType.file) {
                    this.controller.addImageSpan($rawfile(`emoji/${emoji.file}`), { imageStyle: { size: [16, 16] } })
                  } else if (emoji.type === NIMEmoticonType.delete) {
                    let currentLength = this.getInputContentLength()
                    if (currentLength > 0) {
                      this.controller.deleteSpans({ start: currentLength - 1, end: currentLength })
                    }
                  }
                },
                onEmojiSendMessage: () => {
                  let text = this.getMessageText().trimEnd()
                  if (text.length <= 0) {
                    NECommonUtils.showToast($r('app.string.null_message_not_support'))
                    return
                  }
                  this.chatViewModel.sendTextMessage(text, this.replyMsg, this.aitManager.aitModel,
                    this.getAitPushList(), this.getFirstAitAIUserAccount())
                  this.clearInput(true)
                  this.aitManager.cleanAit()
                  this.builderSpans.splice(0, this.builderSpans.length)
                  this.resetAITranslateView()
                }
              }).padding({ top: 0 })
                .width('100%')
                .height(170)
                .alignRules({
                  left: { anchor: "__container__", align: HorizontalAlign.Start },
                  right: { anchor: "__container__", align: HorizontalAlign.End },
                  top: { anchor: "__container__", align: VerticalAlign.Top }
                })
            } else if (this.inputStyle === InputStyleType.AiHelper) {
              // AI 助聊面板
              AIHelperView({
                isLoading: this.aiHelperLoading,
                isError: this.aiHelperError,
                helperItems: this.aiHelperItems,
                clickListener: {
                  onShow: () => {
                    this.loadAIHelperData(false)
                  },
                  onRefreshClick: () => {
                    this.loadAIHelperData(true)
                  },
                  onTryAgainClick: () => {
                    this.loadAIHelperData(true)
                  },
                  onItemClick: (item: AIHelperItem) => {
                    this.chatViewModel.sendTextMessage(item.content)
                  },
                  onItemEditClick: (item: AIHelperItem) => {
                    this.controller.deleteSpans()
                    this.controller.addTextSpan(item.content, { offset: 0 })
                    this.hideAIHelperPanel()
                    inputMethod.getController().showTextInput()
                  }
                }
              })
                .width('100%')
                .height(this.expandHeight)
                .linearGradient({
                  direction: GradientDirection.Bottom,
                  colors: [
                    [$r('app.color.ai_chat_helper_background_main'), 0.0],
                    [$r('app.color.ai_chat_helper_background_sub'), 1.0]
                  ]
                })
                .alignRules({
                  left: { anchor: "__container__", align: HorizontalAlign.Start },
                  right: { anchor: "__container__", align: HorizontalAlign.End },
                  top: { anchor: "__container__", align: VerticalAlign.Top }
                })
            } else if (this.inputStyle === InputStyleType.Multiline) {
              // 多行输入模式面板：使用 visibility 控制显隐，避免组件销毁导致内容丢失
              Column() {
                MultiLineInputView({
                teamId: undefined,
                team: undefined,
                showAitAll: false,
                showAIUserAit: this.canAitAIUser(),
                showTeamMemberAit: false,
                aiUsers: this.getAIChatUsers(),
                conversationName: this.chatUserInfo.conversationName ?? '',
                initialTitle: this.multiLineTitle,
                initialBody: this.multiLineBody,
                initialBodyNodes: this.multiLineBodyNodes,
                aitManager: this.aitManager,
                replyMsg: this.replyMsg,
                chatInfo: this.chatUserInfo,
                onInputTextChange: (hasText: boolean) => {
                  this.syncTranslateInputText()
                  // 通知 ViewModel 输入状态变化（用于"正在输入"功能）
                  this.chatViewModel.sendInputNotification(hasText)
                },
                onComponentReady: (instance: MultiLineInputView) => {
                  // 保存组件实例引用
                  this.multiLineInputViewInstance = instance
                },
                onCloseReply: () => {
                  this.replyMsg = undefined
                  // 恢复高度
                  this.expandHeight = 150
                  this.computeScrollHeight()
                },
                onSendMultiLineMessage: (title: string, body: string) => {
                  // 发送消息
                  if (title.length > 0) {
                    this.chatViewModel.sendMultiLineMessage(title, body, this.replyMsg, this.aitManager.aitModel,
                      this.getAitPushList(), this.getFirstAitAIUserAccount())
                  } else {
                    this.chatViewModel.sendTextMessage(body, this.replyMsg, this.aitManager.aitModel,
                      this.getAitPushList(), this.getFirstAitAIUserAccount())
                  }
                  this.aitManager.cleanAit()
                  // 清空缓存
                  this.multiLineTitle = ''
                  this.multiLineBody = ''
                  this.multiLineBodyNodes = []
                  this.resetAITranslateView()
                  // 清除回复消息（但保持多行模式和键盘状态）
                  if (this.replyMsg) {
                    this.replyMsg = undefined
                    // 恢复到无回复时的高度（保持多行模式和键盘）
                    this.expandHeight = 150
                    this.computeScrollHeight()
                  }
                  this.scrollToNewMessage()
                },
                onCollapseClick: (title: string, bodyText: string, bodyNodes: RichInputTransferNode[]) => {
                  // 收起按钮点击
                  this.multiLineTitle = ''
                  this.multiLineBody = ''
                  this.multiLineBodyNodes = []
                  // 切换回单行模式
                  this.inputStyle = InputStyleType.None
                  this.bottomHeight = this.getSingleLineInputHeight()
                  this.expandHeight = 0
                  this.computeScrollHeight()
                  this.restoreSingleLineTransferNodes(title, bodyText, bodyNodes)
                }
              })
              }
              .width('100%')
              .visibility(this.showMultiSelect ? Visibility.None : Visibility.Visible)
            }
          }
          .height(this.getInputExpandContainerHeight())
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
              operationItems: this.operationMenuItems,
              didClickItem: (item: MessageOperationItem) => {
                this.showOperationView = false
                if (this.operationMsg == undefined) {
                  return;
                }
                if (item.operationType == MessageOperationType.Copy) {
                  // 获取要复制的文本内容
                  let copyText = this.getOperationText()
                  const pasteboardData =
                    pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, copyText)
                  pasteboard.getSystemPasteboard().setDataSync(pasteboardData)
                  NECommonUtils.showToast($r('app.string.chat_message_copy_success_tips'))
                } else if (item.operationType == MessageOperationType.Delete) {
                  this.showDialogToDelete([this.operationMsg])
                } else if (item.operationType == MessageOperationType.Undo) {
                  this.showDialogToRevoke(this.operationMsg)
                } else if (item.operationType == MessageOperationType.Forward) {
                  // 转发
                  // Keep forward content consistent during selection
                  const useTranslatedText = this.translationOperationMode
                  const translatedText = useTranslatedText ?
                    MessageTranslationService.instance.getTranslatedDisplayText(this.operationMsg) : ''
                  this.forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
                    if (useTranslatedText) {
                      if (translatedText.length === 0) {
                        return
                      }
                      this.forwardMessages = [ChatRepo.createTextMessage(translatedText)]
                    } else if (this.operationMsg?.message) {
                      this.forwardMessages = [this.operationMsg.message]
                    } else {
                      return
                    }
                    if (this.operationMsg?.message) {
                      this.forwardConversations = selectedList
                      this.currentConversationName = this.chatUserInfo.getConversationName()
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
                  this.hideAIHelperPanel()
                  this.chatViewModel.clearSelectMessage()
                  this.chatViewModel.addSelectMessage(this.operationMsg)
                  this.showMultiSelect = true
                  this.bottomHeight = 100
                } else if (item.operationType == MessageOperationType.Reply) {
                  this.loadReplyInfo(this.operationMsg)
                } else if (item.operationType == MessageOperationType.VoicePlayMode) {
                  // 切换语音播放模式
                  const newMode = !IMKitConfigCenter.enableEarphoneMode
                  IMKitConfigCenter.enableEarphoneMode = newMode
                  AppStorage.setOrCreate(CommonConstants.KEY_SETTING_EARPIECE_MODE, newMode)
                  // 播放中立刻切换输出设备
                  AudioPlayerManager.instance.switchAudioOutputDevice(newMode)
                  // 显示 Toast 提示
                  if (newMode) {
                    NECommonUtils.showToast($r('app.string.chat_message_audio_earphone_tip'))
                  } else {
                    NECommonUtils.showToast($r('app.string.chat_message_audio_speaker_tip'))
                  }
                } else if (item.operationType == MessageOperationType.VoiceToText) {
                  // 语音转文字
                  this.chatViewModel.voiceToText(this.operationMsg)
                } else if (item.operationType == MessageOperationType.Translate) {
                  MessageTranslationService.instance.translate(this.operationMsg)
                } else if (item.operationType == MessageOperationType.HideTranslation) {
                  MessageTranslationService.instance.hideTranslation(this.operationMsg)
                } else if (item.operationType == MessageOperationType.AISearch) {
                  const keyword = this.getAISearchOperationText().trim()
                  if (keyword.length > 0) {
                    if (ChatKitClient.connectBroken()) {
                      NECommonUtils.showToast($r('app.string.chat_ai_search_network_error'))
                      this.translationOperationMode = false
                      this.operationMenuItems = undefined
                      this.selectedOperationText = ''
                      this.closeAISearchSelection()
                      return
                    }
                    this.aiSearchKeyword = keyword
                    this.showAISearchPanel = true
                  }
                }
                this.translationOperationMode = false
                this.operationMenuItems = undefined
                this.selectedOperationText = ''
                this.closeAISearchSelection()
              }
            })
              .position({ x: this.operationRect.x, y: this.operationRect.y })
              .borderRadius(8)
              .shadow(ShadowStyle.OUTER_DEFAULT_MD)

          }

          }
      .margin({ bottom: this.bottomMargin })
      .expandSafeArea([SafeAreaType.KEYBOARD])
      .layoutWeight(1)
      .width('100%')
      .height('100%')
        }
        .width('100%')
        .height('100%')

        if (this.showAISearchPanel) {
          Column()
            .width('100%')
            .height(220)
            .backgroundColor(Color.White)
            .position({ x: 0, y: '100%' })
            .offset({ y: -1 })
            .zIndex(99)

          AISearchPanel({
            keyword: this.aiSearchKeyword,
            onClose: () => {
              this.showAISearchPanel = false
              this.aiSearchKeyword = ''
            }
          })
            .position({ x: 0, y: 0 })
            .zIndex(100)
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      let param = this.pathStack.getParamByName("ChatP2PPage") as string[];
      if (param.length > 0) {
        this.conversationId = param[0];
        this.loadChatData();
        // Bot 不支持音视频通话，不显示 Call 按钮
        const targetId = this.chatUserInfo.targetId
        if (targetId) {
          if (NEAIUserCache.getAIUser(targetId) || UserAIBotManager.isDeletedUserAIBot(targetId)) {
            this.operationMoreDataList = setupMoreOperationData(true, true)
          } else {
            UserAIBotManager.getUserAIBot({ accid: targetId }).then((bot) => {
              if (bot) {
                this.operationMoreDataList = setupMoreOperationData(true, true)
              }
            })
          }
        }
      } else {
        this.pathStack.removeByName("ChatP2PPage")
      }
    })
    .onShown(() => {
      // 页面显示时设置为可见
      this.chatViewModel.isPageVisible = true
      // 重置录音停止信号
      this.shouldStopRecord = false
      if (!this.firstLoadData) {
        // 首屏滚动位置未稳定时不发回执，等列表完成首屏定位后再按可见区处理。
        const allMessages = this.chatUserInfo.msgList.getMessageList()
        const visibleMessages = allMessages.slice(this.listScrollStartPosition, this.listScrollEndPosition + 1)
        this.chatViewModel.toHandleReceiptMessage(visibleMessages)
      }
    })
    .onHidden(() => {
      // 页面隐藏时设置为不可见
      this.chatViewModel.isPageVisible = false
      AudioPlayerManager.instance.stopPlayAll()
      // 标记录音被取消，endRecord 时会检查此状态决定是否发送
      AudioRecordManager.instance.setCancelled(true)
      // 通知 NEAudioRecordView 停止录音（触发 View 的 UI 清理）
      this.shouldStopRecord = true
    })
  }

  loadReplyInfo(msg: NIMMessageInfo) {
    this.replyMsg = msg
    this.clearPendingReplyTasks()
    // 多行模式下调整 expandHeight 并弹出键盘
    if (this.inputStyle === InputStyleType.Multiline) {
      this.expandHeight = 186
      this.computeScrollHeight()
      this.scheduleMultiLineFocus()
      return
    }
    this.bottomHeight = this.inputStyle === InputStyleType.AiHelper ? this.getAIHelperInputHeight() :
      this.getSingleLineInputHeight()
    this.computeScrollHeight()
    this.scheduleSingleLineFocus()
  }

  private resetMultiLineDraft() {
    this.clearPendingReplyTasks()
    this.multiLineInputViewInstance?.clearContent()
    this.multiLineTitle = ''
    this.multiLineBody = ''
    this.multiLineBodyNodes = []
    this.revokeMultiLineContent = ''
  }

  private exitMultiLineEditMode() {
    this.clearPendingReplyTasks()
    if (this.inputStyle === InputStyleType.Multiline) {
      this.inputStyle = InputStyleType.None
      this.expandHeight = 0
      this.bottomHeight = this.getSingleLineInputHeight()
      this.computeScrollHeight()
    }
  }

  private clearPendingReplyTasks() {
    if (this.singleLineFocusTask >= 0) {
      clearTimeout(this.singleLineFocusTask)
      this.singleLineFocusTask = -1
    }
    if (this.multiLineFocusTask >= 0) {
      clearTimeout(this.multiLineFocusTask)
      this.multiLineFocusTask = -1
    }
  }

  private scheduleSingleLineFocus() {
    if (this.singleLineFocusTask >= 0) {
      clearTimeout(this.singleLineFocusTask)
    }
    this.singleLineFocusTask = setTimeout(() => {
      this.singleLineFocusTask = -1
      if (this.inputStyle === InputStyleType.Multiline || this.hideInput || this.showMultiSelect || this.bottomHeight <= 0) {
        return
      }
      try {
        this.getUIContext().getFocusController().requestFocus("chat_edit_input")
      } catch (e) {
        Logger.warn('ChatKitUI', `ChatP2PPage scheduleSingleLineFocus failed: ${e}`)
      }
    }, 100)
  }

  private scheduleMultiLineFocus() {
    if (this.multiLineFocusTask >= 0) {
      clearTimeout(this.multiLineFocusTask)
    }
    this.multiLineFocusTask = setTimeout(() => {
      this.multiLineFocusTask = -1
      if (this.inputStyle !== InputStyleType.Multiline || this.showMultiSelect || !this.multiLineInputViewInstance) {
        return
      }
      try {
        this.getUIContext().getFocusController().requestFocus("multiline_body_input")
      } catch (e) {
        Logger.warn('ChatKitUI', `ChatP2PPage scheduleMultiLineFocus failed: ${e}`)
      }
    }, 100)
  }

  /**
   * 加载 AI 助聊回复灵感数据
   * 素材：最近 5 条 TEXT 成功消息 + 对方最后一条消息
   */
  private async loadAIHelperData(forceRefresh: boolean = true): Promise<void> {
    const context = buildAIHelperContext(this.chatViewModel.chatInfo?.msgList.getMessageList() ?? [])
    if (!forceRefresh && this.aiHelperItems.length > 0 && !this.aiHelperError &&
      context.latestMessageClientId === this.aiHelperLastMessageClientId) {
      return
    }
    this.aiHelperLoading = true
    this.aiHelperError = false
    try {
      const chatAccountId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(
        this.chatViewModel.conversationId)
      const selfAccountId = ChatKitClient.getLoginUserId()
      const body = AIHelperRepo.buildRequestJSON(context.history, context.receiverLastMessage, chatAccountId,
        selfAccountId)
      const items = await AIHelperRepo.requestAIHelper(body)
      if (items.length > 0) {
        this.aiHelperItems = items
        this.aiHelperLastMessageClientId = context.latestMessageClientId
      } else {
        this.aiHelperError = true
      }
    } catch (_err) {
      this.aiHelperError = true
    }
    this.aiHelperLoading = false
  }

  clearInput(clearInput?: boolean) {
    if (clearInput) {
      this.controller.deleteSpans()
    }
    this.replyMsg = undefined
    this.bottomHeight = this.inputStyle === InputStyleType.AiHelper ? this.getAIHelperInputHeight() :
      this.getSingleLineInputHeight()
    this.computeScrollHeight()
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
        this.currentConversationName = this.chatUserInfo.getConversationName()
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
        this.currentConversationName = this.chatUserInfo.getConversationName()
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
      if (onlyShow &&
        (msg.getMessageType() == V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT || isMultiLineMessage(msg.message))) {
        this.textMessageDetailDialog = new CustomDialogController({
          builder: TextMessageDetailDialog({
            message: msg,
            onClose: () => {
              this.closeTextMessageDetailDialog()
            }
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
        this.clearPendingAIHelperMediaRestore()
        downLoadAndOpenFile(msg, getContext(this), this.chatUserInfo)
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
        this.showVideoDetail(msg)
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
        this.clearPendingAIHelperMediaRestore()
        this.showLocationDetail(msg)
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
        this.clearPendingAIHelperMediaRestore()
        if (onlyShow) {
          this.playAudioMessage(msg)
        }
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
        this.clearPendingAIHelperMediaRestore()
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
      } else {
        this.clearPendingAIHelperMediaRestore()
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
            // 退出多选模式后，如果是多行输入模式，恢复 bottomHeight
            if (this.inputStyle === InputStyleType.Multiline) {
              this.bottomHeight = 0
            }
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
            Logger.info('ChatKitUI', 'Callback when the first button is clicked')
          }
        },
        secondaryButton: {
          enabled: true,
          defaultFocus: true,
          style: DialogButtonStyle.HIGHLIGHT,
          value: $r('app.string.chat_msg_dialog_sure'),
          action: () => {
            Logger.info('ChatKitUI', 'Callback when the second button is clicked')
            this.chatViewModel.revokeMessage(message)
          }
        }
      }
    )
  }

  goToSettingPage(pathStack: NavPathStack) {
    this.hideAIHelperPanel()
    if (this.showMultiSelect) {
      this.chatViewModel.clearSelectMessage()
      this.showMultiSelect = false
      if (this.inputStyle === InputStyleType.Multiline) {
        this.bottomHeight = 0
      }
    } else {
      pathStack.pushPath({
        name: 'UserSettingPage',
        param: this.chatViewModel.conversationId
      })
    }
    this.controller.stopEditing()
  }

  onPageHide(): void {
    this.chatViewModel.clearUnreadCount()
    this.hideAIHelperPanel()
    this.resetAIHelperCache()
  }

  /**
   * 计算此时的 this.chatTeamInfo.isReceiveMsg 中有多少应该被记录成 newMessageCount 增加的
   * 满足以下条件的才允许添加：
   * 1. conversationId 为当前会话
   * 2. 发送者不是自己
   * @returns
   */
  private addNewMessageCount(): void {
    for (const message of this.chatUserInfo.isReceiveMsg.messages) {
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
    for (const message of this.chatUserInfo.isReceiveMsg.messages) {
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
    MessageTranslationService.instance.removeTranslationFinishedListener(this.translationFinishedListener)
    this.chatViewModel.clearUnreadCount()
    this.chatViewModel.onOperateMessageInvalid = undefined
    this.chatViewModel.onDestroy()
    AudioPlayerManager.instance.stopPlayAll()
    this.resetAIHelperCache()
    
    // 清空多行输入框状态和内容（退出聊天页面时）
    this.multiLineTitle = ''
    this.multiLineBody = ''
    this.expandHeight = 0
    this.inputStyle = InputStyleType.None
  }
}

// 跳转页面入口函数
@Builder
export function ChatP2PPageBuilder() {
  ChatP2PPage()
}
