/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatTeamInfo } from '../model/ChatTeamInfo';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { MessageComponent } from '../view/MessageComponent';
import { NEEmojiManager } from '../manager/NEEmojiManager';
import {
  CommonEmptyResult,
  ImagesIndexModel,
  ImageViewDialog,
  NavigationBackBuilder,
  NECommonUtils,
  VideoViewerDialog
} from '@nimkit/common';
import { DeviceUtils } from '../common/DeviceUtils';
import {
  downLoadAndOpenFile,
  getMessageImageUrls,
  getMessageVideoRatio,
  getMessageVideoUrl
} from '../common/MessageHelper';
import { V2NIMConversationType, V2NIMErrorCode, V2NIMMessageType } from '@nimsdk/base';
import pasteboard from '@ohos.pasteboard';
import { ChatKitClient } from '@nimkit/chatkit/src/main/ets/ChatKitClient';
import { ChatRepo } from '@nimkit/chatkit/src/main/ets/repo/ChatRepo';
import { TextMessageDetailDialog } from '../view/TextMessageDetailDialog';
import { ConversationSelectParam } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectParam';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import { ForwardMessageDialog } from '../view/ForwardMessageDialog';
import { ChatPinViewModel } from '../viewmodel/ChatPinViewModel';
import { ErrorUtils } from '@nimkit/chatkit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ChatBaseViewModel } from '../viewmodel/ChatBaseViewModel';
import { AudioPlayerManager } from '../manager/AudioPlayerManager';

@CustomDialog
export struct PinMoreActionDialog {
  @BuilderParam message: NIMMessageInfo
  @BuilderParam dialogHeight: number
  @BuilderParam forwardMessageAction?: (message: NIMMessageInfo) => void
  controller?: CustomDialogController
  unpinMessage = async () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      await ChatRepo.unpinMessage(this.message.message).catch((err: BusinessError) => {
        if (err.code == V2NIMErrorCode.V2NIM_ERROR_CODE_PIN_NOT_EXIST) {
          return
        }
        ErrorUtils.handleErrorToast(err.code)
      })
      NECommonUtils.showToast($r('app.string.pin_list_unpin_success_tips'))
      this.cancel()
    }
  }
  copyMessage = () => {
    const copyData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.message.message.text)
    pasteboard.getSystemPasteboard().setData(copyData).then(() => {
      NECommonUtils.showToast($r('app.string.copy_success'))
      this.cancel()
    })
  }
  forwardMessage = () => {
    this.forwardMessageAction?.(this.message)
    this.cancel()
  }
  cancel = () => {
    this.controller?.close()
  }

  build() {
    Column() {
      Column() {
        Text($r("app.string.setting_unpin"))
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.unpinMessage)

        if (this.message.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
          Row()
            .height(1)
            .width('100%')
            .backgroundColor("#EFF1F4")

          Text($r("app.string.chat_operation_copy"))
            .fontSize(14)
            .fontColor("#333333")
            .textAlign(TextAlign.Center)
            .height(42)
            .width('100%')
            .onClick(this.copyMessage)
        }

        if (this.message.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO &&
          this.message.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
          Row()
            .height(1)
            .width('100%')
            .backgroundColor("#EFF1F4")

          Text($r("app.string.chat_operation_forward"))
            .fontSize(14)
            .fontColor("#333333")
            .textAlign(TextAlign.Center)
            .height(42)
            .width('100%')
            .onClick(this.forwardMessage)
        }
      }
      .height(this.dialogHeight)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 12, right: 12 })

      Column() {
        Text($r('app.string.mine_edit_cancel'))
          .fontSize(14)
          .fontColor("#333333")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.cancel)
      }
      .height(42)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ top: 10, left: 12, right: 12 })

    }
    .height(this.dialogHeight + 52)
    .backgroundColor(Color.Transparent)
  }
}

@ComponentV2
export struct PinMessagePage {
  pathStack: NavPathStack = new NavPathStack()
  @Local chatTeamInfo: ChatTeamInfo = new ChatTeamInfo('');
  viewModel: ChatPinViewModel = new ChatPinViewModel();
  conversationId: string = '';
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
    customStyle: true,
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
  @Local tapMessage?: NIMMessageInfo
  @Local pinMoreActionDialogHeight: number = 42
  @Local forwardMessages: NIMMessageInfo[] = []
  @Local forwardConversations: ConversationSelectModel[] = []
  @Local currentConversationName?: string
  private listScroller: Scroller = new Scroller()
  private scrollIndex: number = 0
  forwardMessageClick = () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      this.pathStack.pushPath({
        name: 'ConversationSelectPage',
        param: new ConversationSelectParam([], 9, this.forwardMessageAction)
      })
    }
  }
  forwardMessageDialog = new CustomDialogController({
    builder: ForwardMessageDialog({
      conversationList: this.forwardConversations,
      currentConversationName: this.currentConversationName,
      sendForwardMsg: (text: string | undefined) => {
        this.viewModel.forwardMessage(this.forwardMessages, this.forwardConversations, text)
      }
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 250,
    width: 276,
  })
  pinMoreActionDialog: CustomDialogController = new CustomDialogController({
    builder: PinMoreActionDialog({
      message: this.tapMessage,
      dialogHeight: this.pinMoreActionDialogHeight,
      forwardMessageAction: this.forwardMessageClick
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
  })
  textMessageDetailDialog: CustomDialogController = new CustomDialogController({
    builder: TextMessageDetailDialog({
      message: this.tapMessage
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Center,
    backgroundColor: Color.White,
    height: '100%',
    width: '100%',
    customStyle: true
  })

  @Monitor("viewModel.topInsert")
  scrollToTop() {
    if (this.scrollIndex === 0) {
      this.listScroller.scrollToIndex(0)
    }
    this.viewModel.topInsert = false
  }

  forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
    if (this.tapMessage?.message) {
      this.forwardMessages = [this.tapMessage]
      this.forwardConversations = selectedList
      const conversationType = ChatKitClient.nim.conversationIdUtil.parseConversationType(this.conversationId)
      if (conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        const targetAccountId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId)
        this.currentConversationName = this.chatTeamInfo.getChatUserShowName(targetAccountId)
      } else {
        this.currentConversationName = this.chatTeamInfo.team?.name
      }
      this.forwardMessageDialog.open()
    }
  }

  getPinMoreActionDialogHeight(message?: NIMMessageInfo): number {
    let height = 42
    if (message?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      height += 43
    }
    if (message?.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      height += 43
    }
    return height
  }

  aboutToAppear(): void {
    NEEmojiManager.instance.setup();
    DeviceUtils.rootDirPath = getContext(this).filesDir
  }

  async requestChatData() {
    this.chatTeamInfo.setConversationId(this.conversationId)
    this.viewModel.init(this.conversationId as string, this.chatTeamInfo)
    this.viewModel.getPinMessageList()
  }

  async showImageDetail(msg?: NIMMessageInfo) {
    try {
      const imageModel = await getMessageImageUrls(msg, this.chatTeamInfo)
      this.imagesIndexModel = imageModel
      this.imageViewerDialog.open()
    } catch (err) {
      console.log(err)
    }
  }

  showVideoDetail(msg: NIMMessageInfo) {
    //点击视频消息前关闭所以音频
    AudioPlayerManager.instance.stopPlayAll()
    this.videoFileUrl = getMessageVideoUrl(msg, this.chatTeamInfo)
    this.videoRatio = getMessageVideoRatio(msg)
    if (this.videoFileUrl) {
      this.videoViewerDialog.open()
    }
  }

  @Builder
  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r("app.string.setting_pin"),
        backgroundColor: '#EFF1F4',
        leftButtonAction: () => {
          this.pathStack.pop()
        },
      })
      if (this.viewModel.pinListEmpty) {
        CommonEmptyResult({
          tips: $r('app.string.setting_pin_empty')
        })
          .margin({
            top: 56 + 74,
          })
      }
      RelativeContainer() {
        List({ space: 12, scroller: this.listScroller }) {
          LazyForEach(this.chatTeamInfo.msgList, (msg: NIMMessageInfo) => {
            ListItem() {
              MessageComponent({
                isPinPage: true,
                message: msg,
                chatInfo: this.chatTeamInfo,
                onMessageClick: {
                  onAvatarClick: undefined,
                  onItemLongClick: undefined,
                  onItemClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                    this.tapMessage = msg
                    if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
                      this.showImageDetail(msg)
                    } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
                      downLoadAndOpenFile(msg, getContext(this), this.chatTeamInfo)
                    } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
                      this.showVideoDetail(msg)
                    } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
                      this.textMessageDetailDialog.open()
                    }
                  }
                },
                onMoreButtonClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                  this.tapMessage = msg
                  this.pinMoreActionDialogHeight = this.getPinMoreActionDialogHeight(msg)
                  this.pinMoreActionDialog.open()
                },
                onPinItemClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                  if (msg) {
                    if (ChatBaseViewModel.currentViewModel) {
                      ChatBaseViewModel.currentViewModel.setAnchorMessage(msg)
                    }
                    if (msg.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
                      this.pathStack.popToName('ChatP2PPage')
                    } else if (msg.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
                      this.pathStack.popToName('ChatTeamPage')

                    }
                  }
                }
              })
            }
          }, (item: NIMMessageInfo, index?: number) => item.message.messageClientId)
        }
        .id("pinPageListView")
        .cachedCount(20)
        .padding({ bottom: 56 })
        .maintainVisibleContentPosition(true)
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "__container__", align: VerticalAlign.Top },
        })
        .width('100%')
        .height('100%')
        .onScrollIndex((start: number, end: number, center: number) => {
          this.scrollIndex = start
        })
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      let param = this.pathStack.getParamByName("PinMessagePage") as string[];
      if (param.length > 0) {
        this.conversationId = param[0];
        this.requestChatData();
      } else {
        this.pathStack.removeByName("PinMessagePage")
      }
    })
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
  }
}

// 跳转页面入口函数
@Builder
export function PinMessagePageBuilder() {
  PinMessagePage()
}

