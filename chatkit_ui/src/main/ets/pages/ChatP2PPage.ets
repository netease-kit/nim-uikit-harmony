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
import { NEEmojiManager, NIMEmoticonType } from '../manager/NEEmojiManager';
import { NEChatMoreOperation } from '../view/ChatMoreOperationLayout';
import { NEChatMoreOperationData, NEChatMoreOperationType } from '../model/NEChatMoreOperationData';
import { NEAudioRecordView } from '../view/NEAudioRecordView';
import { InputStyleType, NEChatInputView } from '../view/ChatInputView';
import {
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
import { pasteboard } from '@kit.BasicServicesKit';
import { DeviceUtils } from '../common/DeviceUtils';
import { ImageViewDialog } from '@nimkit/common/src/main/ets/ImageViewDialog/ImageViewDialog';
import { V2NIMMessageType } from '@nimsdk/base';
import { ChatConst } from '../constants/ChatConst';
import { ChatKitClient } from '@nimkit/chatkit/src/main/ets/ChatKitClient';
import { AudioPlayerManager } from '../manager/AudioPlayerManager';
import { ConversationSelectParam } from '@nimkit/chatkit';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import { ForwardMessageDialog } from '../view/ForwardMessageDialog';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import {
  downLoadAndOpenFile,
  getMessageImageUrls,
  getMessageVideoRatio,
  getMessageVideoUrl
} from '../common/MessageHelper';

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
  // 长按操作弹窗的边距值
  operationViewMargin: number = 12;
  defaultInputViewHeight: number = 0;
  // 长按操作选中的消息
  operationMsg: NIMMessageInfo | undefined = undefined
  @Local operationRect: NERectData = new NERectData()
  screenHeight: number = 0;
  screenWidth: number = 0;
  //导航栏高度，用于计算弹窗位置
  navBarHeight: number = 80;
  // 底部输入框以及固定按钮操作栏高度
  bottomHeight: number = 105;
  // 暂时让出底部 tab bar 高度，后续去掉或设置为0
  bottomMargin: number = 100;
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
  @Local forwardMessages: NIMMessageInfo[] = []
  @Local forwardConversations: ConversationSelectModel[] = []
  @Local currentConversationName?: string
  forwardMessageDialog = new CustomDialogController({
    builder: ForwardMessageDialog({
      conversationList: this.forwardConversations,
      currentConversationName: this.currentConversationName,
      sendForwardMsg: (text: string | undefined) => {
        this.chatViewModel.forwardMessage(this.forwardMessages, this.forwardConversations, text)
      }
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 250,
    width: 276,
  })
  forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
    if (this.operationMsg?.message) {
      this.forwardMessages = [this.operationMsg]
      this.forwardConversations = selectedList
      this.currentConversationName = this.chatUserInfo.getConversationName()
      this.forwardMessageDialog.open()
    }
  }

  @Monitor("chatUserInfo.isReceiveMsg")
  onReceiveMsg(monitor: IMonitor) {
    if (this.firstLoadData || this.chatUserInfo.isReceiveMsg) {
      this.listScroller.scrollEdge(Edge.Bottom)
      this.chatUserInfo.setReceiveMsg(false)
      this.firstLoadData = false;
    }
  }

  @Monitor("chatUserInfo.scrollIndex")
  onScrollIndex(monitor: IMonitor) {
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

  @Monitor("chatViewModel.anchorMsg")
  onAnchorMsg(monitor: IMonitor) {
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

  @Monitor("expandHeight")
  onExpandInputView(monitor: IMonitor) {
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
    this.setupMoreOperationData();
    NEEmojiManager.instance.setup();
    DeviceUtils.rootDirPath = getContext(this).filesDir
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
          let keyboardHeight = px2vp(data.area.bottomRect.height);
          // 如果是定位消息状态，收到键盘展开重新切换最新消息
          if (keyboardHeight > 10 && this.chatViewModel.hasNew) {
            this.chatViewModel.reloadMessageList()
          }
          if ((this.inputStyle === InputStyleType.Emoji || this.inputStyle === InputStyleType.Record ||
            this.inputStyle === InputStyleType.More) && keyboardHeight <= 0) {
            this.scrollHeight =
              px2vp(currentWindow.getWindowProperties().windowRect.height - data.area.bottomRect.height) -
              this.bottomHeight - this.expandHeight;
          } else {
            this.scrollHeight =
              px2vp(currentWindow.getWindowProperties().windowRect.height - data.area.bottomRect.height) -
              this.bottomHeight;
            if (keyboardHeight > 10) {
              this.expandHeight = 0
              this.inputStyle = InputStyleType.None;
              this.listScroller.scrollEdge(Edge.Bottom)
            }
          }
          return;
        }
      })
    })
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

  // 初始化数据
  setupMoreOperationData() {
    const videoOperationData = new NEChatMoreOperationData();
    videoOperationData.operationTitle = $r("app.string.chat_camera_take");
    videoOperationData.type = NEChatMoreOperationType.Video;
    videoOperationData.imageSource = "app.media.ic_public_chat_photo";
    this.operationMoreDataList.push(videoOperationData);
    const fileOperationData = new NEChatMoreOperationData();
    fileOperationData.operationTitle = $r("app.string.chat_send_file");
    fileOperationData.type = NEChatMoreOperationType.File;
    fileOperationData.imageSource = "app.media.ic_public_chat_file";
    this.operationMoreDataList.push(fileOperationData);
  }

  loadChatData() {
    this.chatUserInfo.setConversationId(this.conversationId)
    this.chatViewModel.init(this.conversationId, this.chatUserInfo);
    this.chatViewModel.loadData();
  }

  async showImageDetail(msg?: NIMMessageInfo) {
    try {
      const imageModel = await getMessageImageUrls(msg, this.chatUserInfo)
      this.imagesIndexModel = imageModel
      this.imageViewerDialog.open()
    } catch (err) {
      console.error(err)
    }
  }

  showVideoDetail(msg: NIMMessageInfo) {
    AudioPlayerManager.instance.stopPlayAll()
    this.videoFileUrl = getMessageVideoUrl(msg, this.chatUserInfo)
    this.videoRatio = getMessageVideoRatio(msg)
    if (this.videoFileUrl) {
      this.videoViewerDialog.open()
    }
  }

  @Builder
  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: this.chatUserInfo.conversationName,
        rightButtonIcon: $r('app.media.ic_public_more_dot'),
        rightButtonAction: () => {
          this.goToSettingPage(this.pathStack)
        },
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })

      if (this.chatViewModel.networkBroken) {
        NetworkBrokenBuilder()
      }

      RelativeContainer() {
        List({ scroller: this.listScroller }) {
          LazyForEach(this.chatUserInfo.msgList, (msg: NIMMessageInfo) => {
            ListItem() {
              MessageComponent({
                message: msg,
                chatInfo: this.chatUserInfo,
                onMessageClick: {
                  onAvatarClick: ((msg: NIMMessageInfo | undefined) => {
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
                    this.operationMsg = msg
                    let opMenuWidth = MessageOperationView.computeViewWidth(msg)
                    if (event.target.area.position.x !== undefined) {
                      let xPoint = Number(event.target.area.globalPosition.x) +
                        (Number(event.target.area.width) - opMenuWidth) / 2
                      if (xPoint < this.operationViewMargin) {
                        xPoint = this.operationViewMargin;
                      }
                      if (xPoint + opMenuWidth + this.operationViewMargin > this.screenWidth) {
                        xPoint = this.screenWidth - opMenuWidth - this.operationViewMargin;
                      }
                      this.operationRect.x = xPoint;
                    }
                    if (event.target.area.position.y !== undefined) {
                      this.operationRect.y =
                        Number(event.target.area.globalPosition.y) - this.navBarHeight +
                        Number(event.target.area.height)
                    }
                    this.showOperationView = true
                  }),
                  onItemClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                    if (msg) {
                      if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
                        this.showImageDetail(msg)
                      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
                        downLoadAndOpenFile(msg, getContext(this), this.chatUserInfo)
                      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
                        this.showVideoDetail(msg)
                      }
                    }
                  },
                  onRevokeEditClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                    if (msg?.checkRevokeEdit()) {
                      this.controller.deleteSpans()
                      this.controller.addTextSpan(msg.revokeInfo?.revokeMsgText)
                    } else if (msg?.revokeInfo !== undefined) {
                      NECommonUtils.showToast($r('app.string.chat_revoke_edit_error_tips'))
                    }
                  }
                },
              })
            }
          }, (item: NIMMessageInfo, index?: number) => item.message.messageClientId)
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

        if (this.hideInput === false) {
          NEChatInputView({
            controller: this.controller,
            placeHolder: (this.chatUserInfo.conversationName ?? '').length > 15 ?
              this.chatUserInfo.conversationName?.substring(0, 15) + '...' : this.chatUserInfo.conversationName,
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
              let context = getContext(this) as common.UIAbilityContext;
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
              this.chatViewModel.sendTextMessage(text)
              this.controller.deleteSpans()
            },
            inputStyle: this.inputStyle
          }).alignRules({
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
                this.chatViewModel.sendTextMessage(text)
                this.controller.deleteSpans()
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
              } else if (item.operationType == MessageOperationType.Delete ||
                item.operationType == MessageOperationType.Undo) {
                AlertDialog.show(
                  {
                    title: item.operationType == MessageOperationType.Undo ?
                    $r('app.string.chat_msg_revoke_dialog_title') : $r('app.string.chat_msg_delete_dialog_title'),
                    message: item.operationType == MessageOperationType.Undo ?
                    $r('app.string.chat_msg_revoke_dialog_desc') : $r('app.string.chat_msg_delete_dialog_desc'),
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
                        if (item.operationType == MessageOperationType.Delete) {
                          this.chatViewModel.deleteMessage(this.operationMsg)
                        } else if (item.operationType == MessageOperationType.Undo) {
                          this.chatViewModel.revokeMessage(this.operationMsg)
                        }
                      }
                    }
                  }
                )
                // 转发
              } else if (item.operationType == MessageOperationType.Translate) {
                this.pathStack.pushPath({
                  name: 'ConversationSelectPage',
                  param: new ConversationSelectParam([], 9, this.forwardMessageAction)
                })
              } else if (item.operationType == MessageOperationType.Pin) {
                this.chatViewModel.pinMessage(this.operationMsg)
              } else if (item.operationType == MessageOperationType.Unpin) {
                this.chatViewModel.unpinMessage(this.operationMsg)
              }
            }
          })
            .position({ x: this.operationRect.x, y: this.operationRect.y })
            .borderRadius(8)
            .shadow(ShadowStyle.OUTER_DEFAULT_MD)

        }
      }.margin({ bottom: this.bottomMargin })
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

  goToSettingPage(pathStack: NavPathStack) {
    pathStack.pushPath({
      name: 'UserSettingPage',
      param: this.chatViewModel.conversationId
    })
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



