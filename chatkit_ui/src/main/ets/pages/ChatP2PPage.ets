/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatUserInfo } from '../model/ChatUserInfo';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { MessageComponent } from '../view/MessageComponent';
import { ChatP2PViewModel } from '../viewmodel/ChatP2PViewModel';
import { NEChatEmojiView } from '../view/NEChatEmojiView';
import { NEEmojiManager, NEEmojiParseResult, NIMEmoticonType } from '../manager/NEEmojiManager';
import { NEChatMoreOperation } from '../view/ChatMoreOperationLayout';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { NEAudioRecordView } from '../view/NEAudioRecordView';
import { InputStyleType, NEChatInputView } from '../view/ChatInputView';
import {
  DoubleAlertDialog,
  ImagesIndexModel,
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
import { ImageViewDialog } from '@nimkit/common/src/main/ets/ImageViewDialog/ImageViewDialog';
import {
  V2NIMMessage,
  V2NIMMessageAudioAttachment,
  V2NIMMessageLocationAttachment,
  V2NIMMessageSendingState,
  V2NIMMessageType
} from '@nimsdk/base';
import { ChatConst } from '../constants/ChatConst';
import { ChatKitClient } from '@nimkit/chatkit/src/main/ets/ChatKitClient';
import { AudioPlayerManager } from '../manager/AudioPlayerManager';
import {
  conversationSelectLimitCount,
  ConversationSelectParam,
  CustomMessageUtils,
  ErrorUtils,
  MergedMessageAttachment,
  mergedMessageCustomType,
  mergedMessageLimitCount,
  mergedMessageMaxDepth,
  singleMessageLimitCount
} from '@nimkit/chatkit';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import { ForwardMessageDialog } from '../view/ForwardMessageDialog';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import {
  downLoadAndOpenFile,
  getMessageImageUrl,
  getMessageImageUrls,
  getMessageVideoRatio,
  getMessageVideoUrl,
  parseMessageText
} from '../common/MessageHelper';
import { sceneMap } from '@kit.MapKit';
import { computeOperateViewHeight, computeOperateViewWidth, setupMoreOperationData } from '../common/ChatUtils';
import { ChatMultiSelectView } from '../view/ChatMultiSelectView';
import { TextMessageDetailDialog } from '../view/TextMessageDetailDialog';

@ComponentV2
export struct ChatP2PPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local chatUserInfo: ChatUserInfo = new ChatUserInfo();
  chatViewModel: ChatP2PViewModel = new ChatP2PViewModel();
  conversationId: string = '';
  // 底部扩展区域高度，默认为0
  @Local expandHeight: number = 0;
  @Local inputStyle: InputStyleType = InputStyleType.None;
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
  @Local replyMsg: NIMMessageInfo | undefined = undefined
  @Local operationRect: NERectData = new NERectData()
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
      imagesIndexModel: this.imagesIndexModel
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Center,
    backgroundColor: Color.Black,
    backgroundBlurStyle: BlurStyle.NONE,
    height: '100%',
    width: '100%',
    customStyle: true
  })
  @Local videoFileUrl?: string
  @Local videoRatio?: number
  videoViewerDialog: CustomDialogController = new CustomDialogController({
    builder: VideoViewerDialog({
      videoUrl: this.videoFileUrl,
      videoRatio: this.videoRatio
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Center,
    backgroundColor: Color.Black,
    backgroundBlurStyle: BlurStyle.NONE,
    height: '100%',
    width: '100%',
    customStyle: true
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
        }
      }
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 250,
    width: 276,
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
  forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
    if (this.operationMsg?.message) {
      this.forwardMessages = [this.operationMsg.message]
      this.forwardConversations = selectedList
      this.currentConversationName = this.chatUserInfo.getConversationName()
      this.forwardMessageDialog.open()
    }
  }

  @Monitor("chatUserInfo.isReceiveMsg")
  onReceiveMsg() {
    if (this.firstLoadData || this.chatUserInfo.isReceiveMsg) {
      this.listScroller.scrollEdge(Edge.Bottom)
      this.chatUserInfo.setReceiveMsg(false)
      this.firstLoadData = false;
    }
  }

  @Monitor("chatUserInfo.scrollIndex")
  onScrollIndex() {
    if (this.chatUserInfo.scrollIndex > -1) {
      let height = DeviceUtils.windowPXHeight / 2
      this.toScroll = true
      this.listScroller.scrollToIndex(this.chatUserInfo.scrollIndex, false, undefined, {
        'extraOffset': new LengthMetrics(-height, 0)
      })
      this.chatViewModel.setAnchorMessage(undefined)
      this.chatUserInfo.setScrollIndex(-1)
    }
  }

  @Monitor("chatViewModel.needScrollToBottom")
  onNeedScrollToBottom() {
    if (this.chatViewModel.needScrollToBottom &&
      this.listScrollEndPosition >= this.chatUserInfo.msgList.totalCount() - 2) {
      this.listScroller.scrollEdge(Edge.Bottom)
      this.chatViewModel.needScrollToBottom = false;
    }
  }

  @Monitor("chatViewModel.anchorMsg")
  onAnchorMsg() {
    if (this.chatViewModel.anchorMsg) {
      if (this.chatUserInfo.msgMap.has(this.chatViewModel.anchorMsg.getMessageClientId())) {
        let position = this.chatUserInfo.searchPosition(this.chatViewModel.anchorMsg.getMessageClientId())
        this.toScroll = true
        this.listScroller.scrollToIndex(position)
        this.chatViewModel.setAnchorMessage(undefined)
      } else {
        this.chatViewModel.loadAnchorMsg(this.chatViewModel.anchorMsg)
      }
    }

  }

  @Monitor("chatViewModel.selectMsgCount")
  onSelectMsg() {
    this.multiSelectCount = this.chatViewModel.getSelectMessageSize()
  }

  @Monitor("expandHeight")
  onExpandInputView() {
    if (this.expandHeight > 10) {
      // 如果是定位消息状态，收到键盘展开重新切换最新消息
      if (this.chatViewModel.hasNew) {
        this.chatViewModel.reloadMessageList()
      } else {
        this.listScroller.scrollEdge(Edge.Bottom)
      }
    }
  }

  aboutToAppear(): void {
    NEEmojiManager.instance.setup();
    DeviceUtils.rootDirPath = getContext(this).filesDir
    this.operationMoreDataList = setupMoreOperationData()
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
        this.listScroller.scrollEdge(Edge.Bottom)
      }
    }
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
    let text = '';
    let results = this.controller?.getSpans();
    results?.forEach((item) => {
      if (typeof (item as RichEditorImageSpanResult)['imageStyle'] != 'undefined') {
        let resourcePath = (item as RichEditorImageSpanResult).valueResourceStr;
        if (resourcePath != null && resourcePath.toString().length > 0) {
          let path = resourcePath.toString();
          let splits = path.split("/")
          let fileName = splits[splits.length - 1];
          let emoji = NEEmojiManager.instance.getEmojiByName(String(fileName));
          if (emoji?.tag != null) {
            text += emoji.tag;
          }
        }
      } else {
        text += (item as RichEditorTextSpanResult).value;
      }
    })
    return text
  }

  loadChatData() {
    this.chatUserInfo.setConversationId(this.conversationId)
    this.chatViewModel.init(this.conversationId, this.chatUserInfo);
    this.chatViewModel.loadData();
  }

  async showImageDetail(msg?: NIMMessageInfo, onlyMsg?: boolean) {
    try {
      const imageModel =
        onlyMsg ? await getMessageImageUrl(msg, this.chatUserInfo) : await getMessageImageUrls(msg, this.chatUserInfo)
      this.imagesIndexModel = imageModel
      this.imageViewerDialog.open()
    } catch (err) {
      console.error(err)
    }
  }

  showVideoDetail(msg: NIMMessageInfo) {
    AudioPlayerManager.instance.stopPlayAll()
    this.videoFileUrl = getMessageVideoUrl(msg, this.chatUserInfo)
    if (this.videoFileUrl == undefined) {
      NECommonUtils.showToast($r('app.string.chat_msg_download_tips'))
      return
    }
    this.videoRatio = getMessageVideoRatio(msg)
    if (this.videoFileUrl) {
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
      console.info("netease QueryLocation", "Succeeded in querying location.");
    }).catch((err: BusinessError) => {
      console.error("netease QueryLocation", `Failed to query Location, code: ${err.code}, message: ${err.message}`);
    });
  }

  @Builder
  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: this.chatUserInfo.conversationName,
        rightButtonIcon: this.showMultiSelect ? undefined : $r('app.media.ic_public_more_dot'),
        rightButtonTitle: this.showMultiSelect ? $r('app.string.chat_msg_dialog_cancel') : undefined,
        rightButtonAction: () => {
          this.goToSettingPage(this.pathStack)
        },
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })
      RelativeContainer() {
        List({ scroller: this.listScroller }) {
          LazyForEach(this.chatUserInfo.msgList, (msg: NIMMessageInfo) => {
            ListItem() {
              MessageComponent({
                message: msg,
                chatInfo: this.chatUserInfo,
                showSelect: this.showMultiSelect,
                onMessageClick: {
                  onAvatarClick: ((msg: NIMMessageInfo | undefined) => {
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
                  }),
                  onItemLongClick: ((event: GestureEvent, msg: NIMMessageInfo | undefined) => {
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
                  }),
                  onItemClick: (_event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                    if (this.showMultiSelect) {
                      if (msg) {
                        if (!msg?.isSelectedMsg && !msg.isRevokeMsg) {
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
                      this.clearInput(true)
                      if (msg.isReplyMsg && msg.replyMsg) {
                        this.loadReplyInfo(msg.replyMsg)
                      }
                      parseMessageText(msg.revokeInfo?.revokeMsgText)?.forEach((item: NEEmojiParseResult) => {
                        if (item.text) {
                          this.controller.addTextSpan(item.text)
                        } else if (item.emoji) {
                          this.controller.addImageSpan($rawfile(`emoji/${item.emoji.file}`),
                            {
                              imageStyle: { size: [16, 16] }
                            })
                        }
                      })
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
                  onAvatarLongPress: () => {

                  },
                  onReadReceiptClick: (_event: ClickEvent) => {

                  }
                },
              })
            }
          }, (item: NIMMessageInfo) => item.message.messageClientId)
        }
        .id("chatPageListView")
        .cachedCount(20)
        .maintainVisibleContentPosition(true)
        .padding({ bottom: 20 })
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
        })
        .onScrollStop(() => {
          console.debug('netease to scroll stop:', this.toScroll)
          if (this.toScroll) {
            this.toScroll = false
          }
        })
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "__container__", align: VerticalAlign.Top },
        })
        .height(this.scrollHeight - this.bottomMargin)
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

        if (this.chatViewModel.networkBroken) {
          NetworkBrokenBuilder()
        }

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
            controller: this.controller,
            placeHolder: (this.chatUserInfo.conversationName ?? '').length > 15 ?
              this.chatUserInfo.conversationName?.substring(0, 15) + '...' : this.chatUserInfo.conversationName,
            replyMsg: this.replyMsg,
            chatInfo: this.chatUserInfo,
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
                }
              })
            },
            onDidClickAudio: () => {
              this.showOperationView = false
              let context = getContext(this) as common.UIAbilityContext
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
              this.showOperationView = false
              let text = this.getMessageText().trimEnd()
              if (text.length <= 0) {
                NECommonUtils.showToast($r('app.string.null_message_not_support'))
                return
              }
              this.chatViewModel.sendTextMessage(text, this.replyMsg)
              this.clearInput(true)
            },
            inputStyle: this.inputStyle
          }).alignRules({
            left: { anchor: "chat_input", align: HorizontalAlign.Start },
            right: { anchor: "chat_input", align: HorizontalAlign.End },
            bottom: { anchor: "chat_input", align: VerticalAlign.Bottom },
            top: { anchor: "chat_input", align: VerticalAlign.Top },
          }).backgroundColor($r('app.color.chat_input_background'))
        } else if (this.showMultiSelect) {
          ChatMultiSelectView({
            isEnable: this.multiSelectCount > 0,
            onMultiForward: () =>{
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
                          console.info("ChooseLocation", "Succeeded in choosing location.");
                        })
                        .catch((err: BusinessError) => {
                          console.error("ChooseLocation",
                            `Failed to choose location, code: ${err.code}, message: ${err.message}`);
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
                this.chatViewModel.sendTextMessage(text, this.replyMsg)
                this.clearInput(true)
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

        if (this.showOperationView) {
          MessageOperationView({
            operateMsg: this.operationMsg,
            didClickItem: (item: MessageOperationItem) => {
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
                    this.currentConversationName = this.chatUserInfo.getConversationName()
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
                this.loadReplyInfo(this.operationMsg)
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
      .zIndex(1)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      let param = this.pathStack.getParamByName("ChatP2PPage") as string[];
      if (param.length > 0) {
        this.conversationId = param[0];
        this.loadChatData();
      } else {
        this.pathStack.removeByName("ChatP2PPage")
      }
    }).onHidden(() => {
      AudioPlayerManager.instance.stopPlayAll()
    })
  }

  loadReplyInfo(msg: NIMMessageInfo) {
    this.bottomHeight = this.bottomWithReplyHeight
    this.replyMsg = msg
    this.getUIContext().getFocusController().requestFocus("chat_edit_input")
  }

  clearInput(clearInput?: boolean) {
    if (clearInput) {
      this.controller.deleteSpans()
    }
    this.replyMsg = undefined
    this.bottomHeight = 105
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
        if (message.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED ||
          message.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO ||
          message.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
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
        if (message.message.sendingState === V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_FAILED) {
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
        let textMessageDetailDialog: CustomDialogController = new CustomDialogController({
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
        textMessageDetailDialog.open()
      }
      if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
        this.showImageDetail(msg, onlyShow)
      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
        downLoadAndOpenFile(msg, getContext(this), this.chatUserInfo)
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

  goToSettingPage(pathStack: NavPathStack) {
    if (this.showMultiSelect) {
      this.chatViewModel.clearSelectMessage()
      this.showMultiSelect = false
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
  }

  aboutToDisappear(): void {
    this.chatViewModel.clearUnreadCount()
    this.chatViewModel.onDestroy()
    AudioPlayerManager.instance.stopPlayAll()
  }
}

// 跳转页面入口函数
@Builder
export function ChatP2PPageBuilder() {
  ChatP2PPage()
}